#!/bin/bash

set -e


export policy_name="SandboxProvisionerPolicy"
export policy_file="sandbox_provisioner_policy.json"
export SANDBOX_MANAGEMENT_ROLE_NAME="SandboxAccountManagementRole"
export LAMBDA_POLICY_NAME="SandboxLambdaPolicy"
export lambda_policy_file="sandbox_lambda_policy.json"
export lambda_role_name="SandboxLambdaRole"
export PERMISSION_SET_NAME="SandboxAdministratorAccess"                                   # Define the name for the permission set
export MANAGED_POLICY_ARN_FOR_SANDBOX_USERS="arn:aws:iam::aws:policy/AdministratorAccess" # Specify the AWS managed policy for AdministratorAccess
export PERMISSION_SET_NAME="SandboxAdministratorAccess"                                   # Define the name for the permission set
export SECRET_NAME="sandbox/git"
export SECRET_KEY_NAME="git_token"
export SELF_HOSTED_RUNNER_SG_NAME="SelfHostedRunnerSecurityGroup"
export RUNNER_INSTANCE_PROFILE_NAME="GitHubRunnerInstanceProfile"
export GITHUB_RUNNER_ROLE_NAME="GitHubRunnerRole"
export SSH_USER="ec2-user"
export SELF_HOSTED_RUNNER_VPC_CIDR="10.129.10.0/26"
export SELF_HOSTED_RUNNER_SUBNET_CIDR="10.129.10.0/28"
export INSTANCE_TYPE="t2.micro"

export AWS_DEFAULT_REGION="us-east-1"                            # e.g "us-east-1" Identity Center default region used by management account
export AWS_ADMINS_EMAIL="aws-admins@yourdomain.com"                              # e.g "aws-admins@yourdomain.com" AWS admins DL required during sandbox account setup
export SSO_ENABLED="true"                                   # set to true if your organization has SSO enabled and uses AWS IAM Identity center or set to false
export TEAM_NAMES=("dev-team")                                  # e.g ("dev-team" "qa-team" "devops-team") [ Please use the same syntax as example ]
export REQUIRES_MANAGER_APPROVAL="true"                 # set to true if approval is required for sandbox account of duration more than APPROVAL_DURATION hours duration
export APPROVAL_DURATION=8                              # Duration of hours of sandbox account request post which workflow requires manager's approval automatically.
export SELF_HOSTED_RUNNER_LABEL="aws-sandbox-gh-runner" # Use default label "aws-sandbox-gh-runner" to create and register a runner for the sandbox provisioner workflow. or else use already created runner by changing the label value.
export PARENT_OU_ID=""                                  # Keep blank to create the OUs under root in the organization by default.
export FRESHDESK_URL=""                                 # Leave blank if not applicable. In this case freshdesk APIs are used for ticket creation and updates. Provide freshdesk api url like 'https://your_freshdesk_domain.freshdesk.com'
export ENABLE_SLACK_NOTIFICATION=""                     # Set to true to enable slack notification in the workflows. Defaults to false



# Define color codes
export GREEN='\033[0;32m'
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export NC='\033[0m' # No Color
export TEAM_SANDBOX_OUs=() # Keep blank
export TEAM_POOL_OUs=() # Keep blank

##########################################################

if [[ -z $AWS_ADMINS_EMAIL ]]; then
  echo -e "${RED}\nPlease provide aws admins DL or a admin user email ${YELLOW}[AWS_ADMINS_EMAIL] ${GREEN}e.g aws-admins@yourdomain.com${NC}"
  exit 1
fi

# Check if AWS_DEFAULT_REGION is empty or blank
if [ -z "$AWS_DEFAULT_REGION" ]; then
  echo -e "${RED}\nAWS_DEFAULT_REGION is required. Please set the variable before running this script.${NC}"
  exit 1
fi

if [ -z "$SSO_ENABLED" ]; then
  echo -e "${RED}SSO_ENABLED flag value is required. Please set the variable before running this script.${NC}"
  echo -e "If not applicable set the value to ${YELLOW}false${NC}"
  exit 1
