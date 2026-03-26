#!/bin/bash
# List stories in the "Ready" column that are not assigned to anyone.
# Usage: ./scripts/list-available.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env.github"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env.github not found. See scripts/README.md for setup instructions."
  exit 1
fi

source "$ENV_FILE"

if [ -z "$GITHUB_PROJECT_TOKEN" ] || [ -z "$GITHUB_REPO_OWNER" ] || [ -z "$GITHUB_REPO_NAME" ]; then
  echo "ERROR: Missing required variables in .env.github"
  echo "Required: GITHUB_PROJECT_TOKEN, GITHUB_REPO_OWNER, GITHUB_REPO_NAME"
  exit 1
fi

echo "Fetching stories ready for work..."
echo ""

GITHUB_TOKEN="$GITHUB_PROJECT_TOKEN" gh issue list \
  --repo "$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME" \
  --label "status:ready" \
  --no-assignee \
  --state open \
  --json number,title,labels \
  --template '{{range .}}#{{.number}} {{.title}} [{{range .labels}}{{.name}} {{end}}]{{"\n"}}{{end}}'

echo ""
echo "Pick a story and run: ./scripts/claim-story.sh <story-id>"
