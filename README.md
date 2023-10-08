# Temporary Sandbox Account Provisioner

Welcome to the Temporary Sandbox Account Provisioner documentation! This document provides a comprehensive overview of our solution for creating temporary, time-based sandbox accounts for individuals and teams. We have designed this provisioner to address a range of challenges related to cost management, security, and ease of account management within organizations.

## Table of Contents
1. [Introduction](#introduction)
2. [Key Benefits](#key-benefits)
3. [Use Cases](#use-cases)
4. [Features](#features)
5. [Getting Started](#getting-started)
6. [Documentation](#documentation)
7. [FAQ](#faq)
8. [Support](#support)
9. [Contributing](#contributing)
10. [License](#license)

## Introduction

The Temporary Sandbox Account Provisioner is a solution designed to automate the creation and management of temporary sandbox accounts for users or teams within your organization. These sandbox accounts are time-limited and serve as dedicated environments for various purposes such as proof of concept (POC), testing, experimentation, and more.

## Key Benefits

Our provisioner offers several key benefits for organizations:

### Cost Management
- **Cost Control**: The provisioner helps control costs by automatically cleaning up sandbox accounts after a specified duration. This prevents the unnecessary accumulation of resources and associated costs.

### Security
- **Reduced Attack Surface**: By isolating sandbox accounts, it reduces the attack surface, limiting the potential impact of security breaches or vulnerabilities.

### Management
- **Automation**: The solution is completely automated, simplifying the process of account creation, assignment, and cleanup.
- **Reusability**: It allows for the reuse of sandbox accounts from a pool, reducing administrative overhead.

## Use Cases

The Temporary Sandbox Account Provisioner is a versatile tool that can address a variety of use cases within your organization:

- **Proof of Concept (POC)**: Provide dedicated environments for POCs without impacting production resources.
- **Testing and Quality Assurance**: Enable testing and QA teams to work in isolated environments.
- **Training and Learning**: Create temporary accounts for training purposes.
- **Development and Experimentation**: Facilitate experimentation and development in isolated sandboxes.

## Features

Our provisioner offers a range of features to meet your organization's needs:

- **Automated Account Creation**: Easily create sandbox accounts with predefined configurations.
- **Time-Based Expiry**: Set a duration for sandbox accounts, ensuring automatic cleanup.
- **Pool of Reusable Accounts**: Maintain a pool of sandbox accounts for efficient resource allocation.
- **Security Isolation**: Isolate sandbox accounts from production resources to enhance security.
- **Detailed Logging**: Keep track of account provisioning and cleanup activities for auditing.

## Getting Started

To get started with the Temporary Sandbox Account Provisioner, please refer to our [Getting Started Guide](getting-started.md). This guide will walk you through the setup and configuration process, helping you quickly deploy the solution within your organization.

## Documentation

Our documentation is organized into the following sections:

- [Installation](installation.md): Instructions for installing and configuring the provisioner.
- [Usage](usage.md): Detailed usage guidelines and examples.
- [Configuration](configuration.md): Configure the provisioner to align with your organization's requirements.
- [Troubleshooting](troubleshooting.md): Common issues and solutions.
- [Advanced Features](advanced-features.md): Explore advanced capabilities and customization options.

## FAQ

Have questions? Check out our [FAQ section](faq.md) for answers to common queries and concerns.

## Support

For technical support or assistance, please contact our support team at support@example.com.

## Contributing

We welcome contributions from the community! If you have suggestions, bug reports, or would like to contribute code, please review our [Contributing Guidelines](contributing.md).

## License

This project is licensed under the [MIT License](LICENSE). Feel free to use, modify, and distribute it as needed within your organization.

Thank you for choosing the Temporary Sandbox Account Provisioner. We hope this solution helps streamline your organization's workflows and enhances your resource management capabilities.

################################

## Workflow

### Account Provisioning

The account provisioning workflow is as follows:

1. A user initiates the workflow by providing their email, team, access duration, and purpose.
2. If the access duration requires approval, a helpdesk ticket is created, and approval is requested.
3. Once approved, the tool provisions an AWS sandbox account for the user's team.
4. The user receives a notification with the necessary details to access the sandbox account.

### Account Cleanup (Nuke)

The account cleanup (nuke) workflow is as follows:

1. An event is triggered to initiate the cleanup process for a specific account.
2. The tool removes SSO access for all users from the account and cleans up all resources using `aws-nuke`.
3. The account is moved from the Sandbox Organizational Unit (OU) to a Suspended OU.

## Usage

To provision a sandbox account, follow these steps:

1. Open a new GitHub workflow dispatch event.
2. Provide the required input parameters: `EMAIL`, `TEAM`, `DURATION`, and `PURPOSE`.

To initiate an account cleanup (nuke), follow these steps:

1. Open a new GitHub repository dispatch event with the `aws_sandbox_nuke` type.
2. Provide the payload with `ACCOUNT_ID_TO_NUKE` representing the account to be cleaned up.

## Configuration

Configure the environment variables in your GitHub repository to customize the behavior of the provisioning and cleanup workflows. Details can be found in the respective workflow sections of this repository.

## License

This project is licensed under the [MIT License](LICENSE).

## Contact

For support and inquiries, please contact the CloudCover Helpdesk: [CloudCover Helpdesk](https://cloudcover-helpdesk.freshdesk.com).

---

Feel free to contribute to this project by submitting pull requests or opening issues.
