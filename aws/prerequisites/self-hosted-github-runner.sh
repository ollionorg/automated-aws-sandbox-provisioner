#!/bin/bash

export AWS_DEFAULT_REGION="us-east-1"
export SELF_HOSTED_RUNNER_VPC_CIDR="10.129.10.0/26"
export SELF_HOSTED_RUNNER_SUBNET_CIDR="10.129.10.0/28"
export INSTANCE_TYPE="t2.micro"
export SELF_HOSTED_RUNNER_SG_NAME="SelfHostedRunnerSecurityGroup"
export RUNNER_INSTANCE_PROFILE_NAME="GitHubRunnerInstanceProfile"
export GITHUB_RUNNER_ROLE_NAME="GitHubRunnerRole"
export SANDBOX_MANAGEMENT_ROLE_NAME="SandboxAccountManagementRole"

# Define the trust policy JSON
TRUST_POLICY_JSON='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'
# Use the AWS CLI to list all existing VPCs and their CIDR blocks
existing_vpcs=$(aws ec2 describe-vpcs --region "$AWS_DEFAULT_REGION" --query "Vpcs[].CidrBlock" --output json | jq -r '.[]')

# Loop through the existing VPCs and check for conflicts
for existing_cidr in $existing_vpcs; do
    if [ "$existing_cidr" == "$SELF_HOSTED_RUNNER_VPC_CIDR" ]; then
        echo "Error: CIDR block $SELF_HOSTED_RUNNER_VPC_CIDR conflicts with an existing VPC."
        exit 1
    fi
done

INSTANCE_AMI_ID=$(aws ec2 describe-images --region $AWS_DEFAULT_REGION --filters "Name=name,Values=al2023-ami-2023.2.20231002.0-kernel-6.1-x86_64" --output text --query 'Images[].ImageId')

if [[ -z $INSTANCE_AMI_ID ]]; then
    echo "Could not fetch AMI for the instance in $AWS_DEFAULT_REGION. Please specify manually above. "
fi

# Create the VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block "$SELF_HOSTED_RUNNER_VPC_CIDR" --region "$AWS_DEFAULT_REGION" --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=SelfHostedRunnerVPC}]' | jq -r '.Vpc.VpcId')

if [ -z "$VPC_ID" ]; then
    echo "Error: Failed to create VPC."
    exit 1
else
    echo "VPC created with ID: $VPC_ID"
fi

# Create a subnet for the self-hosted runner
SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$SELF_HOSTED_RUNNER_SUBNET_CIDR" --region "$AWS_DEFAULT_REGION" --availability-zone "$AWS_DEFAULT_REGION"a | jq -r '.Subnet.SubnetId')

if [ -z "$SUBNET_ID" ]; then
    echo "Error: Failed to create subnet."
    exit 1
else
    echo "Subnet created with ID: $SUBNET_ID"
fi


# Create a security group for the self-hosted runner
RUNNER_SG_ID=$(aws ec2 create-security-group --group-name "$SELF_HOSTED_RUNNER_SG_NAME" \
    --description "Security group for self-hosted GitHub runner" \
    --vpc-id "$VPC_ID" \
    --region "$AWS_DEFAULT_REGION" | jq -r '.GroupId')

if [ -z "$RUNNER_SG_ID" ]; then
    echo "Error: Failed to create security group."
    exit 1
else
    echo "Security group created with ID: $RUNNER_SG_ID"
fi

RULE_OUTPUT=$(aws ec2 authorize-security-group-ingress \
  --group-id "$RUNNER_SG_ID" \
  --protocol tcp \
  --port 443 \
  --cidr "0.0.0.0/0" --query 'Return' --output text)

if [[ $RULE_OUTPUT == "True" ]]; then
    echo "Security group rule added"
else
    echo "1 - Security group rule failed to be created"
fi

RULE_OUTPUT=$(aws ec2 authorize-security-group-egress \
  --group-id "$RUNNER_SG_ID" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 --query 'Return' --output text)

if [[ $RULE_OUTPUT == "True" ]]; then
    echo "Security group rule added"
else
    echo "2 - Security group rule failed to be created"
fi

RULE_OUTPUT=$(aws ec2 authorize-security-group-egress \
  --group-id "$RUNNER_SG_ID" \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 --query 'Return' --output text)

if [[ $RULE_OUTPUT == "True" ]]; then
    echo "Security group rule added"
else
    echo "3 - Security group rule failed to be created"
fi
# Create GitHub Runner role
GITHUB_RUNNER_ROLE_OUTPUT=$(aws iam create-role \
  --role-name "$GITHUB_RUNNER_ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY_JSON" \
  --description "Role for GitHub Runner" --output json)


# Create IAM instance profile
INSTANCE_PROFILE_ARN=$(aws iam create-instance-profile \
  --instance-profile-name "$RUNNER_INSTANCE_PROFILE_NAME" \
  --query 'InstanceProfile.Arn' \
  --output text)


if [ -z "$INSTANCE_PROFILE_ARN" ]; then
    echo "Error: Failed to create IAM instance profile."
    exit 1
else
    echo "IAM instance profile created with ARN: $INSTANCE_PROFILE_ARN"
fi

# Attach IAM role policy to the instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name "$RUNNER_INSTANCE_PROFILE_NAME" \
  --role-name "$GITHUB_RUNNER_ROLE_NAME"

sleep 5

# Create EC2 Instance
INSTANCE_ID=$(aws ec2 run-instances \
  --region $AWS_DEFAULT_REGION \
  --instance-type $INSTANCE_TYPE \
  --image-id "$INSTANCE_AMI_ID" \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$RUNNER_SG_ID" \
  --iam-instance-profile "Arn=$INSTANCE_PROFILE_ARN" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=SelfHostedGitHubRunner}]' \
  --user-data file://runner_registration.txt
  --query 'Instances[0].InstanceId' \
  --output text)


aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_DEFAULT_REGION

echo "EC2 runner created"
echo "Proceeding with runner registration"
#aws iam delete-instance-profile \
#  --instance-profile-name GitHubRunnerInstanceProfile
#