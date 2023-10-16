# Automated AWS Sandbox Provisioner Setup

Welcome to the Automated AWS Sandbox Provisioner! To ensure a seamless and hassle-free setup, please follow our comprehensive documentation.

This documentation provides step-by-step instructions, configuration details, and best practices to help you get started quickly. Whether you're new to the system or an experienced user, our guide will assist you in provisioning AWS sandbox provisioner setup  effortlessly.

If you encounter any issues or have questions along the way, check [FAQs's](FAQ.md)


Let's get started on your automated sandbox provisioner setup journey! 🚀

## Getting Started

### Prerequisites

Before you begin, make sure you have the following prerequisites:

- [AWS CLI](https://aws.amazon.com/cli/) installed and configured with the necessary permissions.
- [GitHub Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) with scopes `repo` and `workflow`. [ Used to trigger automated cleanup of AWS sandbox account]
- (Optional) Freshdesk API key if you plan to use Freshdesk for ticket creation and notifications.
- (Optional) Slack webhook URL if you plan to enable Slack notifications.
- `AdministratorAccess` to the AWS Management Account in your AWS organization to setup the provisioner. [ Can take help of your aws admins team to setup the prerequisites ]

## Creating a New Repository from the template repository

To create a new project based on this template, follow these steps:

1. Click the "Use this template" button at the top of this repository.
2. Enter a name for your new repository.
3. Choose the visibility (public or private) for your new repository.
4. Click the "Create repository from template" button.

## Cloning the Repository and getting started
After you have created your new repository from the template, you can clone it to your local machine using Git. Run the following command in your terminal:

1. Clone the repository:
   ```bash
   git clone https://github.com/repo_owner/repo_name.git
   ```

2. Navigate to the [prerequisites](/prerequisites) directory:
   ```bash
   cd repo_name/prerequisites
   ```
3. Open the setup script `setup.sh`
- Verify then variables set.
- Fill in the required input variables like
```bash
export AWS_DEFAULT_REGION=""                            # e.g "us-east-1" Identity Center default region used by management account
export AWS_ADMINS_EMAIL=""                              # e.g "aws-admins@yourdomain.com" AWS admins DL required during sandbox account setup
export SSO_ENABLED=""                                   # set to "true" if your organization has SSO enabled and uses AWS IAM Identity center or set to false
export TEAM_NAMES=("")                                  # e.g ("dev-team" "qa-team" "devops-team") [ Please use the same syntax as example ]
export REQUIRES_MANAGER_APPROVAL="true"                 # set to true if approval is required for sandbox account of duration more than APPROVAL_DURATION hours duration
export APPROVAL_DURATION=8                              # Duration of hours of sandbox account request post which workflow requires manager's approval automatically.
export SELF_HOSTED_RUNNER_LABEL="aws-sandbox-gh-runner" # Use default label "aws-sandbox-gh-runner" to create and register a runner for the sandbox provisioner workflow. or else use already created runner by changing the label value.
export PARENT_OU_ID=""                                  # Keep blank to create the OUs under root in the organization by default.
export FRESHDESK_URL=""                                 # Leave blank if not applicable. In this case freshdesk APIs are used for ticket creation and updates. Provide freshdesk api url like 'https://your_freshdesk_domain.freshdesk.com'
export ENABLE_SLACK_NOTIFICATION=""                     # Set to true to enable slack notification in the workflows. Defaults to false
```
- Check the other variables defined, leave them as default wherever possible.
4. Run the script:
   ```bash
   bash setup.sh
   ```
5. Follow the prompts and act accordingly to finish the setup seamlesly 🚀

##
# That's it, you have done it !!