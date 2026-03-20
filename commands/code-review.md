@"
---
argument-hint: [PR_OR_MR_URL] [LINEAR_OR_JIRA_ISSUE_ID]
description: Review GitHub PR or GitLab MR with Linear or Jira issue context, post threaded feedback, and generate test cases
---

# Code Review: GitHub PR / GitLab MR

You will review a Pull Request (GitHub) or Merge Request (GitLab) in the context of a Linear or Jira issue, performing a comprehensive code review and posting findings as threaded discussions.

## Arguments Provided
- **PR/MR**: $1 (URL — GitHub or GitLab)
- **Issue**: $2 (Linear ID e.g. ENG-123, or Jira key e.g. PROJ-123)

---

## Step 0: Detect Platform

Parse $1 to determine the platform:

- If URL contains `github.com` → **Platform: GitHub**, use GitHub MCP tools
- If URL contains `gitlab.com` or a self-hosted GitLab domain → **Platform: GitLab**, use GitLab MCP tools

Parse $2 to determine the issue tracker:

- If a Jira MCP server is connected AND $2 matches a Jira key pattern (e.g. `ABC-123`) → **Issue Tracker: Jira**
- If a Linear MCP server is connected AND $2 matches a Linear ID pattern (e.g. `ENG-123`) → **Issue Tracker: Linear**
- If both servers are connected, ask the user which tracker $2 belongs to
- **Note:** Issue tracker is independent of the git platform — GitHub+Jira and GitLab+Linear are fully supported

Store as variables for use in all subsequent steps:
- `PLATFORM` = `github` or `gitlab`
- `ISSUE_TRACKER` = `linear` or `jira`

## Prerequisites Check

Use the `/mcp list` command to verify required MCP servers are connected:

**Git platform MCP** (one of):
- GitHub MCP Server (`mcp__github__*`)
- GitLab MCP Server (`mcp__gitlab__*`)

**Issue tracker MCP** (one of):
- Linear MCP Server (`mcp__linear__*` or similar)
- Jira MCP Server (`mcp__jira__*` or `mcp__atlassian__*`)

Any combination is valid: GitHub+Linear, GitHub+Jira, GitLab+Linear, GitLab+Jira.

If a required MCP server is missing, inform the user:
```
❌ Required MCP servers not found for {PLATFORM} + {ISSUE_TRACKER}.

Please ensure the following MCP servers are configured in your Claude Code settings:
- {Git platform} MCP Server — for PR/MR operations
- {Issue tracker} MCP Server — for issue details

Refer to: https://docs.claude.com/en/docs/claude-code/mcp
```

---

## Step 1: Extract PR/MR Information

**If GitHub:**
Parse `https://github.com/{owner}/{repo}/pull/{number}` to extract:
- `OWNER` = repository owner
- `REPO` = repository name
- `PR_NUMBER` = pull request number

**If GitLab:**
Parse `https://gitlab.com/{project_path}/-/merge_requests/{iid}` to extract:
- `PROJECT_PATH` = full project path (e.g. `namespace/project`)
- `MR_IID` = merge request internal ID

If a numeric ID is provided without a URL, ask the user for the repository/project path.

---

## Step 2: Fetch Issue Details

**IMPORTANT: Use MCP tools exclusively. DO NOT use WebFetch, curl, or direct URL access.**

**Step 2a: Discover Available MCP Tools**

Run `/mcp list` to get the exact server name/prefix, then `/mcp inspect <server-name>` to see available tools.

**Step 2b: Fetch Issue via MCP**

*If Linear:*
```
Use MCP tool: mcp__linear__get_issue (or check exact name with /mcp inspect)
Parameters:
- Issue ID: $2 (e.g. ENG-123)
- Include: title, description, state, priority, labels, assignee, project, estimate
```

