---
name: code-review
description: Comprehensive code review for GitHub/GitLab pull/merge requests with Linear/Jira integration. Works globally from any directory - auto-clones repo if needed and compares against main branch.
---

# Code Review Skill

Performs comprehensive code reviews for GitHub Pull Requests or GitLab Merge Requests with issue tracker integration (Linear, Jira). This skill works globally from any directory and will automatically clone the repository if needed.

## Usage

This skill is invoked automatically when you request a code review. Examples:
- "Review GitHub PR #123 for project/repo with Linear issue ENG-456"
- "Review GitLab MR !789 with Jira issue PROJ-123"
- "Review PR https://github.com/owner/repo/pull/123"

## Instructions

### Step 1: Parse Request and Identify Platform

Determine the platform and extract necessary information:

**GitHub Pattern:**
- URL: `https://github.com/{owner}/{repo}/pull/{number}`
- Short form: `PR #{number}` or `#{number}`
- Extract: owner, repo, PR number

**GitLab Pattern:**
- URL: `https://gitlab.com/{group}/{project}/-/merge_requests/{id}`
- Short form: `MR !{number}` or `!{number}`
- Extract: group, project, MR ID

**Issue Tracker** (independent of git platform — any combination is valid):
- Linear: `{TEAM}-{number}` (e.g., ENG-123) — detected when Linear MCP server is connected
- Jira: `{PROJECT}-{number}` (e.g., PROJ-456) — detected when Jira MCP server is connected
- If both MCP servers are connected, ask the user which tracker the issue belongs to
- GitHub+Jira, GitLab+Linear, GitHub+Linear, GitLab+Jira — all supported

If short form is used, ask the user for the repository details.

### Step 2: Check if Repository Exists Locally

Use the Bash tool to check if the repository exists:

```bash
# Extract repo name from URL or user input
REPO_NAME="repo-name"
REPO_PATH="$HOME/code/code-reviews/$REPO_NAME"

if [ -d "$REPO_PATH" ]; then
  echo "Repository exists at: $REPO_PATH"
  cd "$REPO_PATH"
  git fetch origin
else
  echo "Repository not found locally"
fi
```

### Step 3: Clone Repository if Needed

If the repository doesn't exist locally, clone it:

**For GitHub:**
```bash
REPO_URL="https://github.com/{owner}/{repo}.git"
REPO_PATH="$HOME/code/code-reviews/{repo}"

# Create directory if it doesn't exist
mkdir -p "$HOME/code/code-reviews"

echo "Cloning repository to $REPO_PATH..."
git clone "$REPO_URL" "$REPO_PATH"
cd "$REPO_PATH"
```

**For GitLab:**
```bash
REPO_URL="https://gitlab.com/{group}/{project}.git"
REPO_PATH="$HOME/code/code-reviews/{project}"

# Create directory if it doesn't exist
mkdir -p "$HOME/code/code-reviews"

echo "Cloning repository to $REPO_PATH..."
git clone "$REPO_URL" "$REPO_PATH"
cd "$REPO_PATH"
```

**Important:**
- Use `$HOME/code/code-reviews/` as the base directory for cloning
- This keeps all code review repositories separate from your regular projects
- Ensure proper git credentials are configured

### Step 4: Fetch PR/MR Branch

Once in the repository directory, fetch the PR/MR branch:

**For GitHub:**
```bash
# Fetch the PR branch
git fetch origin pull/{PR_NUMBER}/head:pr-{PR_NUMBER}
git checkout pr-{PR_NUMBER}

# Update main/master branch
git fetch origin main:main 2>/dev/null || git fetch origin master:master
```

**For GitLab:**
```bash
# Fetch all branches and checkout the MR branch
git fetch origin

# Get the source branch name from GitLab MCP or ask user
SOURCE_BRANCH="{source-branch-name}"
git checkout "$SOURCE_BRANCH"

# Update main/master branch
git fetch origin main:main 2>/dev/null || git fetch origin master:master
```

### Step 5: Get Code Changes

**IMPORTANT: Use MCP tools exclusively. DO NOT use git bash commands (git diff, git log, etc.).**

**For GitHub:**
```
Use MCP tool: mcp__github__get_pull_request_files (or list_pull_request_files)
Parameters:
- Owner: {owner}
- Repo: {repo}
- Pull number: {PR_NUMBER}
```

**For GitLab:**
```
Use MCP tool: mcp__gitlab__list_merge_request_diffs
Parameters:
- Merge request identifier: {PROJECT_PATH}!{MR_IID}
```

Parse and organize changes by file:
```
File: path/to/file.rb
Status: modified (added/removed/renamed)
Lines changed: 42-56, 89-102

Diff:
[Full diff content with line numbers and context]
```

