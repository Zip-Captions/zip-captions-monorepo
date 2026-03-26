#!/bin/bash
# Update a story's status by changing its label.
# Usage: ./scripts/update-status.sh P0-US-001 "Tests Written"
#
# Valid statuses: "In Progress", "Tests Written", "In Review"
# Note: "Ready" and "Done" are managed by humans only.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env.github"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env.github not found. See scripts/README.md for setup instructions."
  exit 1
fi

source "$ENV_FILE"

STORY_ID="$1"
NEW_STATUS="$2"

if [ -z "$STORY_ID" ] || [ -z "$NEW_STATUS" ]; then
  echo "Usage: ./scripts/update-status.sh <story-id> <status>"
  echo "Valid statuses: 'In Progress', 'Tests Written', 'In Review'"
  echo "Example: ./scripts/update-status.sh P0-US-001 'Tests Written'"
  exit 1
fi

if [ -z "$GITHUB_PROJECT_TOKEN" ] || [ -z "$GITHUB_REPO_OWNER" ] || [ -z "$GITHUB_REPO_NAME" ]; then
  echo "ERROR: Missing required variables in .env.github"
  exit 1
fi

# Map status to label
case "$NEW_STATUS" in
  "In Progress")  LABEL="status:in-progress" ;;
  "Tests Written") LABEL="status:tests-written" ;;
  "In Review")     LABEL="status:in-review" ;;
  *)
    echo "ERROR: Invalid status '$NEW_STATUS'"
    echo "Valid statuses: 'In Progress', 'Tests Written', 'In Review'"
    echo "'Ready' and 'Done' are managed by humans only."
    exit 1
    ;;
esac

# Find the issue
ISSUE_NUMBER=$(GITHUB_TOKEN="$GITHUB_PROJECT_TOKEN" gh issue list \
  --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME" \
  --search "$STORY_ID in:title" \
  --state open \
  --json number \
  --jq '.[0].number // empty')

if [ -z "$ISSUE_NUMBER" ]; then
  echo "ERROR: No open issue found matching '$STORY_ID'"
  exit 1
fi

# Remove all status labels, then add the new one
for OLD_LABEL in status:ready status:in-progress status:tests-written status:in-review; do
  GITHUB_TOKEN="$GITHUB_PROJECT_TOKEN" gh issue edit "$ISSUE_NUMBER" \
    --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME" \
    --remove-label "$OLD_LABEL" 2>/dev/null || true
done

GITHUB_TOKEN="$GITHUB_PROJECT_TOKEN" gh issue edit "$ISSUE_NUMBER" \
  --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME" \
  --add-label "$LABEL"

echo "Updated: #$ISSUE_NUMBER ($STORY_ID)"
echo "Status: $NEW_STATUS"
