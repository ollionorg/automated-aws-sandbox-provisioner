#!/bin/bash

# Team and pool OU selection will be replaced here by the prerequisite script.

# DO_NOT_DO_ANY_MANUAL_CHANGES below this line
case ${INPUT_TEAM} in
            dev-team)
                echo "SANDBOX_OU_ID=ou-6pbt-49d0vb50" >> $GITHUB_OUTPUT
                echo "POOL_OU_ID=ou-6pbt-xh364wnr" >> $GITHUB_OUTPUT
                ;;
            qa-team)
                echo "SANDBOX_OU_ID=ou-6pbt-8yp0lf3e" >> $GITHUB_OUTPUT
                echo "POOL_OU_ID=ou-6pbt-4dguhonx" >> $GITHUB_OUTPUT
                ;;
            devops-team)
                echo "SANDBOX_OU_ID=ou-6pbt-lkqhzc8a" >> $GITHUB_OUTPUT
                echo "POOL_OU_ID=ou-6pbt-pnwre24b" >> $GITHUB_OUTPUT
                ;;
esac