fi

if [[ -z $FRESHDESK_URL ]]; then
    export ENABLE_HELPDESK_NOTIFICATION="false"
    export FRESHDESK_URL="NA"
else
    export ENABLE_HELPDESK_NOTIFICATION="true"
    echo -e "You have provided Freshdesk API url as $FRESHDESK_URL"
    echo -e "Make sure GitHub secret '${YELLOW}FRESHDESK_API_KEY${NC}' is added in the same repository Secrets"
    echo -e "$GREEN"
    read -rp "Do you want to continue? (y/n): " continue
    echo -e "$NC"
    if [[ "$continue" =~ ^[Yy]$ ]]; then
        true
    else
        echo -e "${RED}Exiting...${NC}"
        exit 0
    fi
fi

if [[ $ENABLE_SLACK_NOTIFICATION == "true" ]]; then
    echo -e "You have opted to enable slack notification in the workflow"
    echo -e "Make sure GitHub secret '${YELLOW}SANDBOX_SLACK_WEBHOOK${NC}' is added in the same repository Secrets"
    echo -e "The secret should contain Incoming Slack Webhook" #TODO
    echo -e "$GREEN"
    read -rp "Do you want to continue? (y/n): " continue
    echo -e "$NC"
    if [[ "$continue" =~ ^[Yy]$ ]]; then
        true
    else
        echo -e "${RED}Exiting...${NC}"
        exit 0
    fi
else
    export ENABLE_SLACK_NOTIFICATION="false"
fi

#TODO
#ADMIN_EMAIL_PRINCIPAL="${AWS_ADMINS_EMAIL%%@*}"  # Gets everything before the last "@"
#EMAIL_DOMAIN="${AWS_ADMINS_EMAIL#*@}"

