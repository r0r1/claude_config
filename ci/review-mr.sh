#!/bin/bash
set -euo pipefail

# Claude Code CI Review Script
# Invokes the code-review skill via claude -p for comprehensive MR reviews.
# Claude reads CLAUDE.md conventions, changed files, and related files automatically.
#
# Cost optimization:
#   - Sonnet model (~10x cheaper than Opus)
#   - Max 5 turns (enough to read files + review, prevents runaway)
#   - Estimated cost: ~$0.02-0.08 per review
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
TARGET_BRANCH="${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:-main}"
echo "Running Claude Code review on MR !${CI_MERGE_REQUEST_IID}..."

# Build MCP config flag if mcp.json exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_FLAGS=""
if [ -f "${SCRIPT_DIR}/mcp.json" ]; then
  MCP_FLAGS="--mcp-config ${SCRIPT_DIR}/mcp.json"
  echo "MCP config found, loading integrations..."
fi

# Invoke code-review skill with Sonnet model.
# Claude will read CLAUDE.md for conventions, inspect changed & related files.
REVIEW_OUTPUT=$(claude --model sonnet --max-turns 5 \
  $MCP_FLAGS \
  -p "Review the changes on the current branch compared to ${TARGET_BRANCH}. Use the code-review skill. Output as markdown." 2>&1 || true)

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