*If Jira:*
```
Use MCP tool: mcp__jira__get_issue (or mcp__atlassian__get_issue — check /mcp inspect)
Parameters:
- Issue key: $2 (e.g. PROJ-123)
- Fields: summary, description, issuetype, priority, status, acceptance criteria, all custom fields
```

**Step 2c: Fetch Comments via MCP**

*If Linear:*
```
Use MCP tool: mcp__linear__list_comments (or check /mcp inspect)
- Issue ID: $2
```

*If Jira:*
```
Use MCP tool: mcp__jira__get_comments (or check /mcp inspect)
- Issue key: $2
```

Comments may be included in the issue response — check for a `comments` field if no dedicated tool exists.

**Step 2d: Extract and Store Context**

Extract from the response:
- Issue title/summary
- Description
- Acceptance criteria (Jira: custom field or description; Linear: description)
- Status/State
- Priority
- Labels / Issue type
- Assignee, Project
- All comments with author and timestamp

Store this context for the review — used to validate alignment with requirements.

**If MCP call fails:**
- Verify the issue key format is correct
- Check permissions
- DO NOT fall back to direct API/URL — inform the user to fix MCP configuration

---

## Step 3: Fetch PR/MR Details

**If GitHub:**
```
Use MCP tool: mcp__github__get_pull_request
Parameters:
- Owner: {OWNER}
- Repo: {REPO}
- Pull number: {PR_NUMBER}
```

Extract:
- PR title, description/body
- Head branch (source), base branch (target)
- Author, state (open/closed/merged)
- HTML URL
- `base.sha` and `head.sha` (needed for inline comments)

**If GitLab:**
```
Use MCP tool: mcp__gitlab__get_merge_request
Parameters:
- Merge request identifier: {PROJECT_PATH}!{MR_IID} or as required by your MCP config
```

Extract:
- MR title, description
- Source branch, target branch
- Author, status
- Web URL
- `diff_refs.base_sha`, `diff_refs.start_sha`, `diff_refs.head_sha` (needed for inline comments)

---

## Step 4: Fetch Diff

**If GitHub:**
```
Use MCP tool: mcp__github__get_pull_request_files (or list_pull_request_files)
Parameters:
- Owner: {OWNER}
- Repo: {REPO}
- Pull number: {PR_NUMBER}
```

**If GitLab:**
```
Use MCP tool: mcp__gitlab__list_merge_request_diffs
Parameters:
- Merge request identifier: same as Step 3
```

Parse and organize changes by file:
```
File: path/to/file.rb
Status: modified (added/removed/renamed)
Lines changed: 42-56, 89-102

Diff:
[Full diff content with line numbers and context]
```

Preserve exact line numbers — used in Step 8 for inline comments.

---

## Step 4b: Fetch Existing Comments / Discussions

Fetch existing comments before reviewing to avoid duplicates and check if prior issues were fixed.

**If GitHub:**
```
Use MCP tool: mcp__github__list_review_comments
Parameters:
- Owner: {OWNER}
- Repo: {REPO}
- Pull number: {PR_NUMBER}
```

**If GitLab:**
```
Use MCP tool: mcp__gitlab__discussion_list
Parameters:
- Merge request identifier: same as Step 3
```

**Step 4b.2: Parse and Categorize**

For each comment/discussion:
1. Extract ID and resolved status
2. Check if bot-generated (contains "🤖 Automated review by Claude Code")
3. Extract: file path, line number, severity, category, description

**Step 4b.3: Store Context**

```json
[
  {
    "comment_id": "abc123",
    "resolved": false,
    "file_path": "path/to/file.rb",
    "line_number": 42,
    "severity": "critical",
    "category": "Security",
    "description": "Issue description",
    "is_inline": true
  }
]
```

Display summary:
```
Found {count} existing comments on this PR/MR:
- Resolved: {resolved_count}
- Open: {open_count}
  - Inline: {inline_count}
  - General: {general_count}
```

---

## Step 5: Launch Code Review Agent

Use the Task tool to launch the fullstack-code-reviewer agent with the following prompt.