Preserve exact line numbers — used later for inline comments.

### Step 6: Fetch Issue Tracker Details

**For Linear Integration:**

Use Linear MCP tools (check with `/mcp inspect linear`):

```
Use MCP tool: mcp__linear__get_issue
Parameters:
- Issue ID: {LINEAR_ISSUE_ID}

Then fetch comments:
Use MCP tool: mcp__linear__get_comments or check if included in issue response
```

Extract and store:
- Issue title, description, status, priority
- Labels, assignee, project
- All comments with authors and timestamps

**For Jira Integration:**

Use Jira MCP tools (check with `/mcp inspect jira`):

```
Use MCP tool: mcp__jira__get_issue
Parameters:
- Issue key: {JIRA_ISSUE_KEY}
```

Extract and store:
- Issue summary, description, status, priority
- Components, labels, assignee
- Comments and activity

### Step 7: Fetch PR/MR Details

**For GitHub:**

Use GitHub MCP tools:

```
Use MCP tool: mcp__github__get_pull_request
Parameters:
- Owner: {owner}
- Repo: {repo}
- Pull number: {PR_NUMBER}

Then fetch PR files:
Use MCP tool: mcp__github__get_pull_request_files
Parameters:
- Owner: {owner}
- Repo: {repo}
- Pull number: {PR_NUMBER}
```

**For GitLab:**

Use GitLab MCP tools:

```
Use MCP tool: mcp__gitlab__get_merge_request
Parameters:
- Project: {group/project}
- Merge request IID: {MR_ID}

Then fetch MR changes:
Use MCP tool: mcp__gitlab__get_merge_request_changes
Parameters:
- Project: {group/project}
- Merge request IID: {MR_ID}
```

### Step 8: Fetch Existing Review Comments

**For GitHub:**

```
Use MCP tool: mcp__github__list_review_comments
Parameters:
- Owner: {owner}
- Repo: {repo}
- Pull number: {PR_NUMBER}
```

**For GitLab:**

```
Use MCP tool: mcp__gitlab__list_merge_request_discussions
Parameters:
- Project: {group/project}
- Merge request IID: {MR_ID}
```

Parse existing comments to avoid duplicates and check for resolved issues.

### Step 9: Launch Code Review Agent

Use the Task tool to launch the appropriate code review agent:

**For full-stack (Rails/Next.js) projects:**
```
Use Task tool with subagent_type: fullstack-code-reviewer
```

**For mobile (Flutter) projects:**
```
Use Task tool with subagent_type: mobile-code-reviewer
```

**Provide comprehensive prompt with cache_control breakpoints on large static content:**

Structure the prompt with `cache_control: {"type": "ephemeral"}` markers at the end of each large static block to enable prompt caching and reduce token costs on repeated or continued reviews:

