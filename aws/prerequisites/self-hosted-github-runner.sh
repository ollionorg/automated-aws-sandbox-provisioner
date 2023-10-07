#!/bin/bash


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
else
    echo "Using AMI $INSTANCE_AMI_ID to deploy the runner instance"
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

# Create an internet gateway and attach it to the VPC
IGW_ID=$(aws ec2 create-internet-gateway --region "$AWS_DEFAULT_REGION" | jq -r '.InternetGateway.InternetGatewayId')
if [ -z "$IGW_ID" ]; then
    echo "Error: Failed to create internet gateway."
    exit 1
else
    echo "Internet Gateway created with ID: $IGW_ID"
fi
# Attach internet gateway to VPC
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" --region "$AWS_DEFAULT_REGION" | jq .

# Create a route table for the subnet
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --region "$AWS_DEFAULT_REGION" | jq -r '.RouteTable.RouteTableId')
if [ -z "$ROUTE_TABLE_ID" ]; then
    echo "Error: Failed to create route table."
    exit 1
else
    echo "Route Table created with ID: $ROUTE_TABLE_ID"
fi

aws ec2 associate-route-table --route-table-id "$ROUTE_TABLE_ID" --subnet-id "$SUBNET_ID" | jq .

# Add a route to the route table to route traffic to 0.0.0.0/0 through the internet gateway
aws ec2 create-route --route-table-id "$ROUTE_TABLE_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" --region "$AWS_DEFAULT_REGION" | jq .

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

RULE_OUTPUT=$(aws ec2 authorize-security-group-egress \
  --group-id "$RUNNER_SG_ID" \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 --query 'Return' --output text)

if [[ $RULE_OUTPUT == "True" ]]; then
    echo "Security group rule added"
else
    echo "Security group rule failed to be created"
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
  --role-name "$GITHUB_RUNNER_ROLE_NAME" | jq .

sleep 5

KEY_NAME="my-ec2-key-pair-7"
# Check if the key pair already exists
existing_key=$(aws ec2 describe-key-pairs --region "$AWS_DEFAULT_REGION" --key-names "$KEY_NAME" --query "KeyPairs[0].KeyName" --output text)

if [ -n "$existing_key" ]; then
  echo "Key pair '$KEY_NAME' already exists."
else
  # Create the key pair
  aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$KEY_NAME.pem"
  echo "Key pair '$KEY_NAME' created and saved to '$KEY_NAME.pem'."
fi
chmod 400 "$KEY_NAME.pem"

echo "Spinning up EC2 runner instance"
# Create EC2 Instance
INSTANCE_ID=$(aws ec2 run-instances \
  --region $AWS_DEFAULT_REGION \
  --instance-type $INSTANCE_TYPE \
  --image-id "$INSTANCE_AMI_ID" \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$RUNNER_SG_ID" \
  --iam-instance-profile "Arn=$INSTANCE_PROFILE_ARN" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=SelfHostedGitHubRunner}]' \
  --associate-public-ip-address \
  --key-name "$KEY_NAME" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Waiting for the instance to be in active state"
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_DEFAULT_REGION

echo "EC2 runner created"

COMMANDS=(
  "sudo yum update -y"
  "mkdir actions-runner && cd actions-runner"
  "curl -o actions-runner-linux-x64-2.309.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.309.0/actions-runner-linux-x64-2.309.0.tar.gz"
  "tar xzf ./actions-runner-linux-x64-2.309.0.tar.gz"
  "sudo yum install libicu -y"
  "./config.sh --url https://github.com/cldcvr/aws-sandbox-provisioner --token ALS42MANWGXH423PBY5J3LDFEEDKC --name SandboxProvisionerGitHubRunner --labels self-hosted,aws-sandbox-gh-runner --unattended"
)

# Create the runner and start the configuration experience
#./config.sh --url https://github.com/REPLACE_REPO_OWNER_HERE/REPLACE_REPO_NAME_HERE --token REPLACE_REGISTRATION_TOKEN --name SandboxProvisionerGitHubRunner --labels self-hosted,aws-sandbox-gh-runner --unattended

your_ip=$(curl -s https://ipinfo.io/ip)
aws ec2 authorize-security-group-ingress --region "$AWS_DEFAULT_REGION" --group-id "$RUNNER_SG_ID" --protocol tcp --port 22 --cidr "$your_ip/32" | jq .
echo "Inbound rule for SSH added to security group '$SECURITY_GROUP_NAME' for your IP address ($your_ip)."


# SSH into the EC2 instance and run commands
for cmd in "${COMMANDS[@]}"; do
  ssh -o StrictHostKeyChecking=no -i "$KEY_NAME.pem" "$SSH_USER"@"$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)" "$cmd"
  if [ $? -ne 0 ]; then
    echo "Failed to run command on the EC2 instance: $cmd"
  else
    echo "Command executed successfully: $cmd"
  fi
done

ssh -o StrictHostKeyChecking=no -i "$KEY_NAME.pem" "$SSH_USER"@"$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)" "nohup "./run.sh" > /dev/null 2>&1 &"

aws ec2 revoke-security-group-ingress --region "$AWS_DEFAULT_REGION" --group-id "$RUNNER_SG_ID" --protocol tcp --port 22 --cidr "$your_ip/32" --query 'Return' | jq .
echo "SSH inbound rule deleted."

#aws iam delete-instance-profile \
#  --instance-profile-name GitHubRunnerInstanceProfile
#