**Cache Control:** Structure the prompt with `cache_control: {"type": "ephemeral"}` breakpoints at the end of each large static block (issue context, PR/MR details, existing comments, diff). This enables prompt caching to reduce token costs on large PRs or re-reviews.

```
You are reviewing a {GitHub Pull Request / GitLab Merge Request} in the context of a {Linear / Jira} issue.

**Issue Context ({Linear / Jira}):**        ← cache_control: {"type": "ephemeral"} after this block
{Insert issue details from Step 2:
- Issue ID/key, title/summary, description
- Status, priority, issue type
- Acceptance criteria
- All custom fields
- All comments with authors and timestamps}

**PR/MR Details:**                          ← cache_control: {"type": "ephemeral"} after this block
{Insert details from Step 3}

**Existing Comments/Discussions (From Step 4b):**  ← cache_control: {"type": "ephemeral"} after this block
{Insert structured list from Step 4b}

**Your Task:**
You have TWO primary objectives:

**OBJECTIVE 1: Verify Existing Comments**
For each existing comment provided above, check if the issue is still present:
1. Locate the file and line mentioned
2. Analyze if the issue is still present
3. Determine status:
   - "FIXED" - Issue has been resolved
   - "STILL_PRESENT" - Issue remains in the code
   - "CANNOT_VERIFY" - Cannot determine (file removed, line changed significantly, etc.)
4. Provide evidence (code snippet)

**OBJECTIVE 2: Find New Issues**
Review code changes line by line. For each file, analyze:
1. Security vulnerabilities
2. Performance issues (N+1 queries, missing indexes)
3. DRY principle violations
4. Clean Code standard violations
5. Missing or inadequate tests
6. Logic errors or bugs
7. Alignment with issue requirements
8. Consideration of discussion points from issue comments
9. **Observability & Troubleshooting**:
   - Missing logs on critical paths, state transitions, business events
   - Log quality: correlation/trace IDs, user identifiers, structured fields, no sensitive data
   - Log levels: debug/info/warn/error used correctly
   - Traceability: consistent trace/correlation ID through async calls and service boundaries
   - Error reporting (Sentry/Datadog/Rollbar): exceptions not swallowed, capture_exception called with context, business errors NOT sent
   - Avoid double logging across layers
   - No log statements in tight loops (flag for rate-limiting/sampling)
   - No PII, credentials, tokens, or payment data in logs

**Changed Files:**                          ← cache_control: {"type": "ephemeral"} after this block
{Insert organized file changes from Step 4}

**Important Instructions:**
- Review EACH file separately
- For EACH issue found, provide:
  - File path and line numbers affected
  - Severity: Critical (🔴), Warning (🟡), or Info (🟢)
  - Category: Security | Performance | Best Practice | Testing | Bug | Issue Alignment | Observability
  - Description: Clear explanation
  - Recommendation: Specific actionable fix with code example
  - Original code snippet
  - Suggested code snippet
- Use exact file paths and line numbers from the diff

**Output Format — valid JSON:**
```json
{
  "existing_comments_verification": [
    {
      "comment_id": "abc123",
      "file_path": "path/to/file.rb",
      "line_number": 42,
      "status": "FIXED|STILL_PRESENT|CANNOT_VERIFY",
      "evidence": "Code snippet or explanation",
      "notes": "Additional context"
    }
  ],
  "new_issues": [
    {
      "file_path": "path/to/file.rb",
      "line_number": 42,
      "severity": "critical|warning|info",
      "category": "Security|Performance|Best Practice|Testing|Bug|Issue Alignment|Observability",
      "title": "Brief issue title",
      "description": "Detailed explanation",
      "original_code": "problematic code snippet",
      "suggested_code": "improved code snippet",
      "recommendation": "Specific action to take"
    }
  ]
}
```
```

---

## Step 6: Process Review Results

