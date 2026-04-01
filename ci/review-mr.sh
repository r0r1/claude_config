#!/bin/bash
set -euo pipefail

# Claude Code CI Review Script
# Runs AI code review on GitLab Merge Requests and posts results as MR notes.
# Works with any project type: Rails, Next.js, Flutter, etc.
#
# Required CI/CD variables: ANTHROPIC_API_KEY, GITLAB_BOT_TOKEN
# Required CI variables (auto-set by GitLab): CI_MERGE_REQUEST_IID,
#   CI_MERGE_REQUEST_SOURCE_BRANCH_NAME, CI_MERGE_REQUEST_TARGET_BRANCH_NAME,
#   CI_API_V4_URL, CI_PROJECT_ID

# Ensure claude is in PATH (installed in before_script)
export PATH="$HOME/.claude/bin:$PATH"

# Validate required variables
for var in CI_MERGE_REQUEST_IID CI_MERGE_REQUEST_SOURCE_BRANCH_NAME CI_MERGE_REQUEST_TARGET_BRANCH_NAME CI_API_V4_URL CI_PROJECT_ID GITLAB_BOT_TOKEN; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required variable $var is not set."
    exit 1
  fi
done

# Fetch target branch and compute diff
git fetch origin "${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}"
DIFF=$(git diff "origin/${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}...HEAD")

if [ -z "$DIFF" ]; then
  echo "No changes detected. Skipping review."
  exit 0
fi

# Auto-detect project type from files in the repo
detect_project_type() {
  local types=""
  [ -f "Gemfile" ] && types="${types}rails,"
  [ -f "package.json" ] && grep -q '"next"' package.json 2>/dev/null && types="${types}nextjs,"
  [ -f "pubspec.yaml" ] && types="${types}flutter,"
  [ -f "package.json" ] && grep -q '"angular"' package.json 2>/dev/null && types="${types}angular,"
  [ -f "package.json" ] && grep -q '"express"' package.json 2>/dev/null && types="${types}node,"
  echo "${types%,}"  # trim trailing comma
}

PROJECT_TYPE=$(detect_project_type)
echo "Detected project type(s): ${PROJECT_TYPE:-unknown}"
echo "Running Claude Code review on MR !${CI_MERGE_REQUEST_IID}..."
echo "Branch: ${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME} -> ${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}"

# Build project-specific review focus areas
build_review_focus() {
  local focus="Focus on:
1. Security vulnerabilities (injection, XSS, CSRF, insecure data handling)
2. Performance issues (unnecessary computations, memory leaks, inefficient algorithms)
3. DRY violations (duplicated logic, missed abstractions)
4. Clean Code violations (naming, SRP, method/function length, complexity)
5. Missing or inadequate tests
6. Logic errors or bugs
7. Observability (missing logs, error tracking, structured logging)
"

  if [[ "$PROJECT_TYPE" == *"rails"* ]]; then
    focus="${focus}
Rails-specific:
8. N+1 queries, missing indexes, slow queries
9. Fat models/skinny controllers, proper use of concerns and service objects
10. Mass assignment protection, strong parameters
11. Proper use of callbacks, validations, and scopes
12. Migration safety for zero-downtime deployments
"
  fi

  if [[ "$PROJECT_TYPE" == *"nextjs"* ]]; then
    focus="${focus}
Next.js-specific:
8. Server vs client component boundaries
9. Data fetching strategy (SSR, SSG, ISR, client-side)
10. Proper use of App Router patterns
11. Image optimization, bundle size
12. API route security and validation
"
  fi

  if [[ "$PROJECT_TYPE" == *"flutter"* ]]; then
    focus="${focus}
Flutter/Dart-specific:
8. State management patterns (Riverpod, BLoC, Provider)
9. Widget composition and reusability
10. Proper lifecycle management and disposal
11. Platform-specific considerations (iOS/Android)
12. Null safety and type safety
13. Navigation and routing patterns
"
  fi

  if [[ "$PROJECT_TYPE" == *"angular"* ]]; then
    focus="${focus}
Angular-specific:
8. Component architecture and module organization
9. RxJS patterns and subscription management
10. Change detection strategy
11. Lazy loading and bundle optimization
12. Template security (sanitization, trusted types)
"
  fi

  echo "$focus"
}

REVIEW_FOCUS=$(build_review_focus)

# ANTHROPIC_API_KEY is auto-detected from CI/CD variables
REVIEW_OUTPUT=$(claude -p \
  "You are a senior code reviewer. Review this GitLab MR !${CI_MERGE_REQUEST_IID} (${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME} -> ${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}).

Project type(s) detected: ${PROJECT_TYPE:-unknown}

${REVIEW_FOCUS}

For each issue found, provide:
- File path and line number
- Severity: Critical / Warning / Info
- Category: Security | Performance | DRY | Clean Code | Testing | Bug | Observability | Best Practice
- Description of the issue
- Suggested fix with code example

Format the output as a clear markdown report with sections grouped by severity.

Here are the code changes:

${DIFF}" 2>&1 || true)

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
