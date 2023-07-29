# AWS IAM Policy and Role Provisioning Script (prerequisite.sh)

This script is designed to automate the creation of AWS IAM policies and roles in the AWS Management Account. It is particularly useful for setting up necessary permissions for managing AWS accounts programmatically.

## Prerequisites

Before executing the script, please ensure you have the following:

1. **AWS CLI Installed**: The AWS Command Line Interface (CLI) should be installed on your system. If not installed, please refer to the official AWS documentation for installation instructions.

2. **AWS CLI Configuration**: Ensure that the AWS CLI is configured with valid credentials. If you haven't already done this, run `aws configure` and follow the prompts to set up your access key, secret key, and default region.

3. **JSON Policy Files**: Prepare two JSON policy files containing the policies you want to create. Ensure these files are correctly formatted and contain valid IAM policy documents.

## How to Execute the Script

1. Clone or download the script to your local machine.

2. Open a terminal or command prompt and navigate to the directory containing the script.

3. Make sure the script file has executable permissions. If not, give it the necessary permissions using the following command:

```bash
chmod +x prerequisite.sh
```
4. Update the script with the correct policy and role names, as well as the file paths to your JSON policy files. Look for the variables near the beginning of the script and modify them accordingly:

```bash
policy_name="sandbox_provisioner_policy"
policy_file="sandbox_provisioner_policy.json"
role_name="sandbox-account-management-role"
lambda_policy_name="sandbox_lambda_policy"
lambda_policy_file="sandbox_lambda_policy.json"
lambda_role_name="account_management_lambda_role"
```
5. Run the script by executing the following command:
```bash
./prerequisite.sh
```
## What to Expect After Script Execution

1. The script will check if the AWS CLI is installed and properly configured with valid credentials. If not, it will prompt you to install and configure the AWS CLI before proceeding.

2. It will validate the existence and readability of the JSON policy files specified in the script. If any of the files are missing or invalid, the script will display an error and terminate.

3. The script will then check if the specified policies and roles already exist in the AWS Management Account. If they do, it will prompt you whether to reuse the existing resources or create new ones.

4. If the policies and roles do not exist, the script will create them for you. If the policies already exist, it will skip the creation step.

5. If the roles do not exist, the script will create them and attach the corresponding policies.

6. After successfully creating or reusing the policies and roles, the script will display a "Done" message, indicating that the provisioning process is complete.

Please make sure to carefully review any prompts during script execution, as the script will not proceed until you confirm your choices.

**Note:** The script assumes that the AWS CLI is set up to interact with the AWS Management Account, where IAM policies and roles are created. Ensure that you have the necessary permissions to create and manage IAM resources in the AWS Management Account.

**Caution:** This script has the potential to create or modify AWS IAM resources. Please use it with caution and ensure you understand the implications of the changes it makes to your AWS environment. Always test in a controlled environment before using it in production.

For any questions or issues related to the script, please contact the script's maintainer or seek assistance from AWS support.