**Step 6a: Parse and Validate JSON**
1. Parse the JSON response — both `existing_comments_verification` and `new_issues`
2. Validate all required fields are present

**Step 6b: Existing Comments Verification Summary**
```
## Existing Comments Verification

✅ Fixed Issues: {fixed_count}
❌ Still Present: {still_present_count}
⚠️ Cannot Verify: {cannot_verify_count}
```

**Step 6c: New Issues Summary**
```
## New Issues Found

- Total files reviewed: {count}
- Critical (🔴): {count}
- Warnings (🟡): {count}
- Info (🟢): {count}
```

**Step 6d: Ask for User Confirmation**
```
What would you like to do?
1. Resolve fixed comments and post new comments (recommended)
2. Only resolve fixed comments
3. Only post new comments
4. Do nothing (review only)

Enter your choice (1-4):
```

---

## Step 6e: Resolve Fixed Comments

If user chooses option 1 or 2:

**Step 6e.1:** Filter `existing_comments_verification` for status `"FIXED"`.

**Step 6e.2: Resolve Each Fixed Comment**

*If GitHub:*
```
Use MCP tool: mcp__github__resolve_review_thread (or similar — check /mcp inspect)
Parameters:
- Owner: {OWNER}, Repo: {REPO}, Pull number: {PR_NUMBER}
- Comment ID: {from verification result}
```

Optionally reply before resolving:
```
Use MCP tool: mcp__github__create_review_comment_reply
Body:
  "✅ This issue has been verified as fixed.

  **Evidence:** {evidence}
  {notes}

  ---
  🤖 Verified and resolved by Claude Code"
```

*If GitLab:*
```
Use MCP tool: mcp__gitlab__discussion_add_note
Parameters:
- Merge request identifier, Discussion ID: {from verification result}
- Note: "✅ This issue has been verified as fixed.\n\n**Evidence:** {evidence}\n{notes}\n\n---\n🤖 Verified and resolved by Claude Code"

Then: mcp__gitlab__discussion_resolve
Parameters:
- Merge request identifier, Discussion ID, Resolved: true
```

**Step 6e.3: Track Progress**
```
Resolving Fixed Comments:
[✅] Comment #1 - Security issue in auth.rb:42
[❌] Comment #2 - Failed: Permission denied

Successfully resolved: {success_count} / {total_count}
```

---

## Step 7: Test Case Generation

Before posting comments, generate test cases based on the review findings and diff.

**Step 7a: Ask User**
```
Would you like me to generate test cases for this PR/MR?
1. Yes - Generate test cases
2. No - Skip and proceed to posting comments
```

**Step 7b: Generate Test Cases Directly**

Generate test cases yourself by combining ALL three sources:

1. **Issue tracker requirements (Step 2)** — acceptance criteria, business rules, and edge cases defined in the Linear/Jira issue and its comments. Each acceptance criterion should map to at least one TC.
2. **Code diff (Step 4)** — new or modified behavior, logic branches, and changed business flows.
3. **Review findings (Step 6 `new_issues`)** — bugs and logic issues found during review are high-priority TC targets.

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

**Step 7c: Ask User for TC Destination**
```
Where would you like to save the test cases?
1. Post as a comment on the PR/MR
2. Output here only (no posting)
```

If option 1 is chosen:

*If GitHub:*
```
Use MCP tool: mcp__github__create_issue_comment
Body: Formatted markdown table with all test cases
```

*If GitLab:*
```
Use MCP tool: mcp__gitlab__discussion_new
Body: Formatted markdown table with all test cases
(No position — general thread)
```

---

## Step 8: Post New Review Comments

If user chooses option 1 or 3 (post new comments), proceed.

**IMPORTANT:** Only post from `new_issues`. Do NOT re-post already-existing comments (even if `STILL_PRESENT`).

**Priority:**
1. **FIRST**: Inline comment on specific line
2. **SECOND**: General comment/thread (fallback if inline fails)

---

### If GitHub

