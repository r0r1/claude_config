---
argument-hint: [PR_OR_MR_URL] [LINEAR_OR_JIRA_ISSUE_ID]
description: Review GitHub PR or GitLab MR with Linear or Jira issue context, post threaded feedback, and generate test cases
---

# Code Review: GitHub PR / GitLab MR

You will review a Pull Request (GitHub) or Merge Request (GitLab), performing a comprehensive code review and posting findings as threaded discussions.

**CRITICAL: You MUST use MCP tools for ALL GitLab/GitHub/Jira operations. NEVER use curl, Bash, git commands, or direct API calls. MCP servers are already configured and connected. Use `mcp__gitlab__*` tools for GitLab, `mcp__github__*` for GitHub, `mcp__atlassian__*` for Jira.**

## Arguments Provided
- **PR/MR**: $ARGUMENTS (URL — GitHub or GitLab, optionally followed by issue ID)

---

## CI Mode Detection

Determine if running interactively or in CI:

- **CI Mode** (non-interactive): when invoked via `claude -p` in a pipeline
  - Skip Steps 2-4 (repo cloning — CI runner already has the code)
  - Skip Step 6 (issue tracker) unless issue ID is provided
  - Skip Step 8 (existing comments verification — save turns)
  - Skip Step 9 subagent — review the code yourself directly
  - Skip Step 11 user prompt — auto-select option 1
  - Skip Step 13 (test case generation)
  - **PRIORITIZE posting findings over analysis** — if running low on turns, post what you have

- **Interactive Mode** (default): when invoked from the CLI or IDE
  - Full workflow including all steps

---

## Step 1: Parse URL and Fetch MR Details

Parse $ARGUMENTS to determine the platform:
- `github.com` → GitHub
- Any other domain → GitLab (self-hosted or gitlab.com)

Extract project path and MR/PR number from the URL.

**Fetch MR/PR details immediately (combine with diff in one step if possible):**

**If GitLab:**
```
Use MCP tool: mcp__gitlab__get_merge_request
→ Extract: title, description, diff_refs (base_sha, start_sha, head_sha)

Then immediately:
Use MCP tool: mcp__gitlab__list_merge_request_diffs
→ Extract: changed files with full diffs and line numbers
```

**If GitHub:**
```
Use MCP tool: mcp__github__get_pull_request
→ Extract: title, description, base.sha, head.sha

Then immediately:
Use MCP tool: mcp__github__get_pull_request_files
→ Extract: changed files with diffs
```

---

## Step 2: Check if Repository Exists Locally (Interactive Mode Only)

**CI Mode: SKIP this step entirely.**

Use the Bash tool to check if the repository exists locally. If not, clone it:
```bash
REPO_PATH="$HOME/code/code-reviews/{repo}"
if [ -d "$REPO_PATH" ]; then
  cd "$REPO_PATH" && git fetch origin
else
  mkdir -p "$HOME/code/code-reviews"
  git clone "{repo_url}" "$REPO_PATH"
  cd "$REPO_PATH"
fi
```

## Step 3: Fetch PR/MR Branch (Interactive Mode Only)

**CI Mode: SKIP this step entirely.**

Checkout the source branch locally for file reading.

## Step 4: Fetch Issue Details (skip if no issue ID provided)

If a second argument (issue ID) is provided:

**Jira:** `mcp__atlassian__get_issue` → extract summary, description, acceptance criteria
**Linear:** `mcp__linear__get_issue` → extract title, description, status

Store context for review alignment check.

---

## Step 5: Review the Code

Analyze every changed file from the diff against these criteria. **Do this yourself directly — do NOT launch a subagent in CI mode.**

### Review Criteria

1. **Security Vulnerabilities**
   - SQL injection, mass assignment, XSS, exposed secrets
   - Missing auth/authz checks, CSRF gaps

2. **Performance Issues**
   - N+1 queries — suggest `includes`/`preload`/`eager_load`
   - Missing indexes, inefficient queries, unbounded queries

3. **Bugs and Logic Errors**
   - Nil handling, race conditions, incorrect conditionals
   - Wrong method signatures, missing edge cases

4. **DRY Violations and Code Reuse**
   - Duplicated logic that should be extracted
   - Business logic in controllers (should be in models/services)
   - Custom code that could use existing gems

5. **Clean Code Standards**
   - Unclear names, SRP violations, long methods
   - Code smells: feature envy, data clumps

6. **Framework Best Practices**
   - Wrong layer usage (controller vs model vs service)
   - Missing model validations, misuse of callbacks

7. **Testing Gaps**
   - Missing tests for new/changed behavior
   - Critical paths without coverage

8. **Observability**
   - Missing logs on critical paths and state transitions
   - Log quality: trace IDs, structured fields, correct levels
   - Error reporting: exceptions not swallowed, Sentry/Rollbar usage
   - No PII/credentials in logs

