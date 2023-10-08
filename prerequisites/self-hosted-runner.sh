#!/bin/bash

# AWS Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="YOUR_AWS_ACCOUNT_ID"
INSTANCE_TYPE="t2.micro"
SUBNET_ID="subnet-XXXXXXXXXXXXXXXXX"
SECURITY_GROUP_ID="sg-XXXXXXXXXXXXXXXXX"
ROLE_NAME="SandboxAccountManagementRole"
INSTANCE_PROFILE_NAME="EC2GitHubRunnerInstanceProfile"
KEY_PAIR_NAME="YourKeyPairName"

# GitHub Configuration
GITHUB_REPO_OWNER="YourRepoOwner"
GITHUB_REPO_NAME="YourRepoName"
GITHUB_TOKEN="YourGitHubPersonalAccessToken"

# Create EC2 Instance
INSTANCE_ID=$(aws ec2 run-instances \
  --region $AWS_REGION \
  --instance-type $INSTANCE_TYPE \
  --subnet-id $SUBNET_ID \
  --security-group-ids $SECURITY_GROUP_ID \
  --key-name $KEY_PAIR_NAME \
  --iam-instance-profile Name=$INSTANCE_PROFILE_NAME \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "EC2 Instance ($INSTANCE_ID) created."

# Wait for instance to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION

# Assume Role
CREDENTIALS_JSON=$(aws sts assume-role \
  --role-arn "arn:aws:iam::$AWS_ACCOUNT_ID:role/$ROLE_NAME" \
  --role-session-name "GitHubRunnerSession")

export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS_JSON | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS_JSON | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $CREDENTIALS_JSON | jq -r '.Credentials.SessionToken')

# Register GitHub Runner
RUNNER_TOKEN=$(curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME/actions/runners/registration-token" | jq -r '.token')

# Write runner registration script
echo "#!/bin/bash
./config.sh --url \"https://github.com/$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME\" --token $RUNNER_TOKEN --name \"MyAWSRunner\" --labels \"aws,ec2\" --unattended" > runner_registration.sh
chmod +x runner_registration.sh

# Run runner registration script
./runner_registration.sh

echo "GitHub Runner registered."

# Clean up temporary credentials
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

echo "Script execution completed."