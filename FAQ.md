# AWS Sandbox Provisioner FAQs

Below are some frequently asked questions to help you get started and understand the project better.

## Frequently Asked Questions (FAQ)

### 1. What is AWS Sandbox Provisioner?

AWS Sandbox Provisioner is a tool developed in order to automate the management and provisioning and cleanup of isolated aws accounts as sandbox for users for various purposes. The tool makes use of GitHub workflows and AWS APIs and integrations like slack, freshdesk, etc.
It can be used for hassel free provisioning of sandbox accounts

### 2. What permissions are given to the sandbox user ?

The sandbox user get the Administrator access to the account assigned to carry out the POC or any intended work without blockers.
This can be changed during setup by changing the policy here `prerequisites/setup.sh` by changing `export MANAGED_POLICY_ARN_FOR_SANDBOX_USERS="arn:aws:iam::aws:policy/AdministratorAccess"`
In case the change is required after the setup is done, update the policy in the workflow files at `.github/workflows`. Update both `*.yml` files.



### 3. How the private runners are working in this setup?
If you keep the default runner label, the setup script creates the runners and registers.
The runner is basically a EC2 instance deployed with all the security measures. No inbound port is opened.
Working of the runner :
- When a runner is registered to a repository, it keeps on listening for any new jobs.
- Whenever a sandbox provisioner workflow is run, it will look for a runner with the specified label. If found, the job is submitted and runs on that machine.


### 4. How can I check logs if something fails ?
The logs will be available in the `Actions` tab in the GitHub repository.
For AWS logs look for cloudwatch logs for events and lambda logs.



### 5. Can I update the timeline once I already run the workflow ?
Yes, one can get the sandbox account extended by simply changing the schedule of the eventbridge rule associated with that sandbox account in the management account.
Ideally only the aws admins should have access to the management account.

### 6. Is extension of the sandbox account possible ?
Refer Question 5

### 7. What should I do if nuke fails ?
Nuke/Cleanup workflow can be re-ran if it fails due to some issues which are not related to the provisioner. If if fails due to provisioner, check the GitHub Actions logs and resolve the issue accordingly. Still if something is blocking, Please raise an issue with the question.