9. **Issue Alignment** (if issue context available)
   - Changes match stated purpose
   - Acceptance criteria addressed

---

## Step 6: Post Each Finding as a SEPARATE Discussion

**CRITICAL: Post findings immediately as you identify them. Do NOT wait until you've reviewed everything — post as you go to avoid running out of turns.**

For EACH issue found, post it as its own discussion thread.

### Try Inline First (GitLab)

```
Use MCP tool: mcp__gitlab__discussion_new_with_position
Parameters:
- Merge request identifier: {project_path}!{mr_iid}
- Body: (format below)
- Position:
  - base_sha, start_sha, head_sha (from diff_refs)
  - position_type: "text"
  - new_path: file path
  - new_line: line number (must be a + line in the diff)
```

### Try Inline First (GitHub)

```
Use MCP tool: mcp__github__create_review_comment
Parameters:
- Owner, Repo, Pull number, Commit ID (head.sha)
- Path, Line, Side: "RIGHT"
- Body: (format below)
```

### Fallback to General Discussion

If inline fails (error about position/line), immediately retry without position:

**GitLab:** `mcp__gitlab__discussion_new` (no position param)
**GitHub:** `mcp__github__create_issue_comment`

Prepend body with: **📍 Location:** `{file_path}:{line_number}`

### Comment Body Format

```
**{severity_emoji} {Category}: {Title}**

{Description — explain WHY this is an issue}

**Current Code:**
```{language}
{original code}
```

**Suggested Fix:**
```{language}
{improved code}
```

**Recommendation:** {specific action}

---
🤖 Automated review by Claude Code
```

**Severity emojis:** Critical=🔴, Warning=🟡, Info=🟢

---

## Step 7: Post Summary

After posting all findings, create ONE general discussion (no position):

```
## 📊 Code Review Summary

**Reviewed by:** Claude Code (automated)

| # | Severity | Category | File | Line | Title |
|---|----------|----------|------|------|-------|
{one row per finding}

**Totals:** 🔴 {n} Critical, 🟡 {n} Warning, 🟢 {n} Info
**Comments:** {inline_count} inline, {general_count} general, {failed_count} failed

---
🤖 Automated review by Claude Code
```

If NO issues found:
```
## ✅ Code Review — No Issues Found

The changes look good. No security, performance, or code quality issues identified.
Files reviewed: {count}

---
🤖 Automated review by Claude Code
```

---

## Steps 8-15: Interactive Mode Only

The following steps are ONLY executed in interactive mode. In CI mode, stop after Step 7.

### Step 8: Fetch Existing Comments (Interactive Only)

Fetch existing discussions to check if prior issues were fixed.

**GitLab:** `mcp__gitlab__discussion_list`
**GitHub:** `mcp__github__list_review_comments`

### Step 9: Launch Code Review Agent (Interactive Only)

Use the Task tool to launch the fullstack-code-reviewer agent with comprehensive prompt including issue context, PR details, existing comments, and diffs.

The agent returns JSON with `existing_comments_verification` and `new_issues`.

### Step 10: Process Results (Interactive Only)

Parse JSON, count/categorize issues by severity.

### Step 11: User Action Selection (Interactive Only)

```
What would you like to do?
1. Resolve fixed comments and post new comments (recommended)
2. Only resolve fixed comments
3. Only post new comments
4. Do nothing (review only)
```

### Step 12: Resolve Fixed Comments (Interactive Only)

Reply to fixed comments with verification evidence, then resolve the discussion.

### Step 13: Test Case Generation (Interactive Only)

Generate test cases from: issue requirements, code changes, review findings.

### Step 14: Post Comments (Interactive Only)

Post new review comments (inline first, fallback to general).

### Step 15: Final Summary Report (Interactive Only)

Comprehensive report with existing comments status, new issues, categories, next steps.

---

## Error Handling

- **Inline position invalid** → retry as general comment immediately
- **MCP tool failure** → log error, continue to next finding
- **Rate limiting** → wait briefly and retry
- **Running low on turns** → post what you have, skip remaining analysis

---

## MCP Tool Reference

**GitLab MCP:**
- `get_merge_request` — fetch MR details + diff_refs
- `list_merge_request_diffs` — get changed files and diffs
- `discussion_list` — list existing discussions
- `discussion_new_with_position` — create inline discussion
- `discussion_new` — create general discussion (fallback)
- `discussion_add_note` — reply to discussion
- `discussion_resolve` — resolve discussion

**GitHub MCP:**
- `get_pull_request` — fetch PR details
- `get_pull_request_files` — get changed files
- `list_review_comments` — list review comments
- `create_review_comment` — inline comment
- `create_issue_comment` — general comment (fallback)

**Jira MCP:**
- `mcp__atlassian__get_issue` — fetch issue details

**Linear MCP:**
- `mcp__linear__get_issue` — fetch issue details
