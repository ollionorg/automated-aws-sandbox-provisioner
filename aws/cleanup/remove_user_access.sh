#!/bin/bash


if [[ $SSO_ENABLED = "true" ]]; then

    PRINCIPALS=$(aws sso-admin list-account-assignments \
      --instance-arn $SSO_INSTANCE_ARN \
      --account-id $ACCOUNT_ID_TO_NUKE \
      --region $AWS_REGION \
      --permission-set-arn $ADMINISTRATOR_ARN \
      --query 'AccountAssignments[*].PrincipalId' \
      --output text
      )

    for PRICIPAL in $PRINCIPALS
    do
      echo "-----------------------------------------------------------"
      echo "Revoke SSO for Principal ID: $PRICIPAL"
      #Deletes a principal's access from a specified AWS account using a specified permission set.
      aws sso-admin delete-account-assignment \
        --instance-arn "$SSO_INSTANCE_ARN" \
        --target-id "$ACCOUNT_ID_TO_NUKE" \
        --target-type AWS_ACCOUNT \
        --permission-set-arn $ADMINISTRATOR_ARN \
        --principal-type USER \
        --principal-id "$PRICIPAL"
    done

fi


# Get a list of all IAM user names
user_names=$(aws iam list-users --query 'Users[].UserName' --output text)

# Iterate through the list and delete each user
for user_name in $user_names; do
    echo "Deleting IAM user: $user_name"
    aws iam delete-user --user-name "$user_name"
done

echo "All IAM users have been deleted."