**Step 8a: Inline Review Comment (First Priority)**

```
CRITICAL: Verify SHA values from Step 3 — base.sha and head.sha must not be null.
```

```
Use MCP tool: mcp__github__create_review_comment
Parameters:
- Owner: {OWNER}, Repo: {REPO}, Pull number: {PR_NUMBER}
- Commit ID: {head.sha}
- Path: {file_path}
- Line: {line_number}
- Side: "RIGHT" (new code) or "LEFT" (deleted code, rare)
- Body:
  "**{severity_emoji} {category}: {title}**

  {description}

  **Current Code:**
  ```
  {original_code}
  ```

  **Suggested Fix:**
  ```
  {suggested_code}
  ```

  **Recommendation:** {recommendation}

  ---
  🤖 Automated review by Claude Code"
```

**Step 8b: Fallback — General PR Comment**

Only if Step 8a fails:
```
Use MCP tool: mcp__github__create_issue_comment
Parameters:
- Owner: {OWNER}, Repo: {REPO}, Issue number: {PR_NUMBER}
- Body: same as above but prepend "**📍 Location:** `{file_path}` line **{line_number}**"
```

---

### If GitLab

**Step 8a: Inline Discussion Thread (First Priority)**

```
CRITICAL: Verify from Step 3 — diff_refs.base_sha, diff_refs.start_sha, diff_refs.head_sha must not be null.
Display: "Using SHAs — base: {base_sha}, start: {start_sha}, head: {head_sha}"
```

```
Use MCP tool: mcp__gitlab__discussion_new
Parameters:
- Merge request identifier: same as Step 3
- Body:
  "**{severity_emoji} {category}: {title}**

  {description}

  **Current Code:**
  ```
  {original_code}
  ```

  **Suggested Fix:**
  ```
  {suggested_code}
  ```

  **Recommendation:** {recommendation}

  ---
  🤖 Automated review by Claude Code"

- Position:
  - base_sha: {diff_refs.base_sha}
  - start_sha: {diff_refs.start_sha}
  - head_sha: {diff_refs.head_sha}
  - position_type: "text"
  - new_path: {file_path}
  - new_line: {line_number}  ← must be a line added (+) in the diff
```

**Step 8b: Fallback — General Discussion Thread**

Only if Step 8a fails:
```
Use MCP tool: mcp__gitlab__discussion_new
Same body but prepend "**📍 Location:** `{file_path}` line **{line_number}**"
Omit position parameter entirely (creates a general thread)
```

---

**Progress Tracking (both platforms):**

For each comment:
1. Log: "Posting inline comment {n}/{total} on {file_path}:{line_number}..."
2. If inline succeeds: "✅ Inline comment posted"
3. If inline fails: log full error → "⚠️ Inline failed: {error} — retrying as general..."
4. If general succeeds: "✅ General comment posted as fallback"
5. If both fail: "❌ Failed: {error}" — continue to next item

Track: inline_count / general_count / failed_count

**Severity Emoji Mapping:**
- Critical (🔴): red circle
- Warning (🟡): yellow circle
- Info (🟢): green circle

---

## Step 9: Comprehensive Summary Report

