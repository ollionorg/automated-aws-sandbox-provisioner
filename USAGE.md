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
