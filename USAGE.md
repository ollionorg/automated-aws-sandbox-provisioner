# AWS Sandbox Provisioner Usuage

This tool consists of two primary workflows
1. [Account Provisioning](#provisioning)
2. [Account Cleanup (Nuke)](#cleanup)


## Account Provisioning

The account provisioning can be used to provision sandbox accounts


1. Open Sandbox Provisioner GitHub repository.
2. Head over to Actions tab
   ![Screenshot](./screenshots/Actions_tab.png?text=Actions+tab+Screenshot+Here)

3. Select the AWS Sandbox Provisioner workflow
   ![Screenshot](./screenshots/Action_Select.png?text=Actions+tab+Screenshot+Here)

4. Click on Run workflow and fill in the required input parameters: `EMAIL`, `TEAM`, `DURATION`, `PURPOSE` and `Additional User Emails` [Optional]
   ![Screenshot](./screenshots/Options.png?text=Actions+tab+Screenshot+Here)

5. Click Run workflow
   ![Screenshot](./screenshots/Run_Workflow.png?text=Actions+tab+Screenshot+Here)

To know more, read : [HOW_DOES_PROVISIONING_WORK](#provisioning_steps) [TODO]


## Account Cleanup (Nuke)

The account cleanup (nuke) workflow is automated and does not require any action:

To know more, read : [HOW_DOES_NUKE_WORK](#nuke_steps) [TODO]




#
# Detailed Workflow Steps
## [Provisioning Steps](#provisioning_steps)
1. TODO
2.
3.

## [Nuke Steps](#nuke_steps)

1. An event is triggered to initiate the cleanup process for a specific account.
2. The tool removes SSO access for all users from the account and cleans up all resources using `aws-nuke`.
3. The account is moved from the Sandbox Organizational Unit (OU) to a Suspended OU.

##