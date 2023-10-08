#!/bin/bash

export SANDBOX_USER_ACCESS_POLICY="REPLACE_MANAGED_POLICY_ARN_FOR_SANDBOX_USERS" #prerequisite script will update it, do not change manually

# Function to create an IAM user
create_iam_user() {
    local username="$1"
    local email="$2"

    echo "---------------------------------------------------------"
    echo "Creating IAM user for  $email"
    echo "---------------------------------------------------------"

    # Create the IAM user and generate an initial password
    USER_ARN=$(aws iam create-user --user-name "$username" --query 'User.Arn' --output text)
    if [[ -z $USER_ARN ]]; then
        echo "IAM user for $email was not created. Please investigate"
    fi


    initial_password="$(openssl rand -base64 48 | head -c16)$"
    # Create login profile with initial password
    LOGIN_PROFILE_OUTPUT=$(aws iam create-login-profile --user-name "$username" --password "$initial_password" --password-reset-required --query 'LoginProfile.UserName' --output text)
    if [[ -z $LOGIN_PROFILE_OUTPUT ]]; then
        echo "Login profile for user $email was not created. Please investigate"
    fi

    # Attach AdministratorAccess policy to the IAM user
    aws iam attach-user-policy --user-name "$username" --policy-arn "$SANDBOX_USER_ACCESS_POLICY" --output json

    # Output user information
    echo "IAM User: $username"
    echo "Email: $email"
    echo "Initial Password: $initial_password"
    echo "User created and console access enabled with $SANDBOX_USER_ACCESS_POLICY."
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <email1> [<email2> ...]"
    exit 1
fi


for email in "$@"; do
    username=$(echo "$email" | tr '@' '-')
    create_iam_user "$username" "$email"
done