# Check if at least one team is defined
if [ ${#TEAM_NAMES[@]} -eq 0 ]; then
    echo -e "${RED}\nError: At least one team must be defined.${NC}"
        echo -e "Please refer the OU prerequisite readme doc - ${YELLOW}aws/prerequisites/OU_PREREQUISITES.md${NC}"

    exit 1
fi

# Check if any team name is blank
for team_name in "${TEAM_NAMES[@]}"; do
    if [ -z "$team_name" ]; then
        echo -e "${RED}\nError: Team name cannot be blank.${NC}"
        echo -e "\ne.g ${YELLOW}export TEAM_NAMES=(\"dev-team\" \"qa-team\" \"devops-team\")${NC}\n"
        echo -e "At least one team name is expected here so as to create the OU for accounts and pool"
        exit 1
    fi
done

if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Please install jq to continue."
    exit 1
fi

#####################################################################################################

check_admin_access() {
    # Check if the user has administrator access
    if aws iam list-attached-user-policies --user-name "$(aws sts get-caller-identity --query "Arn" --output text | cut -d'/' -f2)" | grep -q "AdministratorAccess"; then
        echo -e "Admin access prerequisite check successful ✅"
    else
        echo -e "${RED}WARNING: This script should be executed by an admin to set up the sandbox provisioner properly.${NC}"
        echo -e "You must have ${YELLOW}AdministratorAccess${NC} to proceed."
        echo "Do you want to proceed anyway? (y/n)"
        read -r response
        if [ "$response" != "y" ]; then
            echo "Exiting..."
            exit 1
        else
            echo "Proceeding..."
        fi
    fi
}

create_ou() {
    local ou_name="$1"
    local parent_ou="$2"

    # Attempt to create the OU, but capture any errors in a variable
    create_ou_result=$(aws organizations create-organizational-unit --parent-id "$parent_ou" --name "$ou_name" 2>&1)

    # Check if the result contains the error indicating a duplicate OU
    if [[ $create_ou_result =~ "DuplicateOrganizationalUnitException" ]]; then
        # If a duplicate OU exists, try to get its ID
        existing_ou_id=$(aws organizations list-organizational-units-for-parent --parent-id "$parent_ou" |
                            jq -r '.OrganizationalUnits[] | select(.Name == "'"$ou_name"'") | .Id')

        if [ -n "$existing_ou_id" ]; then
            echo "$existing_ou_id"
        else
            echo "OU with the same name already exists"
            echo "Failed to retrieve existing OU ID."
            exit 1
        fi
    elif [[ $create_ou_result =~ "Arn" ]]; then
        # If the OU was created successfully, echo its ID
        OU_ID_CREATED=$(echo "$create_ou_result" | jq -r '.OrganizationalUnit.Id')
        echo "$OU_ID_CREATED"
    else
        echo "An error occurred while creating the OU: $create_ou_result"
        exit 1
    fi
}

# Function to add OU to the array
add_ou_to_array() {
    local team_ou="$1"
    local team_pool_ou="$2"
    TEAM_SANDBOX_OUs+=("$team_ou")
    TEAM_POOL_OUs+=("$team_pool_ou")
}


create_sandbox_ous() {
    echo "-------------------------------"
    echo "Creating main Sandbox OU"
    SANDBOX_OU_ID=$(create_ou "SANDBOX_OU" "$PARENT_OU_ID")
    echo "Sandbox OU id : $SANDBOX_OU_ID"

    # Iterate through the team names and create OUs
    for team_name in "${TEAM_NAMES[@]}"; do
        echo "-------------------------------"
        echo "Working on OU creation for $team_name"
        team_sandbox_ou="${team_name}-sandbox-ou"
        team_sandbox_pool_ou="${team_name}-sandbox-pool-ou"

        TEAM_OU=$(create_ou "$team_sandbox_ou" "$SANDBOX_OU_ID")
        TEAM_POOL_OU=$(create_ou "$team_sandbox_pool_ou" "$TEAM_OU")
        sleep 1
        add_ou_to_array "$TEAM_OU" "$TEAM_POOL_OU"
        echo "Created OUs for $team_name : $TEAM_OU, $TEAM_POOL_OU"
    done
    echo "-------------------------------"
}

self_hosted_runner_prerequisites_check() {
    # Check the value of SELF_HOSTED_RUNNER_LABEL
    if [ "$SELF_HOSTED_RUNNER_LABEL" != "aws-sandbox-gh-runner" ]; then
      echo -e "\n${RED}-----------IMPORTANT----------${NC}"
      echo -e "As a runner label other than 'aws-sandbox-gh-runner' was provided, you intend to use existing runner instance/instances for this sandbox provisioner workflow."
      echo -e "Make sure that the runner instance has the ability to ${YELLOW}assume the $SANDBOX_MANAGEMENT_ROLE_NAME in the management account${NC} to perform the tasks. If not, add the necessary policies"
      echo -e "\nIn case you want to make use of the runner created by this workflow, make sure to rename the variable ${YELLOW}SELF_HOSTED_RUNNER_LABEL${NC} to ${YELLOW}\"aws-sandbox-gh-runner\"${NC}"
      echo -e "${RED}-------READ THOROUGHLY-------${NC}"

      echo -e "$GREEN"
      read -rp "Do you want to continue? (y/n): " continue
      echo -e "$NC"
      if [[ "$continue" =~ ^[Yy]$ ]]; then
          true
      else
          echo -e "${RED}Exiting...${NC}"
          exit 0
      fi
    fi

    #list all existing VPCs and their CIDR blocks
    existing_vpcs=$(aws ec2 describe-vpcs --region "$AWS_DEFAULT_REGION" --query "Vpcs[].CidrBlock" --output json | jq -r '.[]')

    # Loop through the existing VPCs and check for conflicts
    for existing_cidr in $existing_vpcs; do
        if [ "$existing_cidr" == "$SELF_HOSTED_RUNNER_VPC_CIDR" ]; then
            echo "Error: CIDR block $SELF_HOSTED_RUNNER_VPC_CIDR conflicts with an existing VPC."
            exit 1
        fi
    done

    echo -e "\nSelf Hosted runner prerequisite check successful ✅"

}

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
    echo -e "\nAWS cli prerequisites check successful ✅"
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

    POLICY_ID=$(aws iam create-policy --policy-name "$policy_name" --policy-document "file://$policy_file" --query 'Policy.PolicyId' --output text)

    if [[ -z $POLICY_ID ]]; then
        print_message "Failed to create the policy $policy_name in AWS Management Account." "$RED"
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
    local SANDBOX_MANAGEMENT_ROLE_NAME="$1"
    local policy_name="$2"

    if aws iam get-role --role-name "$SANDBOX_MANAGEMENT_ROLE_NAME" &>/dev/null; then
        read -rp "Role '$SANDBOX_MANAGEMENT_ROLE_NAME' already exists. Do you want to use the existing role? (y/n): " reuse_role
        if [[ "$reuse_role" =~ ^[Yy]$ ]]; then
            if check_policy_attachment "$SANDBOX_MANAGEMENT_ROLE_NAME" "$policy_name"; then
                print_message "Using existing IAM Role: '$SANDBOX_MANAGEMENT_ROLE_NAME'" "$GREEN"
            else
                attach_policy_to_role "$SANDBOX_MANAGEMENT_ROLE_NAME" "$policy_name"
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
    local SANDBOX_MANAGEMENT_ROLE_NAME="$1"
    local policy_name="$2"

    local policy_arn="arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$policy_name"

    if aws iam list-attached-role-policies --role-name "$SANDBOX_MANAGEMENT_ROLE_NAME" | jq -r ".AttachedPolicies[].PolicyArn" | grep -q "$policy_arn"; then
        echo "Policy '$policy_name' is already attached to the role '$SANDBOX_MANAGEMENT_ROLE_NAME'."
        return 0
    fi

    return 1
}

# Function to attach the policy to the role
attach_policy_to_role() {
    local SANDBOX_MANAGEMENT_ROLE_NAME="$1"
    local policy_name="$2"

    if ! aws iam attach-role-policy --role-name "$SANDBOX_MANAGEMENT_ROLE_NAME" --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$policy_name" &>/dev/null; then
        echo "Failed to attach the policy '$policy_name' to the IAM Role: '$SANDBOX_MANAGEMENT_ROLE_NAME'."
        exit 1
    fi

    echo "Policy '$policy_name' attached to the IAM Role '$SANDBOX_MANAGEMENT_ROLE_NAME' successfully."
}

# Function to create an AWS IAM Role and attach the policy to it
create_management_role() {
    # Define your JSON policy in a variable
    local MGMT_ROLE_POLICY_JSON
    MGMT_ROLE_POLICY_JSON='{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "AWS": "arn:aws:iam::'$(aws sts get-caller-identity --query "Account" --output text)':role/'${GITHUB_RUNNER_ROLE_NAME}'"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }'

    # Create the IAM role with the policy
    if ! aws iam create-role --role-name "$SANDBOX_MANAGEMENT_ROLE_NAME" --assume-role-policy-document "$MGMT_ROLE_POLICY_JSON" &>/dev/null; then
        print_message "Failed to create the IAM Role: '$SANDBOX_MANAGEMENT_ROLE_NAME'" "$RED"
        exit 1
    fi

    if check_policy_attachment "$SANDBOX_MANAGEMENT_ROLE_NAME" "$policy_name"; then
        echo "Using existing IAM Role: '$SANDBOX_MANAGEMENT_ROLE_NAME'"
    else
        attach_policy_to_role "$SANDBOX_MANAGEMENT_ROLE_NAME" "$policy_name"
    fi
}

create_lambda_role() {
    # Define your JSON policy in a variable
    local LAMBDA_ROLE_POLICY_JSON='{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "lambda.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }'

    create_aws_role "$lambda_role_name" "$LAMBDA_POLICY_NAME"

    # Create the IAM role with the policy
    if ! aws iam create-role --role-name "$lambda_role_name" --assume-role-policy-document "$LAMBDA_ROLE_POLICY_JSON" &>/dev/null; then
        print_message "Failed to create the IAM Role: '$lambda_role_name'" "$RED"
        exit 1
    fi

    if check_policy_attachment "$lambda_role_name" "$LAMBDA_POLICY_NAME"; then
        echo "Using existing IAM Role: '$lambda_role_name'"
    else
        attach_policy_to_role "$lambda_role_name" "$LAMBDA_POLICY_NAME"
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


main() {

    export REPO_OWNER=$(git config --get remote.origin.url | awk -F ':' '{print $2}' | cut -d '/' -f 1)
    export REPO_NAME=$(basename -s .git $(git config --get remote.origin.url))
    echo -e "${RED}----------------------------------------------------${NC}"
    echo -e "Starting with Sandbox Provisioner Prerequisite Setup"
    echo -e "${RED}----------------------------------------------------${NC}"
    print_message "Below resources will be created and related files will be updated." "$GREEN"
    sleep 1
    echo -e "
1. IAM policies [ $policy_name, $LAMBDA_POLICY_NAME ]
2. IAM roles [ $SANDBOX_MANAGEMENT_ROLE_NAME, $lambda_role_name ]
3. Secret containing GitHub token which will be used for triggering workflow to revoke access of sandbox
4. SelfHosted GitHub runner along with related components with registration [ VPC, Subnet, SecurityGroup, Role, InstanceProfile, InternetGateway, Rule, Routes ] subject to runner label
5. Organizational Unit [ OU ] structure for the sandbox provisioner
6. All the files related to the Sandbox Provisioner will be updated with required variables.
"
    sleep 1

    echo -e "Using region      : ${YELLOW}$AWS_DEFAULT_REGION${NC} to deploy the resources."
    echo -e "GitHub Repo Owner : ${YELLOW}$REPO_OWNER${NC}"
    echo -e "GitHub Repo Name  : ${YELLOW}$REPO_NAME${NC}"
    sleep 1

    echo -e "\nMake sure you are authenticated to the management account and the default region above is as expected."
    echo -e "$GREEN"
    read -rp "Do you want to continue? (y/n): " continue
    echo -e "$NC"
    if [[ "$continue" =~ ^[Yy]$ ]]; then
        # Validate master account
        if ! [[ $(aws organizations describe-organization --query "Organization.MasterAccountId" --output text) = $(aws sts get-caller-identity --query "Account" --output text) ]];then
          echo -e "${RED}This is not a master account under a organization. Please authenticate to a master account in order to setup the prerequisites. Exiting...${NC}"
          exit 1
        fi
    else
        print_message "Exiting..." "$RED"
        exit 0
    fi

    # Prompt user to enter GitHub token (github_token)
    read -rp "Enter GitHub token with access to the repository '$REPO_NAME' and workflows. It will be stored securely in AWS Secrets Manager ] : " github_token

    if [[ -z "$github_token" ]]; then
        echo -e "${RED}Empty token value, Please enter valid GitHub token with access to the repository and workflows"
        exit 1
    fi
    # Use GitHub API to get token details
    token_scopes=$(curl -sS -f -I -H "Authorization: token ${github_token}" https://api.github.com | grep ^x-oauth-scopes: | cut -d' ' -f2- | tr -d "[:space:]")

    # Check if the "workflow" scope is present in the token's scopes
    if [[ ! $token_scopes == *workflow* ]]; then
        echo -e "\n${RED}IMPORTANT${NC} Token does not have the ${YELLOW}'workflow'${NC} scope."
        echo "Please provide a valid token with the necessary permissions."
        print_message "Exiting..." "$RED"
        exit 1
    fi

    echo -e "\n---------------------------------------------------------------\n"

    print_message "Checking prerequisites..." "$GREEN"
    # Check if the AWS CLI is installed
    check_aws_cli
    # Check AWS CLI configuration with valid credentials
    check_aws_cli_configuration
    # Check admin access
    check_admin_access
    #runner prerequisite check
    self_hosted_runner_prerequisites_check

    echo -e "\nChecking organizational unit [ OU Id ] input variable which will be used to create OU structure for the Sandbox provisioner"

    # Check if PARENT_OU_ID is blank or empty
    if [ -z "$PARENT_OU_ID" ]; then
        echo -e "\nPARENT_OU_ID is blank or empty. Considering the root of the org as parent to create the Sandbox OU structure"
        echo "If you want to use a specific parent, please modify the PARENT_OU_ID variable with the value and rerun the script"

        PARENT_OU_ID=$(aws organizations list-roots --output json | jq -r '.Roots[].Id')
        echo -e "\nUsing ${YELLOW}${PARENT_OU_ID} ${NC} as parent to deploy the OUs for sandbox provisioner."
        echo -e "$GREEN"
        read -rp "Do you want to continue? (y/n): " continue
        echo -e "$NC"

    else
        OU_EXISTS=$(aws organizations describe-organizational-unit --organizational-unit-id "$PARENT_OU_ID" 2>&1)
        if [[ $? -ne 0 ]]; then
            echo -e "\n${RED}Provided PARENT_OU_ID does not exist: $PARENT_OU_ID${NC}"
            echo "Please check and correct. Exiting..."
            exit 1
        fi
        echo "PARENT_OU_ID provided is $PARENT_OU_ID. All the OUs for sandbox provisioner will be created under this OU"

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

        # Check if there are multiple instances and print them on the screen
        NUM_INSTANCES=$(aws sso-admin list-instances | jq '.Instances | length')
        if [ "$NUM_INSTANCES" -gt 1 ]; then
          echo "More than one instance ARNs and Identity Store IDs available:"
          aws sso-admin list-instances | jq -r '.Instances[] | "Instance ARN: \(.InstanceArn)\nIdentity Store ID: \(.IdentityStoreId)\n"'
          echo ""
        fi

        # Display the instance ARN and Identity Store ID
        echo -e "SSO instance ARN: ${RED}$SSO_INSTANCE_ARN ${NC}"
        echo -e "Identity Store ID: ${RED}$SSO_IDENTITY_STORE_ID ${GREEN}\n"
        read -rp "Confirm the above SSO Instance Details. Do you want to continue? (y/n): " continue
        echo -e "${NC}"
        if [[ "$continue" =~ ^[Yy]$ ]]; then
            echo -e "Creating permission set named ${YELLOW}$PERMISSION_SET_NAME${NC} for sandbox users with policy ${YELLOW}$MANAGED_POLICY_ARN_FOR_SANDBOX_USERS${NC} which will be used while provisioning sandbox account"
            SANDBOX_USER_PERMISSION_SER_ARN=$(aws sso-admin create-permission-set \
              --instance-arn $SSO_INSTANCE_ARN \
              --name "$PERMISSION_SET_NAME" \
              --description "Permission set with AdministratorAccess policy for Sandbox users" \
              --session-duration "PT1H30M" --query 'PermissionSet.PermissionSetArn' --output text
              )

            sleep 1

            aws sso-admin attach-managed-policy-to-permission-set \
              --instance-arn $SSO_INSTANCE_ARN \
              --permission-set-arn "$SANDBOX_USER_PERMISSION_SER_ARN" \
              --managed-policy-arn "$MANAGED_POLICY_ARN_FOR_SANDBOX_USERS"

            sleep 1

            echo -e "Sandbox user Permission set ARN : ${YELLOW}$SANDBOX_USER_PERMISSION_SER_ARN${NC}"

        else
            print_message "Exiting..." "$RED"
            exit 0
        fi

        echo -e "\nUpdating SSO details in workflow files"
        # Replace the instance ARN and Identity Store ID in the aws-provision.yml GitHub workflow file
        if [ -f "../../.github/workflows/aws-provision.yml" ]; then
          find ../../.github/workflows -type f -iname "*.yml" -exec bash -c "m4 -D REPLACE_SSO_ENABLED_FLAG_HERE=${SSO_ENABLED} -D INSTANCE_ARN_PLACEHOLDER=$SSO_INSTANCE_ARN -D IDENTITY_STORE_ID_PLACEHOLDER=$SSO_IDENTITY_STORE_ID -D REPLACE_SANDBOX_USER_PERMISSION_SET_ARN_HERE=$SANDBOX_USER_PERMISSION_SER_ARN {} > {}.m4  && cat {}.m4 > {} && rm {}.m4" \;
          echo "Updated aws-provision.yml with the instance ARN and Identity Store ID."
        else
          echo "Warning: aws-provision.yml not found. Please make sure the file is present or clone the repo properly."
        fi
      else
        echo -e "${RED}No SSO instance found. Make sure you are in correct account or disable the flag ${GREEN}'SSO_ENABLED'${NC} or create and Identity store in the management account"
      fi
    else
      echo -e "${YELLOW}\nSSO is not enabled. Skipping SSO-related commands${NC}"
      echo "Updating SSO flag in workflows"
      find ../../.github/workflows -type f -iname "*.yml" -exec bash -c "m4 -D REPLACE_SSO_ENABLED_FLAG_HERE=${SSO_ENABLED} {} > {}.m4  && cat {}.m4 > {} && rm {}.m4" \;
    fi

    echo -e "${RED}----------------------------------------------------${NC}"
    echo -e "  Creating OU structure for Sandbox Provisioner"
    echo -e "${RED}----------------------------------------------------${NC}"
    # Create the required OUs for the sandbox provisioner using the teams
    create_sandbox_ous

    echo -e "\nUpdating team names and OU Ids in workflows"
    TEAM_OU_MAPPING_OUTPUT="../provision/team_ou_select.sh"

    # Generate the case statements for team and ou mapping dynamically based on the arrays
    for ((i = 0; i < ${#TEAM_NAMES[@]}; i++)); do
        team_name="${TEAM_NAMES[i]}"
        sandbox_ou_id="${TEAM_SANDBOX_OUs[i]}"
        pool_ou_id="${TEAM_POOL_OUs[i]}"

        cat <<EOL >> "$TEAM_OU_MAPPING_OUTPUT"
            $team_name)
                echo "SANDBOX_OU_ID=$sandbox_ou_id" >> \$GITHUB_OUTPUT
                echo "POOL_OU_ID=$pool_ou_id" >> \$GITHUB_OUTPUT
                ;;
EOL
    done
    # Append the esac to close the case statement
    echo "esac" >> "$TEAM_OU_MAPPING_OUTPUT"

    TEAM_OPTIONS=""$'\n'
    for team_name in "${TEAM_NAMES[@]}"; do
        TEAM_OPTIONS+="          - $team_name"$'\n'
    done

    echo -e "${RED}----------------------------------------------------${NC}"
    echo -e "          Substituting variables in files"
    echo -e "${RED}----------------------------------------------------${NC}"

    find . -type f -iname "*.json" -exec bash -c "m4 -D REPLACE_AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} -D REPLACE_AWS_MANAGEMENT_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text) -D REPLACE_SECRET_NAME_HERE=${SECRET_NAME} {} > {}.m4  && cat {}.m4 > {} && rm {}.m4" \;
    echo "json files updated"
    sleep 2
    find ../provision -type f -iname "*.py" -exec bash -c "m4 -D REPLACE_REPO_OWNER_HERE=${REPO_OWNER} -D REPLACE_REPO_NAME_HERE=${REPO_NAME} -D REPLACE_SECRET_KEY_NAME_HERE=${SECRET_KEY_NAME} -D REPLACE_AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} -D REPLACE_AWS_MANAGEMENT_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text) -D REPLACE_SECRET_NAME_HERE=${SECRET_NAME} {} > {}.m4  && cat {}.m4 > {} && rm {}.m4" \;
    echo "python file updated"
    sleep 2
    find . -type f -iname "*.txt" -exec bash -c "m4 -D REPLACE_REPO_OWNER_HERE=${REPO_OWNER} -D REPLACE_REPO_NAME_HERE=${REPO_NAME} {} > {}.m4  && cat {}.m4 > {} && rm {}.m4" \;
    echo "txt file updated"
    sleep 2
    find ../provision -type f -iname "*.sh" -exec bash -c "m4 -D REPLACE_LAMBDA_ROLE_HERE=${lambda_role_name} -D REPLACE_MANAGED_POLICY_ARN_FOR_SANDBOX_USERS=${MANAGED_POLICY_ARN_FOR_SANDBOX_USERS} {} > {}.m4  && cat {}.m4 > {} && rm {}.m4" \;
    echo "script file updated"
    sleep 2
    find ../../.github/workflows -type f -iname "*.yml" -exec bash -c "m4 -D REPLACE_ENABLE_SLACK_NOTIFICATION_PLACEHOLDER=${ENABLE_SLACK_NOTIFICATION} -D REPLACE_HELPDESK_URL_PLACEHOLDER=${FRESHDESK_URL} -D REPLACE_ENABLE_HELPDESK_NOTIFICATION_PLACEHOLDER=${ENABLE_HELPDESK_NOTIFICATION} -D REPLACE_SELF_HOSTED_RUNNER_LABEL_PLACEHOLDER=${SELF_HOSTED_RUNNER_LABEL} -D REPLACE_REQUIRES_APPROVAl_PLACEHOLDER=$REQUIRES_MANAGER_APPROVAL -D REPLACE_APPROVAL_HOURS_PLACEHOLDER=$APPROVAL_DURATION -D REPLACE_TEAM_OU_MAPPING_OUTPUT=$TEAM_OU_MAPPING_OUTPUT -D REPLACE_WORKFLOW_TEAM_INPUT_OPTIONS=\"${TEAM_OPTIONS}\" -D REPLACE_MANAGEMENT_ROLE_HERE=${SANDBOX_MANAGEMENT_ROLE_NAME} -D REPLACE_AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} -D REPLACE_AWS_MANAGEMENT_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text) -D REPLACE_AWS_ADMIN_EMAIL=${AWS_ADMINS_EMAIL} {} > {}.m4  && cat {}.m4 > {} && rm {}.m4" \;
    echo "github workflows updated"
    sleep 2

    echo -e "\n${GREEN}Substitution Complete.${NC}"
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
    if ! check_existing_role "$SANDBOX_MANAGEMENT_ROLE_NAME" "$policy_name"; then
        create_management_role
    fi

    # Check if the lambda policy already exists and prompt for reuse
    if check_existing_policy "$LAMBDA_POLICY_NAME"; then
        print_message "Using existing policy: '$LAMBDA_POLICY_NAME'" "$GREEN"
    else
        # Create the lambda policy in the AWS Management Account
        create_aws_policy "$LAMBDA_POLICY_NAME" "$lambda_policy_file"
    fi

    # Check if the role already exists and prompt for reuse
    if ! check_existing_role "$lambda_role_name" "$LAMBDA_POLICY_NAME"; then
        create_lambda_role
    fi

    # Create the secret in AWS Secrets Manager
    create_aws_secret "$SECRET_NAME" "$SECRET_KEY_NAME" "$github_token"
    export MANAGEMENT_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
    export GITHUB_RUNNER_REGISTRATION_TOKEN=$(curl -s -X POST \
      -H "Authorization: token $github_token" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runners/registration-token" | jq -r '.token')

    # Create Self Hosted Github runner
    bash self-hosted-github-runner.sh

    print_message "Done" "$GREEN"
    exit 0
}

main
