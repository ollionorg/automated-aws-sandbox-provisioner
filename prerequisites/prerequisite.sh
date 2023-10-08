#!/bin/bash

set -e


# All_Variables_Here
export policy_name="SandboxProvisionerPolicy"
export policy_file="sandbox_provisioner_policy.json"
export role_name="SandboxAccountManagementRole"
export lambda_policy_name="SandboxLambdaPolicy"
export lambda_policy_file="sandbox_lambda_policy.json"
export lambda_role_name="SandboxLambdaRole"
export SECRET_NAME="sandbox/git"
export SECRET_KEY_NAME="git_token"
export AWS_DEFAULT_REGION="us-east-1"
export SSO_ENABLED=true


CLEANUP="$1" # If cleanup is passed as argument, it will cleanup the resources created by the script
# Define color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local message="$1"
    local color="$2"
    echo -e "${color}${message}${NC}"
}

# Function to check if the AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &>/dev/null; then
        print_message "AWS CLI is not installed. Please install the AWS CLI and configure it with appropriate credentials." "$RED"
        exit 1
    fi
}

# Function to check if the AWS CLI is configured with valid credentials
check_aws_cli_configuration() {
    if ! aws sts get-caller-identity &>/dev/null; then
        print_message "AWS CLI is not configured with valid credentials. Please run 'aws configure' to set up your credentials or use your preferred method to authenticate." "$RED"
        exit 1
    fi
}

# Function to validate JSON file existence and readability
validate_json_file() {
    local json_file="$1"

    if [ ! -f "$json_file" ]; then
        print_message "JSON file '$json_file' not found." "$RED"
        exit 1
    fi

    if ! jq '.' "$json_file" &>/dev/null; then
        print_message "Invalid JSON file: '$json_file'. Please ensure the JSON file is valid." "$RED"
        exit 1
    fi
}

# Function to create the policy in the AWS Management Account
create_aws_policy() {
    local policy_name="$1"
    local policy_file="$2"

    if ! aws iam create-policy --policy-name "$policy_name" --policy-document "file://$policy_file"; then
        print_message "Failed to create the policy in AWS Management Account." "$RED"
        exit 1
    fi

    print_message "Policy '$policy_name' created successfully in AWS Management Account." "$GREEN"
}

# Function to check if an IAM Policy already exists
check_existing_policy() {
    local policy_name="$1"

    if aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$policy_name" &>/dev/null; then
        read -rp "Policy '$policy_name' already exists. Do you want to use the existing policy? (y/n): " reuse_policy
        if [[ "$reuse_policy" =~ ^[Yy]$ ]]; then
            return 0
        else
            return 1
        fi
    fi
    return 1
}

# Function to check if an IAM Role exists
check_existing_role() {
    local role_name="$1"
    local policy_name="$2"

    if aws iam get-role --role-name "$role_name" &>/dev/null; then
        read -rp "Role '$role_name' already exists. Do you want to use the existing role? (y/n): " reuse_role
        if [[ "$reuse_role" =~ ^[Yy]$ ]]; then
            if check_policy_attachment "$role_name" "$policy_name"; then
                print_message "Using existing IAM Role: '$role_name'" "$GREEN"
            else
                attach_policy_to_role "$role_name" "$policy_name"
            fi
            return 0
        else
            return 1
        fi
    fi
    return 1
}

# Function to check if the policy is attached to the role
check_policy_attachment() {
    local role_name="$1"
    local policy_name="$2"

    local policy_arn="arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$policy_name"

    if aws iam list-attached-role-policies --role-name "$role_name" | jq -r ".AttachedPolicies[].PolicyArn" | grep -q "$policy_arn"; then
        echo "Policy '$policy_name' is already attached to the role '$role_name'."
        return 0
    fi

    return 1
}

# Function to attach the policy to the role
attach_policy_to_role() {
    local role_name="$1"
    local policy_name="$2"

    if ! aws iam attach-role-policy --role-name "$role_name" --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$policy_name" &>/dev/null; then
        echo "Failed to attach the policy '$policy_name' to the IAM Role: '$role_name'."
        exit 1
    fi

    echo "Policy '$policy_name' attached to the IAM Role '$role_name' successfully."
}

# Function to create an AWS IAM Role and attach the policy to it
create_aws_role() {
    local role_name="$1"
    local policy_name="$2"

    if ! aws iam create-role --role-name "$role_name" --assume-role-policy-document '{"Version": "2012-10-17","Statement": [{"Effect": "Allow","Principal": {"Service": "organizations.amazonaws.com"},"Action": "sts:AssumeRole"}]}' &>/dev/null; then
        print_message "Failed to create the IAM Role: '$role_name'. Possibly due to duplicate name or permission issues" "$RED"
        exit 1
    fi

    if check_policy_attachment "$role_name" "$policy_name"; then
        echo "Using existing IAM Role: '$role_name'"
    else
        attach_policy_to_role "$role_name" "$policy_name"
    fi
}


