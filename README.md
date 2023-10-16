

<img src="./screenshots/OLLION_BANNER.png" alt="OLLION">

# Automated AWS Sandbox Account Provisioner with GitHub Actions

This document provides a comprehensive overview of our solution for creating temporary, time-based, sandbox accounts for individuals and teams. We have designed this provisioner to address a range of challenges related to cost management, security, and ease of account management within organizations.

## Table of Contents
1. [Introduction](#introduction)
2. [Key Benefits](#key-benefits)
3. [Use Cases](#use-cases)
4. [Features](#features)
5. [Documentation](#documentation)
6. [Getting Started](#getting-started)
7. [FAQ](#faq)
8. [Support](#support)
9. [Contributing](#contributing)
10. [License](#license)

## Introduction

The Temporary AWS Sandbox Account Provisioner is a solution designed to automate the creation and management of temporary sandbox accounts for users or teams within your organization. These sandbox accounts are time-limited and serve as dedicated environments for various purposes such as proof of concept (POC), testing, experimentation, interviews and more.

## Key Benefits

Our provisioner offers several key benefits for organizations:

### Account Management
- **Automation**: The solution is completely automated, simplifying the process of account creation, assignment, and cleanup.
- **Reusability**: It allows for the reuse of sandbox accounts from a pool, reducing administrative overhead.
- **OU SCPs**: By adding SCPs the admins can control the usuage and impose restrictions on the SandBox OU level as per organizational requirenments, thus having greater control over accounts.

### Cost Management
- **Cost Control**: The provisioner helps control costs by automatically cleaning up sandbox accounts after a specified duration selected during provisioning. This prevents the unnecessary accumulation of resources and associated costs.
- **Budget Alerts**: The provisioner automatically configures monthly budget for accounts under sandbox, which inturn helps control costs of unnoticed resources by alerting on thresholds. [TO BE DONE]

### Security
- **Reduced Attack Surface**: By isolating sandbox accounts, it reduces the attack surface, limiting the potential impact of security breaches or vulnerabilities.


## Use Cases

The Temporary Sandbox Account Provisioner is a versatile tool that can address a variety of use cases within your organization:

- **Proof of Concept (POC)**: Provide dedicated environments for POCs without impacting production resources or other shares account resources.
- **Testing and Quality Assurance**: Enable testing and QA teams to work in isolated environments.
- **Training and Learning**: Create temporary accounts for training purposes.
- **Development and Experimentation**: Facilitate experimentation and development in isolated sandboxes.
- **Interviews**: Provide dedicated environments for interviews.

## Features

Our sandbox provisioner offers a range of features to meet your organization's needs:

- **Automated Account Creation**: Easily create sandbox accounts with predefined configurations and manage with the organization.
- **Time-Based Expiry**: Sets a duration for sandbox accounts, ensuring automatic cleanup.
- **Pool of Reusable Accounts**: Maintain a pool of sandbox accounts for efficient resource allocation.
- **Security Isolation**: Isolate sandbox accounts from production resources to enhance security.
- **Logging**: Keep track of account provisioning and cleanup activities for auditing.
- **Approval Workflow**: Implement approval workflows for sandbox accounts that require manager approval beyond specific duration.
- **Integration with SSO**: Seamlessly integrate with AWS Single Sign-On (SSO) for user access management (optional).
- **Helpdesk Integration**: Integrate with Freshdesk for helpdesk ticket notifications (optional).
- **Slack Notifications**: Get Slack notifications for workflow events (optional).



## Documentation

Our documentation is organized into the following sections:

- [Installation / Getting Started Guide](GETTING_STARTED.md): Instructions for installing and configuring the provisioner.
- [Usage](USAGE.md): Detailed usage guidelines and examples.
- [Technical Implementation](IMPLEMENTATION.md): Technical implementation details about the provisioner tool.

## Repo Structure

```bash
.
├── prerequisites
│   ├── OU_PREREQUISITES.md
│   ├── README.md
│   ├── SELF_HOSTED_RUNNER_SETUP.md
│   ├── assume-role-policy-document.json
│   ├── git_commit_push.sh
│   ├── output.txt.bkp
│   ├── sandbox_lambda_policy.json
│   ├── sandbox_provisioner_policy.json
│   ├── self-hosted-github-runner.sh
│   └── setup.sh
├── provision
│   ├── README.md
│   ├── aws_provision_script.sh
│   ├── create_iam_user.sh
│   ├── lambda.py
├── cleanup
│   ├── README.md
│   ├── README.png
│   ├── nuke-config.yaml
│   └── remove_user_access.sh
├── CHANGELOG.md
├── CODEOWNERS
├── CONTRIBUTING.md
├── FAQ.md
├── GETTING_STARTED.md
├── IMPLEMENTATION.md
├── LICENSE
├── README.md
├── SUPPORT.md
├── USAGE.md
└── screenshots

```
## Getting Started

To get started with the AWS Sandbox Account Provisioner, please refer to our [Getting Started Guide](GETTING_STARTED.md). This guide will walk you through the setup and configuration process, helping you quickly deploy the solution within your organization.

## FAQ

Have questions? Check out our [FAQ section](FAQ.md) for answers to common queries and concerns.

## Support

For technical support or assistance, please raise an issue with detailed query, also do check the [FAQs](FAQ.md) if it helps.

## Contributing

We welcome contributions from the community! If you have suggestions, bug reports, or would like to contribute code, please review our [Contributing Guidelines](CONTRIBUTING.md).

## License

This project is licensed under the [Apache License 2.0](LICENSE). Feel free to use, modify, and distribute it as needed within your organization.

Thank you for choosing the Automated AWS Sandbox Account Provisioner. We hope this solution helps streamline your organization's workflows and enhances your resource management capabilities.

