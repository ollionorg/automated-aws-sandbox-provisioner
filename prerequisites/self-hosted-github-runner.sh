#!/bin/bash

###################################################
# Self-Hosted Runner Setup Script
###################################################

# Purpose:
# This Bash script simplifies the setup of a self-hosted GitHub runner on an Amazon EC2 instance.
# The runner allows you to execute GitHub Actions workflows within your own infrastructure.


echo -e "${RED}----------------------------------------------------${NC}"
echo -e "      Starting with Self Hosted Runner Setup"
echo -e "${RED}----------------------------------------------------${NC}"

# Function to echo a message in yellow color
print_yellow() {
  echo -e "${YELLOW}$1${NC}"
}

INSTANCE_AMI_ID=$(aws ec2 describe-images --region $AWS_DEFAULT_REGION --filters "Name=name,Values=al2023-ami-2023.2.20231011.0-kernel-6.1-x86_64" --output text --query 'Images[].ImageId')

if [[ -z $INSTANCE_AMI_ID ]]; then
    echo "Could not fetch AMI for the instance in $AWS_DEFAULT_REGION. Please specify manually above. "
else
    echo -e "Using AMI ${RED}$INSTANCE_AMI_ID${NC} to deploy the runner instance"
fi

# Check if the VPC already exists
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=SelfHostedRunnerVPC" --output json | jq -r '.Vpcs[0].VpcId // "null"')

if [[ -z "$VPC_ID" || "$VPC_ID" == "null" ]]; then
  # Create the VPC
  VPC_ID=$(aws ec2 create-vpc --cidr-block "$SELF_HOSTED_RUNNER_VPC_CIDR" --region "$AWS_DEFAULT_REGION" --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=SelfHostedRunnerVPC}]' --output json | jq -r '.Vpc.VpcId')

  if [ -z "$VPC_ID" ]; then
    echo "Error: Failed to create VPC."
    exit 1
  else
    echo "VPC created with ID: $VPC_ID"
  fi
else
  print_yellow "VPC 'SelfHostedRunnerVPC' already exists. Skipping VPC creation."
fi

# Check if the subnet already exists
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=SelfHostedRunnerSubnet"  --output json | jq -r '.Subnets[0].SubnetId // "null"')

if [[ -z "$SUBNET_ID" || "$SUBNET_ID" == "null" ]]; then
  # Create a subnet for the self-hosted runner
  SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$SELF_HOSTED_RUNNER_SUBNET_CIDR" --region "$AWS_DEFAULT_REGION" --availability-zone "$AWS_DEFAULT_REGION"a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=SelfHostedRunnerSubnet}]' --output json | jq -r '.Subnet.SubnetId')
  if [ -z "$SUBNET_ID" ]; then
    echo "Error: Failed to create subnet."
    exit 1
  else
    echo "Subnet created with ID: $SUBNET_ID"
  fi
else
  print_yellow "Subnet 'SelfHostedRunnerSubnet' already exists. Skipping subnet creation."
fi

# Check if the internet gateway already exists
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=SelfHostedRunnerIGW" --output json | jq -r '.InternetGateways[0].InternetGatewayId // "null"')

