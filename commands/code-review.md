---
argument-hint: [PR_OR_MR_URL] [LINEAR_OR_JIRA_ISSUE_ID]
description: Review GitHub PR or GitLab MR with Linear or Jira issue context, post threaded feedback, and generate test cases
---

# Code Review: GitHub PR / GitLab MR

You will review a Pull Request (GitHub) or Merge Request (GitLab) in the context of a Linear or Jira issue, performing a comprehensive code review and posting findings as threaded discussions.

## Arguments Provided
- **PR/MR**: $ARGUMENTS (URL — GitHub or GitLab, optionally followed by issue ID)

---

## CI Mode Detection

Determine if running interactively or in CI:

- **CI Mode** (non-interactive): when invoked via `claude -p` in a pipeline
  - Skip ALL user prompts — auto-select recommended defaults
  - Step 11: Auto-select option 1 (resolve fixed comments + post new comments)
  - Step 13: Skip test case generation entirely
  - Do NOT ask for confirmation — proceed automatically
  - If no issue ID provided, skip issue tracker steps (Step 6)

- **Interactive Mode** (default): when invoked from the CLI or IDE
  - Present all prompts and wait for user input
  - Full workflow including test case generation

---

## Step 1: Parse Request and Identify Platform

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
- If both servers are connected, ask the user which tracker the issue belongs to (interactive only)
- GitHub+Jira, GitLab+Linear, GitHub+Linear, GitLab+Jira — all supported

If short form is used, ask the user for the repository details (interactive only). In CI mode, fail with an error.

### Prerequisites Check

Verify required MCP servers are connected:

**Git platform MCP** (one of):
- GitHub MCP Server (`mcp__github__*`)
- GitLab MCP Server (`mcp__gitlab__*`)

**Issue tracker MCP** (optional, one of):
- Linear MCP Server (`mcp__linear__*` or similar)
- Jira MCP Server (`mcp__jira__*` or `mcp__atlassian__*`)

If the git platform MCP server is missing, inform the user and stop.

---

## Step 2: Check if Repository Exists Locally

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

mkdir -p "$HOME/code/code-reviews"
git clone "$REPO_URL" "$REPO_PATH"
cd "$REPO_PATH"
```

**For GitLab:**
```bash
REPO_URL="https://gitlab.com/{group}/{project}.git"
REPO_PATH="$HOME/code/code-reviews/{project}"

mkdir -p "$HOME/code/code-reviews"
git clone "$REPO_URL" "$REPO_PATH"
cd "$REPO_PATH"
```

### Step 4: Fetch PR/MR Branch

**For GitHub:**
```bash
git fetch origin pull/{PR_NUMBER}/head:pr-{PR_NUMBER}
git checkout pr-{PR_NUMBER}
git fetch origin main:main 2>/dev/null || git fetch origin master:master
```

**For GitLab:**
```bash
git fetch origin
SOURCE_BRANCH="{source-branch-name}"
git checkout "$SOURCE_BRANCH"
git fetch origin main:main 2>/dev/null || git fetch origin master:master
```

---

## Step 5: Get Code Changes

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

---

## Step 6: Fetch Issue Tracker Details (skip if no issue ID provided)

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

---

## Step 7: Fetch PR/MR Details

**For GitHub:**
```
Use MCP tool: mcp__github__get_pull_request
Parameters:
- Owner: {owner}
- Repo: {repo}
- Pull number: {PR_NUMBER}
```

Extract: title, description, head/base branches, author, state, `base.sha`, `head.sha`

**For GitLab:**
```
Use MCP tool: mcp__gitlab__get_merge_request
Parameters:
- Project: {group/project}
- Merge request IID: {MR_ID}
```

Extract: title, description, source/target branches, author, status, `diff_refs.base_sha`, `diff_refs.start_sha`, `diff_refs.head_sha`

---

## Step 8: Fetch Existing Review Comments

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
Use MCP tool: mcp__gitlab__discussion_list
Parameters:
- Merge request identifier: same as Step 7
```

Parse existing comments to avoid duplicates and check for resolved issues.

---

## Step 9: Launch Code Review Agent

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

---

## Step 10: Process Review Results

Parse the JSON response and:
1. Count and categorize issues by severity
2. Count verification results (fixed, still present, cannot verify)
3. Display comprehensive summary

---

## Step 11: Ask User for Action (Interactive Mode Only)

In **CI mode**: auto-select option 1 and proceed immediately.

In **Interactive mode**, present options:
```
What would you like to do?
1. Resolve fixed comments and post new comments (recommended)
2. Only resolve fixed comments
3. Only post new comments
4. Do nothing (review only)
```

---

## Step 12: Resolve Fixed Comments (if selected)

**For GitHub:**
```
Use MCP tool: mcp__github__create_review_comment_reply
- Add a reply with verification evidence
- Mark as resolved if API supports it
```

**For GitLab:**
```
Use MCP tool: mcp__gitlab__discussion_add_note
Parameters:
- Merge request identifier, Discussion ID
- Note: "✅ This issue has been verified as fixed.\n\n**Evidence:** {evidence}\n\n---\n🤖 Verified and resolved by Claude Code"

Then: mcp__gitlab__discussion_resolve
Parameters:
- Merge request identifier, Discussion ID, Resolved: true
```

---

## Step 13: Test Case Generation (Interactive Mode Only)

In **CI mode**: skip this step entirely and proceed to Step 14.

**Step 13a: Ask User**

```
Would you like me to generate test cases for this PR/MR?
1. Yes - Generate test cases
2. No - Skip and proceed to posting comments
```

**Step 13b: Generate Test Cases Directly**

If Yes, generate test cases yourself by combining ALL three sources:

1. **Issue tracker requirements (Step 6)** — acceptance criteria, business rules, and edge cases defined in the Linear/Jira issue and its comments. Each acceptance criterion should map to at least one TC.
2. **Code changes (Steps 4-5)** — new or modified behavior, logic branches, and changed business flows from the git diff.
3. **Review findings (Step 10 `new_issues`)** — bugs and logic issues found during review are high-priority TC targets.

**Output Format:**
| TC-ID | Title | Type | Source | Steps | Expected Result |
|---|---|---|---|---|---|
| TC-001 | {short title} | Positive/Negative/Edge | AC/Diff/Review | {numbered steps} | {expected outcome} |

Keep test cases short and actionable. Aim for 5-15 total TCs.

**Step 13c: Ask User for TC Destination**

```
Where would you like to save the test cases?
1. Post as a PR/MR comment
2. Output here only (no posting)
```

If option 1 is chosen:
- **GitHub**: Use `mcp__github__create_issue_comment` with the TC table as markdown
- **GitLab**: Use `mcp__gitlab__discussion_new` with the TC table as markdown (no position — general thread)

---

## Step 14: Post New Review Comments

If option 1 or 3 is selected (or CI mode), proceed.

**IMPORTANT:** Only post from `new_issues`. Do NOT re-post already-existing comments (even if `STILL_PRESENT`).

**IMPORTANT:** Post each finding as a SEPARATE discussion/comment. Do NOT batch multiple findings into one thread.

**Priority:** Always try inline comments first, fallback to general comments.

### If GitHub

**Attempt inline first:**
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

**If inline fails, fallback:**
```
Use MCP tool: mcp__github__create_issue_comment
Parameters:
- Owner, Repo, Issue number (same as PR number)
- Body: formatted markdown with location info prepended: "**📍 Location:** `{file_path}` line **{line_number}**"
```

### If GitLab

**Attempt inline first:**
```
Use MCP tool: mcp__gitlab__discussion_new_with_position
Parameters:
- Merge request identifier
- Body: formatted markdown with severity, category, code snippets
- Position:
  - base_sha: from diff_refs.base_sha
  - start_sha: from diff_refs.start_sha
  - head_sha: from diff_refs.head_sha
  - position_type: "text"
  - new_path: file path
  - new_line: line number  ← must be a line added (+) in the diff
```

**If inline fails (invalid position, line changed, etc.), fallback:**
```
Use MCP tool: mcp__gitlab__discussion_new
Parameters:
- Merge request identifier
- Body: formatted markdown including location: "**📍 Location:** `{file_path}:{line_number}`\n\n{rest of comment}"
(No position — creates a general thread)
```

### Comment Body Format

```
**{severity_emoji} {category}: {title}**

{description}

**Current Code:**
```{language}
{original_code}
```

**Suggested Fix:**
```{language}
{suggested_code}
```

**Recommendation:** {recommendation}

---
🤖 Automated review by Claude Code
```

### Severity Emoji Mapping
- Critical (🔴): red circle
- Warning (🟡): yellow circle
- Info (🟢): green circle

### Progress Tracking

For each comment:
1. Log: "Posting inline comment {n}/{total} on {file_path}:{line_number}..."
2. If inline succeeds: "✅ Inline comment posted"
3. If inline fails: log full error → "⚠️ Inline failed: {error} — retrying as general..."
4. If general succeeds: "✅ General comment posted as fallback"
5. If both fail: "❌ Failed: {error}" — continue to next item

Track: inline_count / general_count / failed_count

**CRITICAL:**
- Each issue gets its OWN separate comment/discussion
- Do NOT reply to previous discussions unless resolving existing comments
- Do NOT batch multiple issues into one comment
- Each call creates a new top-level discussion/note

---

## Step 15: Final Summary Report

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

### Next Steps
1. Address {critical_count} critical issues before merging
2. Review {warning_count} warnings for code quality
3. Consider {info_count} suggestions for improvements
4. Update issue status if requirements are met

### Links
- View PR/MR: {URL}
- View Issue: {URL}
```

---

## Error Handling

**MCP Tool Errors:**
- Server not connected: Inform user to configure MCP
- Permission denied: Check API tokens, scopes
- Rate limiting: Wait and retry

**Comment Posting Errors:**
- Invalid position: Retry as general comment
- Duplicate: Skip and note
- API errors: Log and continue

**General Strategy:**
1. Log error with context (step, platform, ID)
2. Guide user on resolution (interactive) or log for CI output
3. Continue remaining operations when possible
4. Include error summary in final report

---

## MCP Tool Reference

**GitHub MCP:**
- `get_pull_request` — fetch PR details
- `get_pull_request_files` / `list_pull_request_files` — get diff
- `list_review_comments` — list review comments (Step 8)
- `create_review_comment` — inline comment (Step 14)
- `create_issue_comment` — general comment (Step 14 fallback)
- `create_review_comment_reply` — reply to thread (Step 12)
- `resolve_review_thread` — resolve thread (Step 12)

**GitLab MCP:**
- `get_merge_request` — fetch MR details
- `list_merge_request_diffs` — get diff
- `discussion_list` — list discussions (Step 8)
- `discussion_new` — create general discussion (Step 14 fallback)
- `discussion_new_with_position` — create inline discussion (Step 14)
- `discussion_add_note` — reply to discussion (Step 12)
- `discussion_resolve` — resolve discussion (Step 12)

**Linear MCP:**
- `get_issue` / `issue` — fetch issue details
- `list_comments` — fetch comments

**Jira MCP (JIRA Base URL: https://ioh-smb.atlassian.net/):**
- `get_issue` / `search_issues` — fetch issue details
- `get_comments` / `list_comments` — fetch comments

**General Notes:**
- The fullstack-code-reviewer agent has access to: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash
- MCP tools handle auth automatically (configured in MCP settings)
