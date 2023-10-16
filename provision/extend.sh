

export LAMBDA_NAME=temp_sandbox_${1}
export DURATION=$(echo "$2" | awk -F' ' '{ print $1 }')
export LAMBDA_LAYER_ARN=$(aws lambda list-layer-versions --layer-name requests_dependency --query 'LayerVersions[0].LayerVersionArn' --output text)
export AWS_REGION="us-east-1"
#add dependency
aws lambda update-function-configuration --function-name ${LAMBDA_NAME} \
	--layers ${LAMBDA_LAYER_ARN} \
	--region $AWS_REGION

#create cron
CRON=$(date -u -d "+${DURATION}hour" +"%M %H %d %m ? %Y" 2>/dev/null ||
	date -u -v "+${DURATION}H" +"%M %H %d %m ? %Y")

#update cron
aws events put-rule \
	--name ${LAMBDA_NAME} \
	--schedule-expression "cron(${CRON})" \
	--region $AWS_REGION
