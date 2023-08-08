# AWS Sandbox Provisioner Workflow Prerequisite Setup

## Overview

This script helps to setup the pre-requisites required for the Sandbox Provisioner workflow to execute properly

## Prerequisites

Before using this workflow, make sure you have the following prerequisites:

1. An AWS Management account of the organization with the necessary permissions to create IAM policies, roles, and manage Secrets Manager.
2. AWS CLI installed and configured with valid credentials.
3. A valid GitHub token (GITHUB_TOKEN) which will be stored in AWS Secrets Manager and used to trigger the cleanup workflow in github using `repository_dispatch` event

## Quick Start Guide 🚀

1. Clone this repository to your local machine.

2. **Update Configuration:**

   Before running the workflow, you may need to adjust some configuration values in the `prerequisite.sh` script. Open the script and modify the configuration section according to your specific requirements. **[Can keep it as it is]**
   ```bash
    # Configuration variables
    export policy_name="SandboxProvisionerPolicy"
    export policy_file="sandbox_provisioner_policy.json"
    export role_name="SandboxAccountManagementRole"
    export lambda_policy_name="SandboxLambdaPolicy"
    export lambda_policy_file="sandbox_lambda_policy.json"
    export lambda_role_name="SandboxLambdaRole"
    export SECRET_NAME="sandbox/git"
    export SECRET_KEY_NAME="git_token"
    export AWS_DEFAULT_REGION="us-east-1"
   ```

4. **Run the Script:**
   Once any modifications above are completed. run the script and floow the prompts
```bash
bash prerequisite.sh
```

5. **Verify Script execution and Resources created in management account:**

   The script will create below resources if the default variable names were used
    * Modify the policy files under `aws/prerequisites` and update variables
    * Policies named `SandboxProvisionerPolicy` and `SandboxAccountManagementRole`
    * Roles named `SandboxAccountManagementRole` and `SandboxLambdaRole`
    * Create a secret in AWS secret manager and store `GITHUB_TOKEN`
    * Modify the `lambda.py` file present under `aws/provision` and update variables
    * Modify the workflows under `.github/workflows` and update variables

## Important Notes

1. The IAM policies (`sandbox_provisioner_policy.json` and `sandbox_lambda_policy.json`) define the permissions granted to the sandbox provisioner workflow and lambda function respectively. Review the policies to ensure they align with your security requirements.

2. Always exercise caution when running workflows that interact with your AWS resources. Make sure to review and understand the actions performed by the workflow

