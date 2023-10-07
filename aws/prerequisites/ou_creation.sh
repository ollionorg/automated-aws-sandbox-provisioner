#!/bin/bash

#export PARENT_OU_ID="" # Keep blank to use the default OU creation under root OU as parent


#export TEAM_NAMES=("dev-team" "qa-team")
declare -a TEAM_SANDBOX_OUs=()
declare -a TEAM_POOL_OUs=()

# Create a function to create an OU
create_ou() {
    local ou_name="$1"
    local parent_ou="$2"
    OU_ID_CREATED=$(aws organizations create-organizational-unit --parent-id "$parent_ou" --name "$ou_name" | jq -r '.OrganizationalUnit.Id')
    echo "$OU_ID_CREATED"
}

# Function to add OU to the array
add_ou_to_array() {
    local team_ou="$1"
    local team_pool_ou="$2"
    TEAM_SANDBOX_OUs+=("$team_ou")
    TEAM_POOL_OUs+=("$team_pool_ou")
}

# Check if PARENT_OU_ID is blank or empty
if [ -z "$PARENT_OU_ID" ]; then
    echo "PARENT_OU_ID is blank or empty. Considering the root of the org as parent to create the Sandbox OU"
    echo "If you want to use a specific parent, please modify the PARENT_OU_ID variable with the value"

    PARENT_OU_ID=$(aws organizations list-roots --output json | jq -r '.Roots[].Id')
    echo "Using $PARENT_OU_ID as parent to deploy the OUs for sandbox provisioner."

else
    OU_EXISTS=$(aws organizations describe-organizational-unit --organizational-unit-id "$PARENT_OU_ID" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "Provided PARENT_OU_ID does not exist: $PARENT_OU_ID"
        echo "Please check and correct. Exiting..."
        exit 1
    fi
    echo "PARENT_OU_ID provided is $PARENT_OU_ID. All the OUs for sandbox provisioner will be created under this OU"

fi

echo "-------------------------------"
echo "Creating main Sandbox OU"
SANDBOX_OU_ID=$(create_ou "SANDBOX_OU" "$PARENT_OU_ID")
echo "Sandbox OU id : $SANDBOX_OU_ID"

# Iterate through the team names and create OUs
for team_name in "${TEAM_NAMES[@]}"; do
    echo "-------------------------------"
    echo "Working on OU creation for $team_name"
    team_sandbox_ou="${team_name}-sandbox-ou"
    team_sandbox_pool_ou="${team_name}-sandbox-pool-ou"

    TEAM_OU=$(create_ou "$team_sandbox_ou" "$SANDBOX_OU_ID")
    TEAM_POOL_OU=$(create_ou "$team_sandbox_pool_ou" "$TEAM_OU")
    sleep 1
    add_ou_to_array "$TEAM_OU" "$TEAM_POOL_OU"
    echo "Created OUs for $team_name : $TEAM_OU, $TEAM_POOL_OU"
done
echo "-------------------------------"
# Print the arrays
echo "TEAM_SANDBOX_OUs: ${TEAM_SANDBOX_OUs[*]}"
echo "TEAM_POOL_OUs: ${TEAM_POOL_OUs[*]}"