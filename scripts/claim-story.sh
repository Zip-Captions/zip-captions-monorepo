#!/bin/bash
# Claim a story: assign to yourself and move to "In Progress".
# Usage: ./scripts/claim-story.sh P0-US-001
#
# The story ID should match the issue title prefix.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env.github"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env.github not found. See scripts/README.md for setup instructions."
  exit 1
fi

source "$ENV_FILE"

STORY_ID="$1"

if [ -z "$STORY_ID" ]; then
  echo "Usage: ./scripts/claim-story.sh <story-id>"
  echo "Example: ./scripts/claim-story.sh P0-US-001"
  exit 1
fi

if [ -z "$GITHUB_PROJECT_TOKEN" ] || [ -z "$GITHUB_REPO_OWNER" ] || [ -z "$GITHUB_REPO_NAME" ]; then
  echo "ERROR: Missing required variables in .env.github"
  exit 1
fi

# Find the issue by searching for the story ID in the title
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

# Check if already assigned
CURRENT_ASSIGNEE=$(GITHUB_TOKEN="$GITHUB_PROJECT_TOKEN" gh issue view "$ISSUE_NUMBER" \
  --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME" \
  --json assignees \
  --jq '.assignees[0].login // empty')

if [ -n "$CURRENT_ASSIGNEE" ]; then
  echo "WARNING: Issue #$ISSUE_NUMBER is already assigned to $CURRENT_ASSIGNEE"
  echo "If you want to reassign, do it manually on GitHub."
  exit 1
fi

# Get current user
CURRENT_USER=$(GITHUB_TOKEN="$GITHUB_PROJECT_TOKEN" gh api user --jq '.login')

# Assign the issue
GITHUB_TOKEN="$GITHUB_PROJECT_TOKEN" gh issue edit "$ISSUE_NUMBER" \
  --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME" \
  --add-assignee "$CURRENT_USER"

# Update labels: remove status:ready, add status:in-progress
GITHUB_TOKEN="$GITHUB_PROJECT_TOKEN" gh issue edit "$ISSUE_NUMBER" \
  --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME" \
  --remove-label "status:ready" \
  --add-label "status:in-progress"

echo "Claimed: #$ISSUE_NUMBER ($STORY_ID)"
echo "Assigned to: $CURRENT_USER"
echo "Status: In Progress"
echo ""
echo "Next steps:"
echo "  1. Create your feature branch: git checkout -b feature/$STORY_ID-short-name"
echo "  2. Write failing tests"
echo "  3. Run: ./scripts/update-status.sh $STORY_ID 'Tests Written'"
