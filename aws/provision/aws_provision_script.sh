#!/bin/bash

### This script is intended to create temporary time based AWS sandbox accounts.


function banner() {
  echo "+------------------------------------------+"
  printf "| %-40s |\n" "`date`"
  echo "|                                          |"
  printf "| %-40s |\n" "$@"
  echo "+------------------------------------------+"
}

function get_reusable_account() {
    aws organizations list-accounts-for-parent --parent-id "${ACCOUNT_POOL_OU}" --query 'Accounts[?Status==`ACTIVE`].Id' --output text > accounts.txt
    ACCOUNT_ID=$(expand -t 1 accounts.txt | tr ' ' '\n' | shuf | tr '\n' ' ' | awk '{print $1}')
    echo $ACCOUNT_ID
}

#function to check the status of account creation
function account_active() {
  STATUS=$(aws organizations list-create-account-status --query 'CreateAccountStatuses[?Id==`'"${CREATE_REQUEST_ID}"'`].State' --output text)
  if [[ "${STATUS}" == "SUCCEEDED" ]]; then
    return 0
  else
    return 1
  fi
}

NEW_ACCOUNT_ID="NA"
function create_account() {
    #Account name format
    export SUFFIX=$((RANDOM % 900000 + 100000))
    export ACCOUNT_NAME=$(echo "${TEAM}_SANDBOX_${SUFFIX}" | awk '{print tolower($0)}')

    banner "Creating New Account"

    #Create account
    echo -e "\n\nCreating AWS sandbox account for ${USER_EMAIL} and the access will be revoked in ${DURATION} hours\n"

    CREATE_REQUEST_ID=$(
      aws organizations create-account \
        --email "${ADMIN_EMAIL}+${ACCOUNT_NAME}@cldcvr.com" \
        --account-name "${ACCOUNT_NAME}" \
        --region ${AWS_REGION} \
        --iam-user-access-to-billing ALLOW \
        --output text \
        --query 'CreateAccountStatus.Id'
    )

    echo -e "Account creation id = ${CREATE_REQUEST_ID} \nFind below the status \n"

    #wait while the account is being created
    while ! account_active; do
      echo "Waiting for the account creation status to be changed to SUCCEEDED"
      sleep 1
    done

    echo "AccountId    AccountName    State    FailureReason"
    aws organizations list-create-account-status \
      --output text \
      --query 'CreateAccountStatuses[?Id==`'"${CREATE_REQUEST_ID}"'`].[AccountId,AccountName,State,FailureReason]'

    NEW_ACCOUNT_ID=$(
      aws organizations list-create-account-status \
        --output text \
        --query 'CreateAccountStatuses[?Id==`'"${CREATE_REQUEST_ID}"'`].[AccountId]'
    )

    MASTER_ROOT_ID=$(aws organizations list-roots --query 'Roots[*].Id' --output text)

    echo "Moving $NEW_ACCOUNT_ID from Root $MASTER_ROOT_ID to Sandbox OU $SANDBOX_OU_ID"
    aws organizations move-account \
      --account-id $NEW_ACCOUNT_ID \
      --source-parent-id $MASTER_ROOT_ID \
      --destination-parent-id $SANDBOX_OU_ID
}

banner "Starting the Job"

#Get the required ARNs
if [ -z $(aws iam list-roles --query 'Roles[?RoleName==`account_management_lambda_role`].Arn' --output text) ]; then
  echo -e "\n$(date) - Role not available. \nPlease follow the prerequisite doc present under aws/prerequisite/admin_setup.sh and create the required role"
  exit 1
else
  export LAMBDA_ROLE=$(aws iam list-roles --query 'Roles[?RoleName==`account_management_lambda_role`].Arn' --output text)
  echo -e "\n$(date) - LAMBDA_ROLE: $LAMBDA_ROLE will be used for lambda deployment"
fi

POOL_ACCOUNT=$(get_reusable_account)

if [[ -z $POOL_ACCOUNT ]]; then
    create_account