if [[ -z "$IGW_ID" || "$IGW_ID" == "null" ]]; then
  # Create an internet gateway and attach it to the VPC
  IGW_ID=$(aws ec2 create-internet-gateway --region "$AWS_DEFAULT_REGION" --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=SelfHostedRunnerIGW}]' | jq -r '.InternetGateway.InternetGatewayId')

  if [ -z "$IGW_ID" ]; then
    echo "Error: Failed to create internet gateway."
    exit 1
  else
    echo "Internet Gateway created with ID: $IGW_ID"
  fi

  IGW_ATTACHED=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --region "$AWS_DEFAULT_REGION" | jq -r '.InternetGateways | length')

  if [ "$IGW_ATTACHED" -eq 0 ]; then
      # If no Internet Gateway is attached, attach one
      IGW_ATTATCH_RESPONSE=$(aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" --region "$AWS_DEFAULT_REGION" | jq .)
      echo "Internet Gateway attached to the VPC."
  else
      echo "Internet Gateway is already attached to the VPC."
  fi

else
    print_yellow "Internet Gateway 'SelfHostedRunnerIGW' already exists. Skipping Internet Gateway creation."
fi

ROUTE_TABLE_NAME="RunnerRouteTable"
# Check if the route table already exists
ROUTE_TABLE_ID=$(aws ec2 describe-route-tables --region "$AWS_DEFAULT_REGION" --filters "Name=tag:Name,Values=$ROUTE_TABLE_NAME" --output json | jq -r '.RouteTables[0].RouteTableId')

if [[ -z "$ROUTE_TABLE_ID" || "$ROUTE_TABLE_ID" == "null" ]]; then
  # Create a route table for the subnet
  ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --region "$AWS_DEFAULT_REGION" --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$ROUTE_TABLE_NAME}]" | jq -r '.RouteTable.RouteTableId')

  if [ -z "$ROUTE_TABLE_ID" ]; then
    echo "Error: Failed to create route table."
    exit 1
  else
    echo "Route Table created with ID: $ROUTE_TABLE_ID"
  fi

else
  print_yellow "Route table '$ROUTE_TABLE_NAME' already exists with id : $ROUTE_TABLE_ID. Skipping route table creation."

fi


# Check if the route table is already associated
ASSOCIATION_ID=$(aws ec2 describe-route-tables --route-table-ids "$ROUTE_TABLE_ID" --output json | jq -r '.RouteTables[0].Associations[] | select(.SubnetId == "'"$SUBNET_ID"'") | .RouteTableAssociationId  // "null"')
if [[ -z "$ASSOCIATION_ID" || "$ASSOCIATION_ID" == "null" ]];then
  NEW_ASSOCIATION_ID=$(aws ec2 associate-route-table --route-table-id "$ROUTE_TABLE_ID" --subnet-id "$SUBNET_ID" --output json | jq -r '.AssociationId')

  if [ -z "$NEW_ASSOCIATION_ID" ]; then
    echo "Error: Failed to associate route-table $ROUTE_TABLE_ID to subnet $SUBNET_ID route table."
    exit 1
  else
    echo "Route Table $ROUTE_TABLE_ID associated with subnet $SUBNET_ID with Association ID: $NEW_ASSOCIATION_ID"
  fi
else
    print_yellow "Route table is already associated with the subnet - $ASSOCIATION_ID. Skipping association."
fi

# subnet-0061be354e2010c06
# Add a route to the route table to route traffic to 0.0.0.0/0 through the internet gateway
IGW_ROUTE_STATUS=$(aws ec2 create-route --route-table-id "$ROUTE_TABLE_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" --region "$AWS_DEFAULT_REGION" --query 'Return' --output text)

if ! [[ "$IGW_ROUTE_STATUS" == "True" ]]; then
  echo "Error: Failed to add route through Internet gateway"
  exit 1
else
  echo "Route for 0.0.0.0/0 added through Internet gateway"
fi

# Check if the security group already exists
RUNNER_SG_ID=$(aws ec2 describe-security-groups --filters "Name=tag:Name,Values=$SELF_HOSTED_RUNNER_SG_NAME" --output json | jq -r '.SecurityGroups[0].GroupId // "null"')

if [[ -z "$RUNNER_SG_ID" || "$RUNNER_SG_ID" == "null" ]]; then
  # Create a security group for the self-hosted runner
  RUNNER_SG_ID=$(aws ec2 create-security-group --group-name "$SELF_HOSTED_RUNNER_SG_NAME" \
    --description "Security group for self-hosted GitHub runner" \
    --vpc-id "$VPC_ID" \
    --region "$AWS_DEFAULT_REGION" \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$SELF_HOSTED_RUNNER_SG_NAME}]" | jq -r '.GroupId')

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
else
  print_yellow "Security group $SELF_HOSTED_RUNNER_SG_NAME already exists. Skipping security group creation."
