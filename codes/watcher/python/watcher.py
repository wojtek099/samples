import aiohttp
import asyncio
import signal
import boto3
import datetime
import os
from time import sleep, time
import logging

logging.basicConfig(format='%(asctime)s : %(message)s', datefmt='%d-%b-%y %H:%M:%S', level=logging.INFO)

async def make_request(session,endpoint):
    url = endpoint['url']
    timeout = endpoint['timeout']
    service_type = endpoint.get('type')
    region = endpoint.get('region')
    metric_id = endpoint.get('metric_id')
    try:
        start = datetime.datetime.utcnow()
        async with session.get(url, timeout=timeout) as resp:
            end = datetime.datetime.utcnow()
            status_code = resp.status
            res = await resp.read()
            if status_code == 200:
                metric = 'status-200'
                # logging.info(f'200 {url}')
            else:
                metric = 'Error'
                logging.warning(f'{url} - {status_code} {res}')
    except Exception as e:
        logging.warning(f'Request error - {url}: {e}')
        metric = "requestError"
        end = datetime.datetime.utcnow()
    else:
        if metric_id:
            statuspage_url = "https://" + statuspage_config['api_base'] + "/v1/pages/" + statuspage_config['page_id'] + "/metrics/" + metric_id + "/data?api_key=" + statuspage_config['api_key']
            data = {
                "timestamp": datetime.datetime.timestamp(start),
                "value": (end-start).total_seconds()
            }
            async with session.post(statuspage_url, timeout=10, json={'data': data}) as resp:
                res = await resp.read()
    finally:
        # TODO take a look if put_metric_data() not hangs the program too long (run_in_executor()?)
        cloudwatch.put_metric_data(
            Namespace='Watcher/status-code',
            MetricData=[
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
                    'Timestamp': end,
                    'Unit': 'Count',
                    'Value': 1,
                    'StorageResolution': 1
                },
            ]
        )

async def watcher(session, endpoint):
    while True:
        loop.create_task(make_request(session,endpoint))
        await asyncio.sleep(endpoint['interval'])

def handle_exception(loop, context):
    # context["message"] will always be there; but context["exception"] may not
    msg = context.get("exception", context["message"])
    print("Handler caught exception: ", msg)

async def shutdown(event, main_task, signal=None):
    if signal:
        print("Received exit signal {}...".format(signal.name))
    tasks = [t for t in asyncio.all_tasks() if t is not asyncio.current_task() and t is not main_task]
    [task.cancel() for task in tasks]
    print("Cancelling outstanding tasks")
    await asyncio.gather(*tasks, return_exceptions=True)
    event.set()     # unlock main thread to gracefuly close session and loop

async def main():
    # handle interrupting signals for gracefuly shutdown
    signals = (signal.SIGHUP, signal.SIGTERM, signal.SIGINT)
    event = asyncio.Event()     # event for managing running this main Task
    main_task = asyncio.current_task()
    for s in signals:
        loop.add_signal_handler(
            s, lambda s=s: asyncio.create_task(shutdown(event, main_task ,signal=s))
        )
    # create Tasks for independently checking all endpoints
    conn = aiohttp.TCPConnector(limit=0)    # change opened connections default limit (100) to no-limit
    async with aiohttp.ClientSession(connector=conn) as session:
        for endpoint in endpoints:
            loop.create_task(watcher(session, endpoint))
        await event.wait()     # Prevent finishing Task to keep loop running
    print("Finishing main Task...")
    # await session.close()
    await asyncio.sleep(.5)
    loop.stop()

if __name__ == '__main__':
    statuspage_config = {
        'page_id': '<redacted>',
        'api_key': '***', #hidden
        'api_base': 'api.statuspage.io'
    }

    print("Watcher start.")
    env = os.getenv('ENV', 'prod')
    main_region = "eu-west-1" if env == "prod" else "us-west-2"
    cloudwatch = boto3.client('cloudwatch', main_region)
    dynamodb = boto3.client('dynamodb', main_region)
    response = dynamodb.scan(
        TableName='Watcher',
        ConsistentRead=True
    )
    endpoints = []
    # {'timeout': {'N': '10'}, 'interval': {'N': '30'}, 'region': {'S': 'test'}, 'url': {'S': 'http://httpbin.org/status/200%2C200%2C500'}, 'type': {'S': 'test'}}
    for item in response['Items']:
        obj = {}
        for attribute, attribute_value in item.items():
            for key, value in attribute_value.items():
                new_attribute_value = int(value) if key == 'N' else value
            obj[attribute] = new_attribute_value
        if obj.get('region') == os.getenv('AWS_REGION', 'default') or obj.get('region') == 'test':   # TODO : consider if default should be an existing region
            endpoints.append(obj)
    # start event loop and run until stop()
    loop = asyncio.get_event_loop()
    loop.set_exception_handler(handle_exception)
    try:
        loop.create_task(main())
        loop.run_forever()
    finally:
        print("Closing loop...")
        loop.close()