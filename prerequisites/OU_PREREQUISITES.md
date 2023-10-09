# Prerequisites for AWS Sandbox Provisioner OU Structure

## Overview

This document outlines the required Organizational Unit (OU) structure for the AWS Sandbox Provisioner. The structure is designed for managing AWS accounts effectively, focusing on the needs of a single team within the organization: `DEV_TEAM`.

## OU Structure

For each team (e.g., `DEV_TEAM`), two OUs need to be created under the organization's hierarchy. The naming convention for these OUs should be as follows:

1. `dev_team_sandbox_ou`: This OU is intended for active sandbox accounts when they are assigned to users.

2. `dev_team_sandbox_pool_ou`: This OU is used to park AWS accounts when they are not assigned to any user and after cleaning up all associated resources.

## Example Team and OU Definitions

To illustrate, here's an example of how you can define teams and their corresponding OUs in the `prerequisites.sh` script:

```bash

# For example you have create dev-team OUs like below,
# team is dev-team
# OU1      > dev-team-sandbox-ou is "ou-6pbt-49d0vb50"
# OU1-pool > dev-team-sandbox-pool-ou is "ou-6pbt-xh364wnr"

# Now you can define the array for dev-team as below

# Define the team names
TEAM_NAMES=("dev-team" "qa-team" "devops-team")

# Define the corresponding sandbox OUs
TEAM_SANDBOX_OUs=("ou-6pbt-49d0vb50" "ou-6pbt-8yp0lf3e" "ou-6pbt-lkqhzc8a")

# Define the corresponding sandbox pool OUs
TEAM_POOL_OUs=("ou-6pbt-xh364wnr" "ou-6pbt-4dguhonx" "ou-6pbt-pnwre24b")


## Workflow Integration

All operations related to these OUs, including their creation and management, will be seamlessly integrated into the workflow. The primary purpose of these OUs is to provide a structured framework for organizing and managing AWS sandbox accounts effectively.

By having these OUs in place and properly configuring them as part of the prerequisites, you can ensure a smooth and organized AWS Sandbox Provisioner setup within your organization.
