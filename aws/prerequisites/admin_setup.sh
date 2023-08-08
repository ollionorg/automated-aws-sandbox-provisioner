#!/bin/bash

: '
 THis script needs to be run while authenticated to management aws account
 It creates policy and role that will be used by the lambda to execute tasks
 It also packages and creates a lambda layers which is used by the lambda function.

 One can do the following tasks manually instead of running the script
 Create a policy and role with permissions defined in lambda_policy.json and assume-role-policy-document.json

'

if [ -f "lambda_policy.json" ]; then
  echo "Creating policy account_management_lambda_policy"
  Policy_Arn=$(aws iam create-policy --policy-name account_management_lambda_policy --policy-document file://lambda_policy.json --query 'Policy.Arn' --output text)
  echo "$Policy_Arn"
else
  echo "Policy file does not exist"
  exit
fi

if [ -f "assume-role-policy-document.json" ]; then
  echo "Creating Role"
  Role_Arn=$(aws iam create-role --role-name account_management_lambda_role --assume-role-policy-document file://assume-role-policy-document.json --query 'Role.Arn' --output text)
  echo "$Role_Arn"
else
  echo "Policy file does not exist"
  exit
fi

aws iam attach-role-policy --role-name account_management_lambda_policy --policy-arn "$Policy_Arn"


if [ -f "org_cross_account_access_role.json" ]; then
  echo "Creating policy GrantAccessToOrganizationAccountAccessRole"
  Policy_Arn=$(aws iam create-policy --policy-name GrantAccessToOrganizationAccountAccessRole --policy-document file://org_cross_account_access_role.json --query 'Policy.Arn' --output text)
  echo "$Policy_Arn"
else
  echo "Policy file does not exist"
  exit
fi

#TODO: The above GrantAccessToOrganizationAccountAccessRole policy is to be attached to the entity with which we are to run all the commands in the main script.
#TODO: This is used to assume role to temp sandbox accounts
#TODO: Refer https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_access.html#orgs_manage_accounts_access-cross-account-role


echo -e "\n\n\nMake sure to add the git_token in AWS Secret Manager. Follow below naming conventions \n"
echo "Secret name:      management/git"
echo "Secret key:       git_token"
echo -e "Secret value:     <add_git_token_there>\n\n"


echo "Done"
