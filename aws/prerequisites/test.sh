#!/bin/bash

# Declare the arrays
TEAM_NAMES=("dev-team" "qa-team" "devops-team")
TEAM_SANDBOX_OUs=("ou-6pbt-49d0vb50" "ou-6pbt-8yp0lf3e" "ou-6pbt-lkqhzc8a")
TEAM_POOL_OUs=("ou-6pbt-xh364wnr" "ou-6pbt-4dguhonx" "ou-6pbt-pnwre24b")

# Check if at least one team is defined
if [ ${#TEAM_NAMES[@]} -eq 0 ]; then
    echo "Error: At least one team must be defined."
    exit 1
fi

# Check if any team name is blank
for team_name in "${TEAM_NAMES[@]}"; do
    if [ -z "$team_name" ]; then
        echo "Error: Team name cannot be blank."
        exit 1
    fi
done

# Check if the number of teams matches the number of OU IDs
if [[ ${#TEAM_NAMES[@]} -ne ${#TEAM_SANDBOX_OUs[@]} || ${#TEAM_NAMES[@]} -ne ${#TEAM_POOL_OUs[@]} ]]; then
    echo "Error: The number of teams does not match the number of OU IDs."
    exit 1
fi

# Initialize the TEAM_OU_MAPPING_OUTPUT variable
TEAM_OU_MAPPING_OUTPUT=""

# Append to the TEAM_OU_MAPPING_OUTPUT variable
TEAM_OU_MAPPING_OUTPUT+="case \${{ inputs.TEAM }} in"$'\n'

# Generate the case statements dynamically based on the arrays
for ((i = 0; i < ${#TEAM_NAMES[@]}; i++)); do
    team_name="${TEAM_NAMES[i]}"
    sandbox_ou_id="${TEAM_SANDBOX_OUs[i]}"
    pool_ou_id="${TEAM_POOL_OUs[i]}"

    TEAM_OU_MAPPING_OUTPUT+="    $team_name)"$'\n'
    TEAM_OU_MAPPING_OUTPUT+="        echo \"SANDBOX_OU_ID=$sandbox_ou_id\" >> \$GITHUB_OUTPUT"$'\n'
    TEAM_OU_MAPPING_OUTPUT+="        echo \"POOL_OU_ID=$pool_ou_id\" >> \$GITHUB_OUTPUT"$'\n'
    TEAM_OU_MAPPING_OUTPUT+="        ;;"$'\n'
done

# Append the esac to close the case statement
TEAM_OU_MAPPING_OUTPUT+="esac"$'\n'


WORKFLOW_TEAM_INPUT_OPTIONS=""
for team_name in "${TEAM_NAMES[@]}"; do
    WORKFLOW_TEAM_INPUT_OPTIONS+="  - $team_name"$'\n'
done


# Output the generated script
echo "Generated script:"
echo "$TEAM_OU_MAPPING_OUTPUT"

# Set the WORKFLOW_TEAM_INPUT_OPTIONS variable
echo "WORKFLOW_TEAM_INPUT_OPTIONS:"
echo "$WORKFLOW_TEAM_INPUT_OPTIONS"

# You can now use the $TEAM_OU_MAPPING_OUTPUT variable as needed in your script
