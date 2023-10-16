# AWS Sandbox Provisioner Resources

The following document gives a brief on what all resources are created as part of the initial setup of the sandbox provisioner.

## Diagram indicating resources

<img src="./screenshots/AWS Sandbox Provisioner Resources.png"  alt="Sandbox Provisioner Resources">


## Resources in Detail
The AWS Sandbox Provisioner creates the following resources:

1. IAM Policies:
- `SandboxProvisionerPolicy`: Policy attached to `SandboxAccountManagementRole`.
- `SandboxLambdaPolicy`: Policy attached to `SandboxLambdaRole`.
- If required review the policy files present under `prerequisites/` `*.json` files.

2. IAM Roles:

- `SandboxAccountManagementRole`: Role used for managing sandbox accounts.
- `SandboxLambdaRole`: Role used for Lambda functions.
3. Secret:

- GitHub token stored securely in AWS Secrets Manager.
4. Self-Hosted GitHub Runner:

- A self-hosted runner instance registered to your GitHub repository.
- Related AWS resources (VPC, Subnet, SecurityGroup, etc.).
- `GitHubRunnerInstanceProfile`: GitHub runner instance profile
- `GitHubRunnerRole`: Policy attached to instance profile, has ability to assume the `SandboxAccountManagementRole`
- SSH Key Pair.
- Temporary SSH inbound rule, which is removed after the runner setup.

5. Organizational Unit (OU) Structure:

- OUs are created for different teams (e.g., dev-team, qa-team, devops-team) within the AWS Organizations hierarchy.


## Cost
The AWS resources created by the AWS Sandbox Provisioner may incur costs. Find below the estimate cost of these resources using the [AWS Pricing Calculator](https://calculator.aws/#/estimate?id=28b16e7775d77456a9970079e50f3c5cedf8d607). Please review the estimated costs and ensure they align with your budget and requirements.

## Setup

To set up the AWS Sandbox Provisioner, follow the steps under [Getting Started Guide](GETTING_STARTED.md)

##
For any questions or issues related to the AWS Sandbox Provisioner, check the [FAQ](FAQ.md) and can raise issues in the GitHub issue section.
Let's get started with seamless and controlled AWS sandbox provisioning
! 🚀