fi

# Check if the IAM instance profile already exists
EXISTING_INSTANCE_PROFILE=$(aws iam get-instance-profile --instance-profile-name "$RUNNER_INSTANCE_PROFILE_NAME" --output json | jq -r '.InstanceProfile // "null"') 2>/dev/null

if [ -n "$EXISTING_INSTANCE_PROFILE" ]; then
  # If the instance profile already exists, echo the information
  echo -e "${YELLOW}IAM instance profile with name $RUNNER_INSTANCE_PROFILE_NAME already exists.${NC}"
  INSTANCE_PROFILE_ARN=$(echo "$EXISTING_INSTANCE_PROFILE" | jq -r '.Arn')
else
  # If it doesn't exist, create the instance profile
  INSTANCE_PROFILE_ARN=$(aws iam create-instance-profile --instance-profile-name "$RUNNER_INSTANCE_PROFILE_NAME" --output json | jq -r '.InstanceProfile.Arn')
  if [ -z "$INSTANCE_PROFILE_ARN" ]; then
    echo "Error: Failed to create IAM instance profile."
    exit 1
  else
    echo "IAM instance profile created with ARN: $INSTANCE_PROFILE_ARN"
  fi
fi

# Check if the role is already attached to the instance profile
EXISTING_ROLE_NAME=$(aws iam list-instance-profiles --query "InstanceProfiles[?InstanceProfileName=='$RUNNER_INSTANCE_PROFILE_NAME'].Roles[0].RoleName | [0]" --output json | jq -r '. // "null"') 2>/dev/null

if [ "$EXISTING_ROLE_NAME" == "$GITHUB_RUNNER_ROLE_NAME" ]; then
  # If the role is already attached, echo the information
  echo -e "${YELLOW}IAM role $GITHUB_RUNNER_ROLE_NAME is already attached to instance profile $RUNNER_INSTANCE_PROFILE_NAME.${NC}"
else
  # If it's not attached, attach the role to the instance profile
  INSTANCE_PROFILE_ROLE_RESPONSE=$(aws iam add-role-to-instance-profile --instance-profile-name "$RUNNER_INSTANCE_PROFILE_NAME" --role-name "$GITHUB_RUNNER_ROLE_NAME" | jq . )
fi

sleep 5

# Check if the key pair already exists
KEY_NAME="self-hosted-runner-keypair"

existing_key=$(aws ec2 describe-key-pairs --region "$AWS_DEFAULT_REGION" --key-names "$KEY_NAME" --output json | jq -r '.KeyPairs[0].KeyName // "null"') 2>/dev/null

if [[ -z "$existing_key" || "$existing_key" == "null" ]]; then
  # Create the key pair
  aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$KEY_NAME.pem"
  echo "Key pair '$KEY_NAME' created and saved to '$KEY_NAME.pem'."
  chmod 600 "$KEY_NAME.pem"

else
  echo -e "${YELLOW}Key pair '$KEY_NAME' already exists.${NC}"
fi

echo "Spinning up EC2 runner instance"

# Check if the instance is already running
EXISTING_INSTANCE=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=SelfHostedGitHubRunner" "Name=instance-state-name,Values=running" --output json | jq -r '.Reservations[0].Instances[0] // ""')

if [ -n "$EXISTING_INSTANCE" ]; then
  # If the instance is already running, echo the information
  INSTANCE_ID=$(echo "$EXISTING_INSTANCE" | jq -r '.InstanceId')
  echo -e "${YELLOW}Instance with ID $INSTANCE_ID is already running.${NC}"