else
    NEW_ACCOUNT_ID=$POOL_ACCOUNT
fi

echo -e "NEW_ACCOUNT_ID     =    $NEW_ACCOUNT_ID\n\n"

#Move the account from ACCOUNT_POOL_OU to Sandbox OU
echo -e "$(date) - Moving $NEW_ACCOUNT_ID from Pool OU $ACCOUNT_POOL_OU to Sandbox OU $SANDBOX_OU_ID\n"
aws organizations move-account \
  --account-id $NEW_ACCOUNT_ID \
  --source-parent-id $ACCOUNT_POOL_OU \
  --destination-parent-id $SANDBOX_OU_ID

####################################################
#SSO assignment function

sso(){
  EMAIL=$1
  echo "=========================================================================="
  echo -e "\n$(date) - SSO assignment for $EMAIL"

  #GET PRINCIPAL ID OF THE USER FROM IDENTITY STORE
  PRINCIPAL_ID=$(
    aws identitystore list-users \
      --identity-store-id $IDENTITY_STORE_ID \
      --region $AWS_REGION \
      --query 'Users[?UserName==`'"$EMAIL"'`].UserId' \
      --output text
  )

  if [ -z ${PRINCIPAL_ID} ]
  then
    echo -e "$(date) - Provided email is incorrect or the user doesn't exist in identity store. Check with your lead\n"
  else
    echo -e "$(date) - Principal id of the User: ${PRINCIPAL_ID} \n"

    SSO_REQUEST_ID=$(
      aws sso-admin create-account-assignment \
        --instance-arn "$SSO_INSTANCE_ARN" \
        --target-id "$NEW_ACCOUNT_ID" \
        --target-type AWS_ACCOUNT \
        --principal-id "$PRINCIPAL_ID" \
        --principal-type USER \
        --permission-set-arn "$ADMINISTRATOR_ARN" \
        --query 'AccountAssignmentCreationStatus.RequestId' \
        --output text
    )
    sleep 3
    echo "--------------------------------------------------------------------------"
    echo "Account Id       Status         Permission Set"
    aws sso-admin describe-account-assignment-creation-status \
         --instance-arn $SSO_INSTANCE_ARN \
         --account-assignment-creation-request-id $SSO_REQUEST_ID \
         --region $AWS_REGION \
         --query 'AccountAssignmentCreationStatus.[TargetId,Status,PermissionSetArn]' \
         --output text

  fi
  echo -e "\n=========================================================================="
}