create_aws_secret() {
    local secret_name="$1"
    local secret_key="$2"
    local secret_value="$3"

    # Check if the secret already exists
    if aws secretsmanager describe-secret --secret-id "$secret_name" &>/dev/null; then
        print_message "Secret '$secret_name' already exists in AWS Secrets Manager. Update the secret value if required" "$YELLOW"
    else
        # Create the secret if it doesn't exist
        if ! aws secretsmanager create-secret --name "$secret_name" --secret-string "{\"$secret_key\":\"$secret_value\"}" &>/dev/null; then
            print_message "Failed to create the secret '$secret_name' in AWS Secrets Manager." "$RED"
            exit 1
        fi

        print_message "Secret '$secret_name' created successfully in AWS Secrets Manager." "$GREEN"
    fi
}



# Function to perform cleanup
cleanup() {
    # Delete the lambda role if it exists
    if aws iam get-role --role-name "$lambda_role_name" &>/dev/null; then
        aws iam detach-role-policy --role-name "$lambda_role_name" --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$lambda_policy_name"
        aws iam delete-role --role-name "$lambda_role_name"
    fi

    # Delete the lambda policy if it exists
    if aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$lambda_policy_name" &>/dev/null; then
        aws iam delete-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$lambda_policy_name"
    fi

    # Delete the IAM role if it exists
    if aws iam get-role --role-name "$role_name" &>/dev/null; then
        aws iam detach-role-policy --role-name "$role_name" --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$policy_name"
        aws iam delete-role --role-name "$role_name"
    fi

    # Delete the IAM policy if it exists
    if aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$policy_name" &>/dev/null; then
        aws iam delete-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$policy_name"
    fi

    # Delete the secret from AWS Secrets Manager if it exists
    if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" &>/dev/null; then
        aws secretsmanager delete-secret --secret-id "$SECRET_NAME"
    fi

    print_message "Cleanup completed" "$GREEN"
}