```
You are reviewing a {GitHub PR / GitLab MR} in the context of a {Linear / Jira} issue.

**Issue Context:**                          ← cache_control breakpoint after this block
{Insert issue details with title, description, status, priority, comments}

**PR/MR Details:**                          ← cache_control breakpoint after this block
{Insert PR/MR details with title, description, author, branches}

**Existing Review Comments:**               ← cache_control breakpoint after this block
{Insert list of existing comments to avoid duplicates}

**Your Task:**

**OBJECTIVE 1: Verify Existing Review Comments**
For each existing review comment:
1. Check if the issue is still present in the current code
2. Determine status: FIXED, STILL_PRESENT, or CANNOT_VERIFY
3. Provide evidence (code snippet)

**OBJECTIVE 2: Find New Issues**
Review the code changes and analyze:
1. Security vulnerabilities
2. Performance issues (N+1 queries, missing indexes)
3. DRY principle violations
4. Framework Best Practices, Refactor, and Simplify the flow / methods, check are there changes can be reusable instead of build method from scratch?
5. Changing patterns and standardization? service should extend from the specific parent already defined? e.g services / controller / models / views miss configuration and miss purpose?
6. Clean Code standard violations
7. Missing or inadequate tests
8. Logic errors or bugs
9. Alignment with issue requirements
10. Discussion points from issue comments
11. **Observability & Troubleshooting** — review all logging, error reporting, and traceability practices:
    - **Missing logs**: Are critical paths, state transitions, and business events logged? Entry/exit of important operations should be logged at appropriate levels (debug, info, warn, error).
    - **Log quality**: Do log messages include enough context to diagnose issues without reading code? Check for: correlation/trace IDs, user/request identifiers, relevant payload fields (avoid logging sensitive data like passwords/tokens), and structured fields (prefer structured/JSON logging over string concatenation).
    - **Log levels**: Are levels used correctly? (debug=dev detail, info=normal flow, warn=recoverable anomaly, error=requires attention, fatal=system cannot continue). Avoid logging errors for expected/business exceptions.
    - **Traceability**: Is there a consistent trace/correlation ID propagated through async calls, background jobs, and service boundaries? Without this, distributed debugging is nearly impossible.
    - **Error reporting to external tools (e.g. Sentry, Datadog, Rollbar)**: Are errors captured and sent to the error tracking tool? Check that: exceptions are not silently swallowed, `Sentry.capture_exception` (or equivalent) is called in rescue/catch blocks for unexpected errors, extra context (user, request, tags) is attached before capturing, and business/expected errors are NOT sent to Sentry (to reduce noise).
    - **Avoid double logging**: Don't log AND capture to Sentry for the same error in multiple layers — pick one consistent place per layer.
    - **Log rotation/volume**: Are there any log statements inside tight loops or high-frequency paths that could flood logs? Suggest rate-limiting or sampling if so.
    - **Sensitive data in logs**: Flag any log statement that may accidentally log PII, credentials, tokens, or payment data.

**Changed Files:**                          ← cache_control breakpoint after this block
{Insert file changes from git diff}

**Output Format:**
Return a JSON object:

```json
{
  "existing_comments_verification": [
    {
      "comment_id": "string",
      "file_path": "string",
      "line_number": 42,
      "status": "FIXED|STILL_PRESENT|CANNOT_VERIFY",
      "evidence": "code snippet or explanation",
      "notes": "additional context"
    }
  ],
  "new_issues": [
    {
      "file_path": "string",
      "line_number": 42,
      "severity": "critical|warning|info",
      "category": "Security|Performance|Best Practice|Testing|Bug|Issue Alignment|Observability",
      "title": "brief issue title",
      "description": "detailed explanation",
      "original_code": "problematic code",
      "suggested_code": "improved code",
      "recommendation": "specific action"
    }
  ]
}
```
```

### Step 10: Process Review Results

Parse the JSON response and:
1. Count and categorize issues by severity
2. Count verification results (fixed, still present, cannot verify)
3. Display comprehensive summary

### Step 11: Ask User for Action

Present options:
```
What would you like to do?
1. Resolve fixed comments and post new comments (recommended)
2. Only resolve fixed comments
3. Only post new comments
4. Do nothing (review only)
```

### Step 12: Resolve Fixed Comments (if selected)

**For GitHub:**
```
Use MCP tool: mcp__github__create_review_comment_reply
- Add a reply with verification evidence
- Mark as resolved if API supports it
```

**For GitLab:**
```
Use MCP tool: mcp__gitlab__resolve_merge_request_discussion
Parameters:
- Project: {group/project}
- Merge request IID: {MR_ID}
- Discussion ID: {discussion_id}
- Resolved: true
```

### Step 13: Test Case Generation

Before posting comments, generate test cases based on the review findings and diff.

**Step 13a: Ask User**

```
Would you like me to generate test cases for this PR/MR?
1. Yes - Generate test cases
2. No - Skip and proceed to posting comments
```

**Step 13b: Generate Test Cases Directly**

If Yes, generate test cases yourself by combining ALL three sources:

1. **Issue tracker requirements (Step 6)** — acceptance criteria, business rules, and edge cases defined in the Linear/Jira issue and its comments. Each acceptance criterion should map to at least one TC.
2. **Code changes (Steps 4–5)** — new or modified behavior, logic branches, and changed business flows from the git diff.
3. **Review findings (Step 10 `new_issues`)** — bugs and logic issues found during review are high-priority TC targets.

**Output Format:**
| TC-ID | Title | Type | Source | Steps | Expected Result |
|---|---|---|---|---|---|
| TC-001 | {short title} | Positive/Negative/Edge | AC/Diff/Review | {numbered steps} | {expected outcome} |

The `Source` column should reference:
- `AC-{n}` — derived from acceptance criterion n in the issue
- `Diff` — derived from code change behavior
- `Review` — derived from a review finding

Keep test cases short and actionable. Cover:
- ✅ Happy path for each acceptance criterion and new feature/behavior
- ❌ Key invalid input, unauthorized access, or business rule violation
- ⚠️ One or two boundary/edge cases if relevant

Do NOT generate exhaustive or deeply nested test cases. Aim for 5–15 total TCs.

**Step 13c: Ask User for TC Destination**

```
Where would you like to save the test cases?
1. Post as a PR/MR comment
2. Output here only (no posting)
```

If option 1 is chosen:
- **GitHub**: Use `mcp__github__create_issue_comment` with the TC table as markdown
- **GitLab**: Use `mcp__gitlab__create_merge_request_note` with the TC table as markdown

