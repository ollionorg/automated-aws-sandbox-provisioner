import json
import boto3
from botocore.exceptions import ClientError
from urllib import request

# SUMMARY
# ACCOUNT_ID = REPLACE_ACCOUNT_ID
# EMAIL = REPLACE_EMAIL_HERE
# HELPDESK TICKET = REPLACE_TICKET_HERE
# TEAM = REPLACE_TEAM_HERE
# TEAM_POOL = REPLACE_POOL_OU_HERE

REPO_OWNER = "REPLACE_REPO_OWNER_HERE"
REPO_NAME = "REPLACE_REPO_NAME_HERE"


def get_secret():
    secret_name = "REPLACE_SECRET_NAME_HERE"
    region_name = "REPLACE_AWS_DEFAULT_REGION"

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        raise e

    # Decrypt secret
    secret = get_secret_value_response['SecretString']
    git_token = (json.loads(secret))['REPLACE_SECRET_KEY_NAME_HERE']

    return git_token


def account_handler(event, context):
    payload = {
        "event_type": "aws_sandbox_nuke",
        "client_payload": {
            "ACCOUNT_ID_TO_NUKE": "REPLACE_ACCOUNT_ID",
            "USER_EMAIL": "REPLACE_EMAIL_HERE",
            "TICKET_ID": "REPLACE_TICKET_HERE",
            "TEAM": "REPLACE_TEAM_HERE",
            "POOL_OU_ID": "REPLACE_POOL_OU_HERE",
            "SANDBOX_OU_ID": "REPLACE_SANDBOX_OU_HERE"
        }
    }
    url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/dispatches"
    headers = {
        'Authorization': f'Bearer {get_secret()}',
        'Accept': 'application/vnd.github+json'
    }
    req = request.Request(url, data=json.dumps(payload).encode(), headers=headers)

    try:
        response = request.urlopen(req)
        print(response)
    except request.HTTPError as e:
        print(f"HTTPError: {e.code} - {e.reason}")
    except request.URLError as e:
        print(f"URLError: {e.reason}")
