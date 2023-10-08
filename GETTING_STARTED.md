# AWS Sandbox Provisioner

AWS Sandbox Provisioner is a tool for automating the provisioning and management of sandbox AWS accounts for development and testing purposes. It enables you to create isolated AWS environments for different teams within your organization while ensuring security and cost control.

![GitHub Workflow Status](https://img.shields.io/github/workflow/status/yourusername/aws-sandbox-provisioner/CI-CD?label=CI%2FCD&logo=github&style=flat-square)
![GitHub](https://img.shields.io/github/license/yourusername/aws-sandbox-provisioner?style=flat-square)

## Table of Contents
- [Features](#features)
- [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Sandbox Account Creation**: Automate the creation of AWS sandbox accounts for different teams or departments.
- **IAM Policy Management**: Easily manage IAM policies and roles for sandbox accounts.
- **Self-Hosted GitHub Runner**: Optionally create and register self-hosted GitHub runners for each sandbox environment.
- **Approval Workflow**: Implement approval workflows for sandbox accounts that require manager approval.
- **Integration with SSO**: Seamlessly integrate with AWS Single Sign-On (SSO) for user access management.
- **Helpdesk Integration**: Integrate with Freshdesk for helpdesk ticket notifications (optional).
- **Slack Notifications**: Get Slack notifications for workflow events (optional).

## Getting Started

### Prerequisites

Before you begin, make sure you have the following prerequisites:

- [AWS CLI](https://aws.amazon.com/cli/) installed and configured with the necessary permissions.
- [GitHub Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) with appropriate repository access.
- (Optional) Freshdesk API key if you plan to use Freshdesk for notifications.
- (Optional) Slack webhook URL if you plan to enable Slack notifications.

## Creating a New Repository from the template repo

To create a new project based on this template, follow these steps:

1. Click the "Use this template" button at the top of this repository.
2. Enter a name for your new repository.
3. Choose the visibility (public or private) for your new repository.
4. Click the "Create repository from template" button.

## Cloning the Repository and getting started
After you have created your new repository from the template, you can clone it to your local machine using Git. Run the following command in your terminal:

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/aws-sandbox-provisioner.git
   ```
   
2. Navigate to the project directory:
   ```bash
   cd aws/prerequisites
   ```
3. Provide the required variables for the setup
   ```bash
   bash prerequisites.sh
   ```
3. Run the script:
   ```bash
   bash prerequisites.sh
   ```