### Step 14: Post New Review Comments

**Priority:** Always try inline comments first, fallback to general comments.

**For GitHub:**

Attempt inline first:
```
Use MCP tool: mcp__github__create_review_comment
Parameters:
- Owner, Repo, Pull number
- Body: formatted markdown with severity emoji, category, code snippets
- Commit ID: head SHA
- Path: file path
- Line: line number
- Side: "RIGHT"
```

If inline fails, fallback:
```
Use MCP tool: mcp__github__create_issue_comment
Parameters:
- Owner, Repo, Issue number (same as PR number)
- Body: formatted markdown with location info prepended: "**📍 Location:** `{file_path}` line **{line_number}**"
```

**For GitLab:**

**IMPORTANT:** Post each inline code comment as a separate discussion. Do NOT group them under one threaded discussion.

For each new issue:

1. **Attempt inline comment first:**
```
Use MCP tool: mcp__gitlab__create_merge_request_discussion
Parameters:
- Project: {group/project}
- Merge request IID: {MR_ID}
- Body: formatted markdown with severity, category, code snippets
- Position:
  - base_sha: base commit SHA
  - start_sha: start commit SHA
  - head_sha: head commit SHA
  - old_path: file path (if renamed, else same as new_path)
  - new_path: file path
  - new_line: line number  ← must be a line added (+) in the diff
```

2. **If inline fails (invalid position, line changed, etc.), post to general thread:**
```
Use MCP tool: mcp__gitlab__create_merge_request_note
Parameters:
- Project: {group/project}
- Merge request IID: {MR_ID}
- Body: formatted markdown including location: "**📍 Location:** `{file_path}:{line_number}`\n\n{rest of comment}"
```

**CRITICAL:**
- Each issue gets its OWN separate comment/discussion
- Do NOT reply to previous discussions unless resolving existing comments
- Do NOT batch multiple issues into one comment
- Each call creates a new top-level discussion/note

### Step 15: Cleanup and Final Summary Report

After review is complete:

```bash
# Return to original directory
cd -

# Optionally clean up the cloned repo if it was temporary
# (Ask user if they want to keep the clone)
```

Provide comprehensive summary:

```
## Code Review Complete

**Repository:** {owner/repo or group/project}
**PR/MR:** #{number} - {title}
**Issue:** {ISSUE_ID} - {title}
**Branch:** {source_branch} -> {target_branch}

### Existing Review Comments Status
- Total: {count}
- Fixed & Resolved: {count}
- Still Present: {count}
- Cannot Verify: {count}

### New Issues Identified
- Total Files Reviewed: {count}
- Critical Issues: {count}
- Warnings: {count}
- Suggestions: {count}

### By Category
- Security: {count}
- Performance: {count}
- Best Practice: {count}
- Testing: {count}
- Bug: {count}
- Issue Alignment: {count}
- Observability: {count}

### Comments Posted
- Inline comments: {count}
- General comments: {count}
- Failed: {count}

### Test Cases Generated
- Total: {total_tc_count}
- Positive: {positive_count}
- Negative: {negative_count}
- Edge Cases: {edge_count}

### Next Steps
1. Address {critical_count} critical issues before merging
2. Review {warning_count} warnings for code quality
3. Consider {info_count} suggestions for improvements
4. Execute {total_tc_count} generated test cases before merging
5. Update issue status if requirements are met

### Links
- View PR/MR: {URL}
- View Issue: {URL}
- Local Repository: {REPO_PATH}
```

## Error Handling

**Repository Access Errors:**
- Clone fails: Check URL, credentials, network
- Fetch fails: Check branch exists, permissions

**MCP Tool Errors:**
- Server not connected: Inform user to configure MCP
- Permission denied: Check API tokens, scopes
- Rate limiting: Wait and retry

**Git Errors:**
- Branch not found: Verify PR/MR number
- Merge conflicts: Inform user, don't attempt resolution
- Detached HEAD: Safe to continue for review

**Comment Posting Errors:**
- Invalid position: Retry as general comment
- Duplicate: Skip and note
- API errors: Log and continue

## Notes

**Directory Structure:**
- All repositories cloned to: `$HOME/code/{repo-name}`
- This keeps everything organized and accessible
- User can navigate to repos after review

**Supported Platforms:**
- GitHub (with GitHub MCP)
- GitLab (with GitLab MCP)

**Supported Issue Trackers:**
- Linear (with Linear MCP)
- Jira (with Jira MCP)

**MCP Integration:**
- Check available tools with: `/mcp inspect {server-name}`
- Verify servers are connected before starting
- Handle different MCP implementations gracefully

**Security:**
- Never commit temporary files
- Don't expose API tokens in output
- Sanitize URLs in error messages
