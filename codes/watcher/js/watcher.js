const DynamoDB = require('aws-sdk/clients/dynamodb');
const CloudWatch = require('aws-sdk/clients/cloudwatch');
const SSM = require('aws-sdk/clients/ssm');
const axios = require('axios');

console.log('Watcher start.');

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'; //ALB redirects to https

const ENV = process.env.ENV || 'prod';
const mainRegion = (ENV=='prod') ? 'eu-west-1' : 'us-west-2';

const cloudwatch = new CloudWatch({apiVersion: '2010-08-01', region: mainRegion});

let statuspageConfig = {};

(async () => {
    const ssm = new SSM({apiVersion: '2014-11-06', region: mainRegion});
    const dynamodb = new DynamoDB.DocumentClient({apiVersion: '2012-08-10', region: mainRegion});
    
    const dynamodb_params = {
        // name mapping beacuse of DynamoDB keyword 'region'
        ExpressionAttributeNames: {
            "#REGION": "region"
        },
        ExpressionAttributeValues: {
            ":region": process.env.AWS_REGION
        },
        FilterExpression: "#REGION = :region",
        TableName: "Watcher"
    };

    try {
        const ssmResponse = await ssm.getParameter({Name: "/general/statuspage-config"}).promise();
        statuspageConfig = JSON.parse(ssmResponse.Parameter.Value);

        const data = await dynamodb.scan(dynamodb_params).promise();
        endpoints = data.Items;
        endpoints.forEach(endpoint => {
            makeRequest(endpoint);
        })
        return true;
    } catch (e) {
        console.log("Error: ", e);
        process.exit(1);
    }
    
})();

const makeRequest = async (endpoint) => {
    const url = endpoint.url;
    const timeout = endpoint.timeout;
    const service_type = endpoint.type;
    const region = endpoint.region;
    const metricId = endpoint.metric_id;
    const interval = endpoint.interval;

    setTimeout(makeRequest, interval * 1000, endpoint);     // schedule executing function again

    let metric = "status-200";
    let start;
    let end;
    try {
        start = Date.now();
        let response = await axios.get(url, {
            timeout : timeout * 1000,
            validateStatus: (status) => {
                return status >= 100 && status < 600;   // don't invoke errors with status codes >200
              }
        });
        end = Date.now();
        const statusCode = response.status;
        if(statusCode != 200) {
            metric = "Error";
            console.log(`${url} - ${statusCode} ${JSON.stringify(response.data)}`);
        }
    } catch (error) {
        console.error(`Request error - ${url}: ${error}`);
        metric = "requestError";
        end = Date.now();
    } finally {
        const params = {
            Namespace: 'Watcher/status-code-1',
            MetricData: [
                {
                    'MetricName': metric,
                    'Dimensions': [
                        {
                            'Name': 'Type',
                            'Value': service_type
                        },
                        {
                            'Name': 'Region',
                            'Value': region
                        },
                        {
                            'Name': 'URL',
                            'Value': url
                        }
                    ],
                    'Timestamp': start/1000,
                    'Unit': 'Count',
                    'Value': 1,
                    'StorageResolution': 1
                },
            ]
        };
        try {
            let data = await cloudwatch.putMetricData(params).promise();
        } catch (e) {
            console.log("CW putMetricData error: ", e);
        }
    }

    if(metric !== 'requestError' && typeof metricId !== "undefined") {
        statuspageUrl = "https://" + statuspageConfig.apiBase + "/v1/pages/" + statuspageConfig.pageId + "/metrics/" + metricId + "/data?api_key=" + statuspageConfig.apiKey;
        try {
            let response = await axios.post(statuspageUrl, {
                data: {
                    timestamp: start/1000,
                    value: (end-start)/1000
                }
            });
        } catch (e) {
            console.log(`StatusPage push response time. Error: ${e}`);
        }
    }    
}
