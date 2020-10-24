Project for checking if services are working correctly.
After requesting particular endpoint fetched from Dynamo DB, the response says what custom metric send to AWS Cloud Watch.
For some endpoints, there is also measurement of response time, sent to Atlassian Statuspage metrics. 
AWS Cloud Watch send alerts after breaching threshold of concurrent errors.

####Python program is the first project version, which was rewritten using JavaScript for simplifying asynchronous operations.
