#!/bin/bash
set -euo pipefail

# Claude Code CI Review Script
# Runs AI code review on GitLab Merge Requests and posts results as MR notes.
#
# Required CI/CD variables: ANTHROPIC_API_KEY, GITLAB_BOT_TOKEN
# Required CI variables (auto-set by GitLab): CI_MERGE_REQUEST_IID,
#   CI_PROJECT_URL, CI_API_V4_URL, CI_PROJECT_ID

export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"

# Verify Claude Code is installed and working
claude --version || { echo "ERROR: Claude Code is not installed or not in PATH."; exit 1; }

# Validate required variables
for var in CI_MERGE_REQUEST_IID CI_PROJECT_URL CI_API_V4_URL CI_PROJECT_ID GITLAB_BOT_TOKEN; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required variable $var is not set."
    exit 1
  fi
done

MR_URL="${CI_PROJECT_URL}/-/merge_requests/${CI_MERGE_REQUEST_IID}"
echo "Running Claude Code review on MR !${CI_MERGE_REQUEST_IID}..."

# Let Claude handle everything: diff analysis, project detection, review
REVIEW_OUTPUT=$(claude -p "Review this GitLab MR: ${MR_URL}

Use /code-review to perform a comprehensive code review. Output as markdown." 2>&1 || true)

if [ -z "$REVIEW_OUTPUT" ]; then
  echo "WARNING: Claude returned empty output."
  REVIEW_OUTPUT="Claude Code review completed but returned no output. This may indicate an API issue."
fi

# Post review as MR note
ESCAPED=$(echo "$REVIEW_OUTPUT" | jq -Rs .)
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --request POST \
  --header "PRIVATE-TOKEN: ${GITLAB_BOT_TOKEN}" \
  --header "Content-Type: application/json" \
  --data "{\"body\": ${ESCAPED}}" \
  "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/notes")

if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
  echo "Review posted successfully to MR !${CI_MERGE_REQUEST_IID} (HTTP ${HTTP_STATUS})"
else
  echo "ERROR: Failed to post review to MR (HTTP ${HTTP_STATUS})"
  exit 1
fi
