import requests
import json
import tempfile
import hashlib
import boto3
import itertools
import pandas as pd
import os
from time import sleep
from google.cloud import storage
import sentry_sdk


ssm = boto3.client('ssm', 'eu-west-1')
pipefy_token = ssm.get_parameter(Name='/data/pipefy')['Parameter']['Value']

url = "https://api.pipefy.com/graphql"

headers = {
    'authorization': f"Bearer {pipefy_token}",
    'content-type': "application/json"
    }
    

query = """
query JP_CM($cursor: String) {
  cards(pipe_id: <redacted> first:50 after: $cursor){
    pageInfo{
      hasNextPage
      endCursor
    }
    edges{
      node {
        child_relations {
                    ...child_relations_recursive
        }
        current_phase{
          name
        }
        ...card_values
      }
    }
  }
}

fragment child_relations_recursive on CardRelationship {
	...child_relation_values
  cards {
    ...card_values
    child_relations {
      ...child_relation_values
      cards {
        ...card_values
        child_relations {
          ...child_relation_values
          cards {
            ...card_values
            child_relations {
          		...child_relation_values
              cards {
            		...card_values
              }
            }
          }
        }
      }
    }
  }
}

fragment card_values on Card {
  createdAt
  id
  title
  assignees {
    name
  }
  fields {
    name
    value
    array_value
    field {
      type
      id
      internal_id
    }
  }
}

fragment child_relation_values on CardRelationship {
  id
  name
}
    """

def get_fields(card, parent_id):
    # preparing child_relations as dictionary with ids
    child_relations = {}
    for child in card.get('child_relations'):
        child_relations[child['id']] = child
    all_fields = {}
    for field in card['fields']:
        field_id = field['field']['id']
        if parent_id:
            field_id = f'{parent_id}::{field_id}'
        # if nested cards
        if field['field']['type'] == 'connector':
            all_fields[field_id] = []
            child = child_relations[field['field']['internal_id']]
            for child_card in child['cards']:
                if child_card['id'] in field['array_value']:
                    # get fields from nested cards recursively
                    child_fields = get_fields(child_card, field_id)
                    child_fields[f'{field_id}::id'] = child_card['id']
                    all_fields[field_id].append(child_fields)
        else:
            all_fields[field_id] = field['value']
    return all_fields
    
def dict_to_rows(data):
    rows = []
    scalar_fields = {}
    array_fields = {}
    for key, value in data.items():
        if isinstance(value, list) and len(value) != 0:
            array_fields[key] = value
        else:
            scalar_fields[key] = value
    if array_fields:
        arrays_permutations = list(itertools.product(*array_fields.values()))
        for permutation in arrays_permutations:
            nested_row = dict(scalar_fields)
            for nested_dict in permutation:
                nested_row.update(nested_dict)
            rows.extend(dict_to_rows(nested_row))
    else:
        rows.append(scalar_fields)
    return rows


def get_one_request_rows(variables):
    global request_tries
    list_of_rows = []
    response = requests.request("POST", url, json={'query': query, "variables":variables}, headers=headers)
    if response.status_code != 200:
        print(f"Bad response: {response.text}")
        request_tries -= 1
        if request_tries > 0:
            sleep(10)
            return get_one_request_rows(variables)
        else:
            raise ValueError("Requests issues")
    data = response.json()['data']
    cards_connections = data['cards']
    page_info = cards_connections['pageInfo']
    edges = cards_connections['edges']
    for nodes in edges:
        card = nodes['node']
        data = get_fields(card, None)
        rows = dict_to_rows(data)
        for row in rows:
            row['title'] = card['title']
            row['phase'] = card['current_phase']['name']
            row['id'] = card['id']
            row['created_at']= card['createdAt']
            assignees = []
            for assignee in card['assignees']:
                assignees.append(assignee['name'])
            assignees = ', '.join(assignees)
            row['assignees'] = assignees
        list_of_rows.extend(rows)
    return [list_of_rows, page_info]

def push_file(df, file_name):
    BUCKET = '<redacted>'
    FILE_KEY = f"dashboards/_common/{file_name}"

    new_checksum = hashlib.sha256(df.to_csv().encode()).hexdigest()
    s3 = boto3.client('s3')
    checksum = None
    try:
        response = s3.head_object(Bucket=BUCKET, Key=FILE_KEY)
        checksum = response['Metadata'].get('checksum')
    except Exception as e:
        print(f"no file {file_name} yet")

    if checksum != new_checksum:
        pipefy_file = tempfile.NamedTemporaryFile(suffix='.csv.gz', delete=True)
        df.to_csv(pipefy_file.name, index=False, compression='gzip')
        ExtraArgs = {'Metadata': {'checksum': new_checksum}}
        s3.upload_file(pipefy_file.name, BUCKET, FILE_KEY, ExtraArgs=ExtraArgs)
        print(f"new file {file_name} pushed")
        pipefy_file.close()
    else:
        print(f"{file_name}: checksum the same")

