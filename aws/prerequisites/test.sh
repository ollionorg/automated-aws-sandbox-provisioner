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


# You can now use the $TEAM_OU_MAPPING_OUTPUT variable as needed in your script
TEAM_OPTIONS="-"$'\n'
for team_name in "${TEAM_NAMES[@]}"; do
    TEAM_OPTIONS+="          - $team_name"$'\n'
done

find ../../.github/workflows -type f -iname "*.yml" -exec bash -c "m4 -D REPLACE_WORKFLOW_TEAM_INPUT_OPTIONS=\"$TEAM_OPTIONS\" {} > {}.m4  && cat {}.m4 > {} && rm {}.m4" \;
