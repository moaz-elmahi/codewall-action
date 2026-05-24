#!/bin/bash
set -e

TARGET_BRANCH="${INPUT_BRANCH}"
TEAM_LEADERS="${INPUT_TEAM_LEADERS}"
DEVOPS_USERS="${INPUT_DEVOPS}"
DEVELOPERS_LIST="${INPUT_DEVELOPERS}"
GH_PAT="${INPUT_PAT}"
ACTOR="${GITHUB_ACTOR}"
REPOSITORY="${GITHUB_REPOSITORY}"

echo "=========================================="
echo "Checking authorization for user: $ACTOR"
echo "Target Branch: $TARGET_BRANCH"
echo "=========================================="

USER_ROLE="developer"

if [[ " ,${TEAM_LEADERS}, " == *",${ACTOR},"* ]]; then
    USER_ROLE="team_leader"
elif [[ " ,${DEVOPS_USERS}, " == *",${ACTOR},"* ]]; then
    USER_ROLE="devops"
elif [[ " ,${DEVELOPERS_LIST}, " == *",${ACTOR},"* ]]; then
    USER_ROLE="developer"
fi

echo "Identified Role for $ACTOR: $USER_ROLE"

AUTHORIZED="false"


if [[ "$USER_ROLE" == "team_leader" || "$USER_ROLE" == "devops" ]]; then
    echo "Access granted: $USER_ROLE has full access."
    AUTHORIZED="true"
elif [[ "$USER_ROLE" == "developer" ]]; then
    if [[ "$TARGET_BRANCH" == "main" || "$TARGET_BRANCH" == "master" || "$TARGET_BRANCH" == "production" ]]; then
        echo "Access denied: Developers cannot push directly to $TARGET_BRANCH."
        AUTHORIZED="false"
    else
        echo "Access granted: Developers can push to $TARGET_BRANCH."
        AUTHORIZED="true"
    fi
fi

if [[ "$AUTHORIZED" == "false" && "$ACTOR" != "github-actions[bot]" ]]; then
    echo "Unauthorized push detected. Reverting changes..."
    
    git config --global user.name "github-actions[bot]"
    git config --global user.email "github-actions[bot]@://github.com"
    git config --global --add safe.directory /github/workspace
    
    TARGET_SHA=$(jq --raw-output .before "$GITHUB_EVENT_PATH")
    
    if [ -z "$TARGET_SHA" ] || [ "$TARGET_SHA" == "0000000000000000000000000000000000000000" ]; then
        git reset --hard HEAD~1
    else
        git reset --hard "$TARGET_SHA"
    fi
    
    git remote set-url origin "https://x-access-token:${GH_PAT}@://github.com{REPOSITORY}.git"
    git push origin "$TARGET_BRANCH" --force
    
    exit 1
fi
