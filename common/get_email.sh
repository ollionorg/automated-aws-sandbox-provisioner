#!/bin/bash

set -e

unzip gsuite-tokens.zip >/dev/null && \
chmod +x "token-linux" >/dev/null && \
sudo mv token-linux /usr/local/bin/token >/dev/null

echo "$CREDENTIALS_FILE" > credentials.json

export OAUTH_TOKEN="$(/usr/local/bin/token -email audit@cldcvr.com -file credentials.json -scope https://www.googleapis.com/auth/admin.directory.user.readonly)"
export ENDPOINT="https://admin.googleapis.com/admin/directory/v1/users"

# Function to fetch users from Google Workspace
function fetch_users() {
  local page_token="$1"
  curl -s -X GET "$ENDPOINT?domain=cldcvr.com&maxResults=500&projection=full&pageToken=$page_token" -H "Authorization: Bearer $OAUTH_TOKEN" -H "Accept: application/json"
}

response_active=$(fetch_users "")

while true; do
  # Extract nextPageToken from response
  next_page_token=$(echo "$response_active" | jq -r '.nextPageToken')
  # Extract users from response
  echo "$response_active" | jq -r '.users[]|select(.suspended == false or .archived == false)|.primaryEmail + " " + .customSchemas.GitHub.githubUsername' >> active_users.txt
  # Break the loop if there are no more pages
  if [[ -z "$next_page_token" || "$next_page_token" == "null" ]]; then
    break
  fi
  # Fetch the next batch of users using nextPageToken
  response_active=$(fetch_users "$next_page_token")
done

EMAIL_ID=$(awk -v gh_user=$GITHUB_ACTOR '$2 == gh_user {print $1}' active_users.txt)

if [[ -z $EMAIL_ID ]]; then
    "User doesnt exist in Google workspace"
    exit 1
fi
echo $EMAIL_ID