else
  # If it's not running, run the command to create the instance
  INSTANCE_ID=$(aws ec2 run-instances \
    --region "$AWS_DEFAULT_REGION" \
    --instance-type "$RUNNER_INSTANCE_TYPE" \
    --image-id "$INSTANCE_AMI_ID" \
    --subnet-id "$SUBNET_ID" \
    --security-group-ids "$RUNNER_SG_ID" \
    --iam-instance-profile "Arn=$INSTANCE_PROFILE_ARN" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=SelfHostedGitHubRunner}]' \
    --associate-public-ip-address \
    --key-name "$KEY_NAME" \
    --query 'Instances[0].InstanceId' \
    --output text)

  if [ -z "$INSTANCE_ID" ]; then
    echo "Error: Failed to create the instance."
    exit 1
  else
    echo "Instance with ID $INSTANCE_ID created."
  fi
fi



echo "Waiting for the instance to be in the active state..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_DEFAULT_REGION"

echo "EC2 runner instance is active."

echo "Setting up runner and registering to the repository $REPO_NAME"
# Runner registration commands
COMMANDS=(
  "sudo yum update -y"
  "mkdir actions-runner"
  "cd actions-runner && curl -o actions-runner-linux-x64-2.309.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.309.0/actions-runner-linux-x64-2.309.0.tar.gz"
  "cd actions-runner && tar xzf ./actions-runner-linux-x64-2.309.0.tar.gz"
  "cd actions-runner && sudo yum install libicu -y"
  "cd actions-runner && sudo dnf update -y && sudo dnf install docker -y"
  "cd actions-runner && sudo systemctl start docker && sudo systemctl enable docker"
  "cd actions-runner && sudo usermod -aG docker $SSH_USER"
  "cd actions-runner && sudo setfacl --modify user:$SSH_USER:rw /var/run/docker.sock"
  "cd actions-runner && ./config.sh --url https://github.com/$REPO_OWNER/$REPO_NAME --token $GITHUB_RUNNER_REGISTRATION_TOKEN --name SandboxProvisionerGitHubRunner --labels self-hosted,$SELF_HOSTED_RUNNER_LABEL --unattended"
)

your_ip=$(curl -s https://ipinfo.io/ip)
ADD_SSH_SG_RULE=$(aws ec2 authorize-security-group-ingress --region "$AWS_DEFAULT_REGION" --group-id "$RUNNER_SG_ID" --protocol tcp --port 22 --cidr "$your_ip/32" --query 'Return' --output text)

if [[ $ADD_SSH_SG_RULE == "True" ]]; then
  echo "Inbound rule for SSH added to security group '$SELF_HOSTED_RUNNER_SG_NAME' for your IP address ($your_ip)."
else
  echo "Error creating an Inbound rule for SSH"
  echo "Runner Registration might fail. Run registration commands manually by connecting to the instance. Refer to the COMMANDS in the script or the docs at https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners"
fi

sleep 10

# SSH into the EC2 instance and run commands
for cmd in "${COMMANDS[@]}"; do
  ssh -o StrictHostKeyChecking=no -i "$KEY_NAME.pem" "$SSH_USER"@"$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)" "$cmd"
  if [ $? -ne 0 ]; then
    echo "Failed to run a command on the EC2 instance: $cmd"
  else
    echo "Command executed successfully: $cmd"
  fi
done

ssh -o StrictHostKeyChecking=no -i "$KEY_NAME.pem" "$SSH_USER"@"$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)" "nohup newgrp docker &"
sleep 5
echo "Starting the runner listener"
ssh -o StrictHostKeyChecking=no -i "$KEY_NAME.pem" "$SSH_USER"@"$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)" "cd actions-runner; nohup ./run.sh > /dev/null 2>&1 &"
echo "Runner configured and active"
REVOKE_SSH_SG_RULE=$(aws ec2 revoke-security-group-ingress --region "$AWS_DEFAULT_REGION" --group-id "$RUNNER_SG_ID" --protocol tcp --port 22 --cidr "$your_ip/32" --query 'Return' --output text)
if [[ $REVOKE_SSH_SG_RULE == "True" ]]; then
  echo "SSH inbound rule deleted"
else
  echo "Error deleting SSH inbound rule"
fi

echo -e "${RED}----------------------------------------------------${NC}"
echo -e "Self-Hosted Runner Setup Completed"
echo -e "${RED}----------------------------------------------------${NC}"
