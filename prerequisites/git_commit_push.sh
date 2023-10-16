#!/bin/bash

# Detect the current/main branch
current_branch=$(git symbolic-ref --short HEAD)
if [ $? -ne 0 ]; then
  echo "Failed to detect the current branch."
  exit 1
fi

# Define the new branch name
new_branch="sandbox-init"

files_to_push=(
    ../.github/workflows/aws-nuke.yml
    ../.github/workflows/aws-provision.yml
    sandbox_lambda_policy.json
    sandbox_provisioner_policy.json
    self-hosted-github-runner.sh
    setup.sh
    ../provision/create_iam_user.sh
    ../provision/lambda.py
    ../provision/team_ou_select.sh
)

# Step 1: Create and switch to a new branch
git checkout -b $new_branch

# Step 2: Add only the specified files to the new branch
for file in "${files_to_push[@]}"; do
    git add "$file"
done

# Step 3: Commit changes
git commit -m "Auto-commit changes from startup script"

# Step 4: Push changes to the new branch
git push origin $new_branch

echo "Changes pushed to $new_branch, Please get it merged in the main/default branch"