```
## {GitHub PR / GitLab MR} Review Complete ✅

**PR/MR:** {URL}
**Issue:** {Issue ID} - {Title}
**Platform:** {GitHub/GitLab} + {Linear/Jira}

### 📊 Existing Comments Status

Total: {total_existing}
- ✅ Fixed & Resolved: {fixed_count}
- ❌ Still Present: {still_present_count}
- ⚠️ Cannot Verify: {cannot_verify_count}
- 📌 Already Resolved: {already_resolved_count}

Resolution: {successful_resolutions} / {attempted_resolutions} succeeded

### 🆕 New Issues Identified

Files reviewed: {files_count}
Comments posted: {new_comments_posted} / {new_issues_found}
- Inline: {inline_count}
- General: {general_count}
- Failed: {failed_count}

By Severity:
- Critical (🔴): {critical_count}
- Warnings (🟡): {warning_count}
- Suggestions (🟢): {info_count}

By Category:
- Security: {n}
- Performance: {n}
- Best Practice: {n}
- Testing: {n}
- Bug: {n}
- Issue Alignment: {n}
- Observability: {n}

### 📋 Next Steps

1. Address {critical_count} critical issue(s) before merging
2. Review {warning_count} warning(s) for code quality
3. Consider {info_count} suggestion(s)
4. Update {Linear/Jira} issue status if all acceptance criteria are met
5. Manually verify {cannot_verify_count} comment(s) that couldn't be auto-verified

### 💰 Cost Estimation

Cost Estimation (Claude Sonnet 4.6 pricing):
- Input: $3.00 / 1M tokens
- Output: $15.00 / 1M tokens
- Estimated cost = (input_tokens / 1M × $3) + (output_tokens / 1M × $15)
(Assume ~70:30 input:output ratio if breakdown unavailable)

### 🔗 Links

- PR/MR: {URL}
- PR/MR Comments: {URL}/files (GitHub) or {URL}#notes (GitLab)
- Issue: {Linear or Jira issue URL}

---
🤖 Automated review completed by Claude Code
```

---

## Error Handling

**Setup Errors:**
- MCP server not connected → inform user, stop
- Invalid PR/MR URL → validate format before proceeding
- Issue not found → verify key format and permissions
- Permission errors → log and inform user

**Step 4b Errors:**
- Failed to fetch comments → log and continue (skip existing comment checks)
- Malformed comment data → skip that comment, continue
- No comments → normal for new PRs/MRs

**Step 5 Errors:**
- MCP tool failure → check error, suggest fix
- Invalid diff format → handle gracefully
- Agent returns invalid JSON → ask agent to retry

**Step 6e Errors:**
- Failed to resolve → log with ID, continue with others
- Failed to add note → non-critical, attempt resolution anyway

**Step 8 Errors:**
- Inline position invalid → retry as general comment
- Invalid line number → fallback to general with file/line in body
- Rate limiting → wait briefly and retry
- Duplicate comment → skip

**General Strategy:**
1. Log error with context (step, platform, ID)
2. Guide user on resolution
3. Continue remaining operations when possible
4. Include error summary in final report

---

## MCP Tool Reference

**GitHub MCP:**
- `get_pull_request` — fetch PR details
- `get_pull_request_files` / `list_pull_request_files` — get diff
- `list_review_comments` — list review comments (Step 4b)
- `create_review_comment` — inline comment (Step 8a)
- `create_issue_comment` — general comment (Step 8b / TC posting)
- `create_review_comment_reply` — reply to thread (Step 6e)
- `resolve_review_thread` — resolve thread (Step 6e)

**GitLab MCP:**
- `get_merge_request` — fetch MR details
- `list_merge_request_diffs` — get diff
- `discussion_list` — list discussions (Step 4b)
- `discussion_new` — create inline or general discussion (Steps 8a/8b, TC posting)
- `discussion_add_note` — reply to discussion (Step 6e)
- `discussion_resolve` — resolve discussion (Step 6e)

**Linear MCP:**
- `get_issue` / `issue` — fetch issue details
- `list_comments` — fetch comments
- Check exact tool names with `/mcp inspect <linear-server-name>`

**Jira MCP (JIRA Base URL: https://ioh-smb.atlassian.net/):**
- `get_issue` / `search_issues` — fetch issue details
- `get_comments` / `list_comments` — fetch comments
- Check exact tool names with `/mcp inspect <jira-server-name>`

**General Notes:**
- The fullstack-code-reviewer agent has access to: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash
- MCP tools handle auth automatically (configured in MCP settings)
- Use `/mcp list` to see connected servers and prefixes
- Use `/mcp inspect <server-name>` to see available tools and parameters