main() {


    # Check if the AWS CLI is installed
    check_aws_cli

    REPO_OWNER=$(git config --get remote.origin.url | awk -F ':' '{print $2}' | cut -d '/' -f 1)
    REPO_NAME=$(basename -s .git $(git config --get remote.origin.url))


    # Check if the script was called with the "cleanup" argument
    if [[ "$CLEANUP" == "cleanup" ]]; then
        check_aws_cli_configuration
        echo -e "${RED}WARNING: This will delete all resources created by the script. This action is irreversible.${NC}"
        read -rp "Are you sure you want to proceed with cleanup? (y/n): " confirm_cleanup
        if [[ "$confirm_cleanup" =~ ^[Yy]$ ]]; then
            cleanup
            exit 0
        else
            print_message "Cleanup canceled." "$YELLOW"
            exit 0
        fi
    fi

    print_message "Running the prerequisite script to provision resources required for AWS Sandbox provisioner" "$GREEN"
    echo -e "Refer the README.md file in the current dir to know about the resources that will be created [Quick Start point no.5]\n"

    echo -e "Using region : ${RED}$AWS_DEFAULT_REGION${NC} to deploy the resources."
    echo -e "GitHub Repo Owner : ${YELLOW}$REPO_OWNER${NC}"
    echo -e "GitHub Repo Name : ${YELLOW}$REPO_NAME${NC}"
    sleep 1

    echo -e "$YELLOW"
    read -rp "Make sure you are authenticated to the management account and the default region above is as expected. Do you want to continue? (y/n): " continue
    echo -e "$NC"
    if [[ "$continue" =~ ^[Yy]$ ]]; then
        true
    else
        print_message "Exiting..." "$RED"
        exit 0
    fi

    print_message "Checking prerequisites..." "$GREEN"

    # Check AWS CLI configuration with valid credentials
    check_aws_cli_configuration

    # Validate master account
    if ! [[ $(aws organizations describe-organization --query "Organization.MasterAccountId" --output text) -eq $(aws sts get-caller-identity --query "Account" --output text) ]];then
      echo -e "${RED}This is not a master account. Exiting...${NC}"
      exit 1
    fi

    # Check if SSO is enabled
    if [ "$SSO_ENABLED" = "true" ]; then
      # Run the AWS CLI command and store the output in SSO_INSTANCE_INFO variable
      SSO_INSTANCE_INFO=$(aws sso-admin list-instances | jq -r '.Instances[0]')

      # Check if the SSO_INSTANCE_INFO variable is not empty
      if [ -n "$SSO_INSTANCE_INFO" ]; then
        # Extract the instance ARN and Identity Store ID from the JSON
        SSO_INSTANCE_ARN=$(echo "$SSO_INSTANCE_INFO" | jq -r '.InstanceArn')
        SSO_IDENTITY_STORE_ID=$(echo "$SSO_INSTANCE_INFO" | jq -r '.IdentityStoreId')

        # Display the instance ARN and Identity Store ID
        echo -e "\nSSO instance ARN: ${RED}$SSO_INSTANCE_ARN ${NC}"
        echo -e "Identity Store ID: ${RED}$SSO_IDENTITY_STORE_ID ${YELLOW}"
        read -rp "Confirm the above SSO Instance Details. Do you want to continue? (y/n): " continue
        echo -e "${NC}"
        if [[ "$continue" =~ ^[Yy]$ ]]; then
            true
        else
            print_message "Exiting..." "$RED"
            exit 0
        fi
        # Check if there are multiple instances and print them on the screen
        NUM_INSTANCES=$(aws sso-admin list-instances | jq '.Instances | length')
        if [ "$NUM_INSTANCES" -gt 1 ]; then
          echo "Other instance ARNs and Identity Store IDs available:"
          aws sso-admin list-instances | jq -r '.Instances[] | "Instance ARN: \(.InstanceArn)\nIdentity Store ID: \(.IdentityStoreId)\n"'
        fi

        exit 0

        # Replace the instance ARN and Identity Store ID in the aws-provision.yml GitHub workflow file
        # Assuming aws-provision.yml contains placeholder texts `INSTANCE_ARN_PLACEHOLDER` and `IDENTITY_STORE_ID_PLACEHOLDER`
        if [ -f "aws-provision.yml" ]; then
          sed -i "s|INSTANCE_ARN_PLACEHOLDER|$SSO_INSTANCE_ARN|" ../../github/workflows/aws-provision.yml
          sed -i "s|INSTANCE_ARN_PLACEHOLDER|$SSO_INSTANCE_ARN|" ../../github/workflows/aws-provision.yml
          sed -i "s|IDENTITY_STORE_ID_PLACEHOLDER|$SSO_IDENTITY_STORE_ID|" ../../github/workflows/aws-provision.yml
          echo "Updated aws-provision.yml with the instance ARN and Identity Store ID."
        else
          echo "Warning: aws-provision.yml not found. Please make sure to update the file manually."
        fi
      else
        echo -e "${RED}No SSO instance found. Make sure you are in correct account or disable the flag ${GREEN}'SSO_ENABLED'${NC}"
      fi
    else
      echo "SSO is not enabled. Skipping SSO-related commands."
    fi

    echo -e "${YELLOW}Substituting variables in files.${NC}"
    find . -type f -iname "*.json" -exec bash -c "m4 -D REPLACE_AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} -D REPLACE_AWS_MANAGEMENT_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text) -D REPLACE_SECRET_NAME_HERE=${SECRET_NAME} {} > {}.m4  && cat {}.m4 > {} && rm {}.m4" \;

    find ../provision -type f -iname "*.py" -exec bash -c "m4 -D REPLACE_REPO_OWNER_HERE=${REPO_OWNER} -D REPLACE_REPO_NAME_HERE=${REPO_NAME} -D REPLACE_SECRET_KEY_NAME_HERE=${SECRET_KEY_NAME} -D REPLACE_AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} -D REPLACE_AWS_MANAGEMENT_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text) -D REPLACE_SECRET_NAME_HERE=${SECRET_NAME} {} > {}.m4  && cat {}.m4 > {} && rm {}.m4" \;

    find ../../.github/workflows -type f -iname "*.yml" -exec bash -c "m4 -D REPLACE_MANAGEMENT_ROLE_HERE=${role_name} -D REPLACE_AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} -D REPLACE_AWS_MANAGEMENT_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text) {} > {}.m4  && cat {}.m4 > {} && rm {}.m4" \;


    echo -e "${YELLOW}Completed substituting.${NC}"
    # Validate the JSON file existence and readability for the provisioner policy
    echo -e "\nValidating the policy files."
    validate_json_file "$policy_file"
    validate_json_file "$lambda_policy_file"
    sleep 1
    echo -e "${GREEN}Looks good, proceeding...${NC}\n"

    # Check if the provisioner policy already exists and prompt for reuse
    if check_existing_policy "$policy_name"; then
        print_message "Using existing policy: '$policy_name'" "$GREEN"
    else
        # Create the provisioner policy in the AWS Management Account
        create_aws_policy "$policy_name" "$policy_file"
    fi


    # Check if the role already exists and prompt for reuse
    if ! check_existing_role "$role_name" "$policy_name"; then
        create_aws_role "$role_name" "$policy_name"
    fi

    # Check if the lambda policy already exists and prompt for reuse
    if check_existing_policy "$lambda_policy_name"; then
        print_message "Using existing policy: '$lambda_policy_name'" "$GREEN"
    else
        # Create the lambda policy in the AWS Management Account
        create_aws_policy "$lambda_policy_name" "$lambda_policy_file"
    fi

    # Check if the role already exists and prompt for reuse
    if ! check_existing_role "$lambda_role_name" "$lambda_policy_name"; then
        create_aws_role "$lambda_role_name" "$lambda_policy_name"
    fi



    # Prompt user to enter GitHub token (GITHUB_TOKEN)
    read -rp "Enter GITHUB_TOKEN (used to trigger cleanup workflow from lambda, Will be stored securely in AWS Secrets Manager): " github_token

    # Create the secret in AWS Secrets Manager
    create_aws_secret "$SECRET_NAME" "$SECRET_KEY_NAME" "$github_token"

    print_message "Done" "$GREEN"
    exit 0
}

main
