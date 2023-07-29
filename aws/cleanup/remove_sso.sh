#!/bin/bash


export ADMINISTRATOR_ARN="arn:aws:sso:::permissionSet/ssoins-72230e0790e87c67/ps-0662f849c7f7a7eb"


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