if [[ $SSO_ENABLED = "true" ]]; then
    #SSO for requestor
    sso ${USER_EMAIL}

    #SSO for additional users
    if [[ -z "$ADDITIONAL_USER_EMAILS" ]]; then
      echo "No additional users specified to add to this account."
    else
      ADDITIONAL_USER_EMAILS=${ADDITIONAL_USER_EMAILS//, /,}

      IFS=',' read -ra USERS <<< "$ADDITIONAL_USER_EMAILS"
      for email in "${USERS[@]}"; do
        sso "$email"
      done
    fi
else
    bash create_iam_user.sh ${USER_EMAIL}
    #IAM user for additional emails
    if [[ -z "$ADDITIONAL_USER_EMAILS" ]]; then
      echo "No additional users specified to add to this account."
    else
      ADDITIONAL_USER_EMAILS=${ADDITIONAL_USER_EMAILS//, /,}

      IFS=',' read -ra USERS <<< "$ADDITIONAL_USER_EMAILS"
      for email in "${USERS[@]}"; do
        bash create_iam_user.sh "$email"
      done
    fi
fi


##################################################################

echo -e "\n$(date) - Creating Lambda function and schedule to revoke access"


if [[ -z $TICKET_ID ]]; then
  TICKET_ID=0
fi

#substitute the new account created in the python script
awk '{sub(/REPLACE_ACCOUNT_ID/,"'${NEW_ACCOUNT_ID}'"); print}' aws/provision/lambda.py > lambda_function.py

sed -i 's/REPLACE_EMAIL_HERE/'${USER_EMAIL}'/' lambda_function.py
sed -i 's/REPLACE_TICKET_HERE/'${TICKET_ID}'/' lambda_function.py
sed -i 's/REPLACE_TEAM_HERE/'${TEAM}'/' lambda_function.py
sed -i 's/REPLACE_POOL_OU_HERE/'${ACCOUNT_POOL_OU}'/' lambda_function.py
sed -i 's/REPLACE_SANDBOX_OU_HERE/'${SANDBOX_OU_ID}'/' lambda_function.py

#Zip the source code for Lambda

zip -q lambda_function_zip.zip lambda_function.py

export LAMBDA_NAME=temp_sandbox_${NEW_ACCOUNT_ID}

#Create a Lambda function with account to move from the Sandbox OU to Pool OU
FUNCTION_STATE=$(aws lambda create-function \
  --function-name ${LAMBDA_NAME} \
  --role "${LAMBDA_ROLE}" \
  --runtime python3.8 \
  --description "Lambda function for Sandbox account" \
  --zip-file fileb://lambda_function_zip.zip \
  --handler lambda_function.account_handler \
  --query 'StateReason' \
  --output text
  )

echo "$FUNCTION_STATE"

lambda_active() {
  STATUS=$(aws lambda get-function-configuration \
            --function-name ${LAMBDA_NAME} \
            --region $AWS_REGION \
            --query 'LastUpdateStatus' \
            --output text)
  if [[ "${STATUS}" == "Successful" ]]; then
    return 0
  else
    return 1
  fi
}

#wait while the lambda is being created
while ! lambda_active; do
  echo "Waiting for the function to be active"
  sleep 2
done

echo -e "$(date) - Lambda function ${LAMBDA_NAME} created.\n"

#Get the account creation timestamp and create cron schedule based on the duration specified
echo -e "$(date) - Creating cron expression\n"
CRON=$(date -u -d "+${DURATION}hour" +"%M %H %d %m ? %Y" 2>/dev/null ||
  date -u -v "+${DURATION}H" +"%M %H %d %m ? %Y")

echo -e "$(date) - Temporary AWS account provisioned will be moved to Account Pool after ${DURATION} hours, i.e cron schedule : ${CRON} \nRefer : https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-create-rule-schedule.html#eb-cron-expressions \n"

#get function arn
LAMBDA_FUNCTION_ARN=$(aws lambda get-function --function-name ${LAMBDA_NAME} --query 'Configuration.FunctionArn' --output text)

#Create scheduled event in AWS event bridge with the new schedule
#put-rule - create a rule with schedule
aws events put-rule \
  --name ${LAMBDA_NAME} \
  --description "Event rule to trigger lambda for revoking Sandbox account" \
  --schedule-expression "cron(${CRON})"

echo -e "$(date) - Scheduled event named ${LAMBDA_NAME} created.\n"

RULE_ARN=$(aws events describe-rule --name=${LAMBDA_NAME} --query 'Arn' --output text)

echo "$(date) - Permission statement to allow invocation of lambda by events"
aws lambda add-permission \
  --function-name ${LAMBDA_NAME} \
  --statement-id MyId \
  --action 'lambda:InvokeFunction' \
  --principal events.amazonaws.com \
  --source-arn ${RULE_ARN}

echo -e "\n$(date) - Configured lambda permission \n"

#Attach the lambda Function as target to the Event
#put-target - add lambda function as target
aws events put-targets --rule ${LAMBDA_NAME} --targets "Id"="1","Arn"="${LAMBDA_FUNCTION_ARN}"

echo -e "$(date) - Added lambda function as target to the scheduled event\n"

rm lambda_function.py lambda_function_zip.zip

banner "Completed. Find the summary below"

echo "Temporary account provisioned : ${NEW_ACCOUNT_ID}"
echo "SSO for user ${USER_EMAIL} configured with ADMINISTRATOR access"
echo "Created schedule for revoking the access after ${DURATION} hours"

