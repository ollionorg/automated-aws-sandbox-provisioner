# Self-Hosted Runner Setup Script

## Purpose

This Bash script simplifies the setup of a self-hosted GitHub runner on an Amazon EC2 instance. The runner allows you to execute GitHub Actions workflows within your own infrastructure. Below are the key steps and pointers to understand how this script works:

## Instructions

To use this script:

1. Ensure you have the AWS CLI installed and configured with the necessary credentials.
2. Modify the script's variables and parameters at the beginning according to your requirements. Key variables to customize include:
    - `AWS_DEFAULT_REGION`: AWS region where the EC2 instance will be created.
    - `SELF_HOSTED_RUNNER_VPC_CIDR`: CIDR block for the VPC.
    - `SELF_HOSTED_RUNNER_SUBNET_CIDR`: CIDR block for the subnet.
    - `REPO_OWNER` and `REPO_NAME`: GitHub repository owner and name where the runner will be registered.
    - `GITHUB_RUNNER_REGISTRATION_TOKEN`: GitHub registration token for the runner.
    - `INSTANCE_TYPE`: EC2 instance type (e.g., `t2.micro`).
    - `SSH_USER`: SSH user for connecting to the EC2 instance.
    - `KEY_NAME`: Name of the EC2 key pair for SSH access.

3. Run the script using Bash. It will create an EC2 instance, set up the runner, and register it with the specified GitHub repository.

4. The script automatically adds an SSH inbound rule to the security group to allow your current IP address to connect for SSH during setup. It revokes this rule once setup is complete.

## Important Note

- Ensure you have the necessary AWS permissions and have configured your environment correctly to use the AWS CLI.
