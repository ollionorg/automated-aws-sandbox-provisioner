# Provision

This folder consists of the files used for provisioning the sandbox account by the github workflows.

For detailed diagram on the workflow visit [AWS Sandbox Provisioner Usage and workflow details](../USAGE.md)

## Script brielfs

### 1. `aws_provision_script.sh`
This Bash script automates the process of creating temporary AWS sandbox accounts and associated configurations. It accomplishes this in a structured series of steps:

**1. Get Reusable Account Function**: A function named `get_reusable_account` is implemented to fetch an existing active AWS account from a specified Organizational Unit (OU). The chosen account's ID is returned.

**2. Account Active Function**: This function checks the status of an account creation request. It queries AWS Organizations to verify if the request has succeeded.

**3. Create Account Function**: The `create_account` function generates a unique AWS account name based on the team and a random suffix. It initiates an account creation request and monitors the status until it succeeds. The new account is moved to a specified Organizational Unit (OU).

**4. Starting the Job**: The script begins by displaying a banner to indicate the start of the job.

**5. Check Prerequisites**: It checks the existence of a specified IAM role (REPLACE_LAMBDA_ROLE_HERE). If the role is not found, it displays an error message and exits. If the role exists, its ARN is retrieved for later use.

**6. Get Reusable Account**: The script attempts to get a reusable AWS account. If one is available, it is moved from an account pool OU to a sandbox OU. If not, a new account is created.

**7. SSO Assignment**: If Single Sign-On (SSO) is enabled, the script assigns SSO permissions to the user who requested the sandbox account. Additional users can also be assigned SSO permissions if specified.

**8. Configuration for IAM Users**: If SSO is not enabled, the script configures credentials for the sandbox account. It assumes an IAM role and creates IAM users for the requesting user and any additional users.

**9. Creating a Lambda Function**: The script creates a Lambda function and a scheduled event to revoke access to the sandbox account after a specified duration. The Lambda function code is updated with account-specific information.

The above script is triggered from GitHub actions with required variables set.

### 2. `create_iam_user.sh`

- Creates an IAM user with the provided `username`.
- Generates an initial password for the user.
- Creates a login profile for the user with the initial password and sets it as "password-reset-required."
- Attaches the `SANDBOX_USER_ACCESS_POLICY` to the IAM user, granting them specific access permissions.
- Outputs user information, including the IAM username, email, initial password, and the attached policy.
- Appends user information to a summary file specified by the `GITHUB_STEP_SUMMARY` environment variable.

The above script is triggered from the `aws_provision_script.sh` actions with required variables set.

### 3. `lambda.py`

This script will be deployed as lambda function for each provisioned account by replacing the variables. It is used to trigger the cleanup workflow.


### 4. `team_ou_select.sh`

This script is triggered by the `aws-provision.yml` workflow, to get the team OU Ids in AWS based on the team name.