all_rows = []
request_tries = 10
rows, page_info = get_one_request_rows(None)
all_rows.extend(rows)
while page_info['hasNextPage']:
    variables = {
        "cursor": page_info['endCursor'] 
    }
    request_tries = 10
    rows, page_info = get_one_request_rows(variables)
    all_rows.extend(rows)
    print(page_info)
    
     
df_all = pd.DataFrame(all_rows)
# print(df.columns.tolist())
rename_dict = {
    "created_at": "creation_date",
    "phase": "phase",
    "campaign_name": "card_name",
    "campaign_name_1": "campaign_name",
    'id': 'card_id',
    "assignees": "campaign_manager",
    "main_kpi":"main_kpi",
    "advertiser::what": "advertiser_name",
    "advertiser::vertical": "advertiser_vertical",
    "database_connection_title::dsp": "dsp",
    "database_connection_title_1::full_name":"client_service_manager",
    "database_connection_title::line_item_type":"format_campaign_type",
    "agency::agency_name_country":"agency_name",
    "database_connection_title::id":"format_id",
    "database_connection_title::end_date":"format_end_date",
    "database_connection_title::start_date":"format_start_date",
    "database_connection_title::reporting_time": "format_timezone",
    "database_connection_title::cpm1":"format_cpm",
    "database_connection_title::currency":"format_currency",
    "database_connection_title::impressions":"format_impressions",
    "dm::bd_code":"demand_manager_bd_code",
    "dm::country": "demand_manager_country_of_origin",
    "database_connection_title::country::country_code": "format_country_code",
    "database_connection_title::advertiser_io": "format_advertiser_io",
    "database_connection_title::format::size":"format_size",
    "database_connection_title::format::product_code":"format_product_code",
    "database_connection_title::flight":"format_flight",
    "database_connection_title::system":"format_system",
    "database_connection_title::deal_id_s":"format_deal_ids",
    "database_connection_title::preview_id_s":"format_preview_ids",
    "database_connection_title::tag_type":"format_tag_type",
    "database_connection_title::specificity_text": "format_specificity",
    "database_connection_title::publisher_io": "publisher_io",
    "database_connection_title::tracker_id": "tracker_id",

    "database_connection_title::optimisations::optimisation_date" : "optimisation_date",
    "database_connection_title::optimisations::optimisation_types" : "optimisation_types",
    "database_connection_title::optimisations::expected_results" : "optimisation_goal",
    "database_connection_title::optimisations::additional_comment" : "optimisation_comment"
}

df_all = df_all.loc[:,df_all.columns.isin(rename_dict.keys())]
df_all = df_all[rename_dict.keys()] # reordering
df_all.rename(columns=rename_dict, inplace=True)
df_all['format_start_date'] = pd.to_datetime(df_all['format_start_date'], format='%d/%m/%Y')
df_all['format_end_date'] = pd.to_datetime(df_all['format_end_date'], format='%d/%m/%Y')
df_all['optimisation_date'] = pd.to_datetime(df_all['optimisation_date'], format='%d/%m/%Y')
df_all = df_all[df_all.format_start_date >= '2020-01-01']   # drop old cards

# optimisation frame
df_opt = df_all[['campaign_name', 'card_id', 'format_id', 'format_product_code', 'optimisation_date', 'optimisation_types', 'optimisation_goal', 'optimisation_comment']].copy()
df_opt.drop_duplicates(keep='first', inplace=True)  # preventing duplicates created by not relevant fields
df_opt = df_opt.loc[df_opt['optimisation_date'].notnull()]
df_opt['optimisation_types'] = df_opt['optimisation_types'].apply(lambda x: '; '.join(json.loads(str(x))) if str(x) != 'nan' else x) #convert array to string
df_opt['optimisation_goal'] = df_opt['optimisation_goal'].apply(lambda x: '; '.join(json.loads(str(x))) if str(x) != 'nan' else x) #convert array to string

# main frame
df = df_all.drop(columns=['optimisation_date', 'optimisation_types', 'optimisation_goal', 'optimisation_comment'])
df.drop_duplicates(keep='first', inplace=True)  # preventing duplicates created by not relevant fields
df['format_system'] = df['format_system'].apply(lambda x: ', '.join(json.loads(str(x))) if str(x) != 'nan' else x) #convert array to string
df.loc[df['format_currency'] == '€', 'format_currency'] = 'EUR'
df.loc[df['format_currency'] == '$', 'format_currency'] = 'USD'
df.loc[df['format_currency'] == '£', 'format_currency'] = 'GBP'
df['format_deal_ids'] = df['format_deal_ids'].str.strip()

push_file(df, 'pipefy/pipefy.csv.gz')
push_file(df_opt, 'pipefy_optimisation/pipefy_optimisation.csv.gz')