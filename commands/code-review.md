@"
---
argument-hint: [PULL_REQUEST_URL_OR_NUMBER] [LINEAR_ISSUE_ID]
description: Review GitHub PR with Linear issue specification and post threaded feedback to GitHub
---

# Review GitHub PR with Linear Issue Specification

You will review a GitHub Pull Request in the context of a Linear issue, performing a comprehensive code review and posting findings as threaded discussions on GitHub.

## Arguments Provided
- **Pull Request**: $1 (URL or PR number)
- **Linear Issue**: $2 (Issue ID, e.g., ENG-123)

## Prerequisites Check

Before starting, verify that the required MCP servers are connected:

Use the `/mcp list` command to check for:
- **GitHub MCP Server** - For accessing GitHub API (pull requests, diffs, posting comments)
- **Linear MCP Server** - For fetching Linear issue details

If either MCP server is not connected, inform the user with instructions:
```
❌ Required MCP servers not found.

Please ensure you have the following MCP servers configured in your Claude Code settings:

1. **GitHub MCP Server**
   - Provides access to GitHub API for PR operations
   - Configuration: Add to your MCP settings with your GitHub token

2. **Linear MCP Server**
   - Provides access to Linear API for issue details
   - Configuration: Add to your MCP settings with your Linear API key

To configure MCP servers, refer to: https://docs.claude.com/en/docs/claude-code/mcp
```

List available MCP tools with: `Use the Bash tool to run: /mcp inspect <server-name>` to see what tools are available from each server.

## Step 1: Extract GitHub Repository and PR Information

Parse the pull request argument to extract:
- If URL provided: Extract owner, repo, and PR number from URL
  - Format: `https://github.com/{owner}/{repo}/pull/{number}`
- If numeric ID provided: Ask user for repository (e.g., "owner/repo")

Use the Bash tool to extract this information:
```bash
# Extract owner, repo, and PR number from URL or use provided values
```

## Step 2: Fetch Linear Issue Details

**IMPORTANT: You MUST use Linear MCP tools exclusively. DO NOT use WebFetch, Bash with curl, or access Linear URLs directly.**

**Step 2a: Discover Available Linear MCP Tools**

First, run `/mcp list` to verify the Linear MCP server is connected and get its exact name/prefix.

Then run `/mcp inspect <linear-server-name>` to see all available Linear tools and their parameters.

**Step 2b: Fetch Issue Details via MCP**

Use the Linear MCP server tool to fetch the issue details:

```
Use the MCP tool from Linear server (e.g., mcp__linear__get_issue or similar) with:
- Issue ID: $2 (e.g., ENG-123)
- Include all fields: title, description, state, priority, labels, assignee, project, etc.
```

Common Linear MCP tool patterns:
- `mcp__linear__get_issue` - Get a single issue by ID
- `mcp__linear__issue` - Some servers use this naming
- Check the actual tool name with `/mcp list` and `/mcp inspect`

**Step 2c: Fetch Linear Comments via MCP**

After fetching the issue details, fetch all comments on the issue:

```
Use the MCP tool from Linear server (e.g., mcp__linear__get_comments or mcp__linear__list_comments) with:
- Issue ID: $2 (e.g., ENG-123)
```

If there's no dedicated comments tool, comments may be included in the issue details response. Check the issue response for a `comments` field.

**Step 2d: Extract and Store Context**

Extract and summarize from the Linear MCP responses:
- Issue title
- Description
- Status/State
- Priority
- Labels
- Assignee
- Project
- Estimate (if set)
- Any relevant custom fields
- **All comments** with author and timestamp

Store this context for the code review. This will be used to validate that the PR changes align with the Linear issue requirements and consider any discussion points from comments.

**If Linear MCP tool call fails:**
- Check the error message carefully
- Verify the issue ID format is correct
- Ensure you have permissions to access the issue
- DO NOT fall back to API/URL methods - inform the user to check their MCP configuration

## Step 3: Fetch GitHub PR Details

Use the GitHub MCP server tool to fetch the pull request details:

```
Use MCP tool: mcp__github__get_pull_request (or check with /mcp list for exact prefix)
Parameters:
- Owner: {repository owner}
- Repo: {repository name}
- Pull number: {PR number}
```

The exact parameter format may vary. If needed, check `/mcp inspect github` to see parameter requirements.

Extract and display from the PR response:
- PR title
- Description/Body
- Head branch (source)
- Base branch (target/destination)
- Author
- State (open, closed, merged)
- HTML URL
- Base commit SHA and head commit SHA (needed for posting review comments on specific lines)

## Step 4: Fetch PR Changes (Diff)

Use the GitHub MCP server tool to fetch the detailed changes:

```
Use MCP tool: mcp__github__get_pull_request_files (or similar - check /mcp inspect)
Parameters:
- Owner: {repository owner}
- Repo: {repository name}
- Pull number: {PR number}
```

This will return a list of files changed in the pull request.

Parse the response to extract:
- All changed files (paths)
- Line-by-line diffs for each file showing additions (+) and deletions (-)
- Previous filename (for renamed/moved files)
- Patch content showing the diff with line numbers
- Status (added, modified, removed, renamed)

Organize the changes by file for systematic review. For each file, structure the diff in a readable format:
```
File: path/to/file.ts
Previous filename: path/to/old_file.ts (if renamed)
Status: modified
Lines changed: 42-56, 89-102

Diff:
[Full diff content with line numbers and context]
```

Make sure to preserve the exact line numbers from the diff, as these will be used in Step 7 to post inline comments.

## Step 4b: Fetch Existing Review Comments

Before reviewing the code, fetch all existing review comments on the PR to:
- Avoid duplicate comments on already-flagged issues
- Check if previously flagged issues have been fixed
- Resolve threads where issues are addressed

**Step 4b.1: List All Review Comments**

Use the GitHub MCP server tool to fetch all review comments:

```
Use MCP tool: mcp__github__list_review_comments (or similar - check /mcp inspect)
Parameters:
- Owner: {repository owner}
- Repo: {repository name}
- Pull number: {PR number}
```

**Step 4b.2: Parse and Categorize Review Comments**

For each review comment returned:
1. Extract the comment ID and any resolution/outdated status
2. Check if it's a bot-generated comment (contains "🤖 Automated review by Claude Code")
3. Parse the comment body to extract:
   - File path (from comment metadata)
   - Line number/position (from comment metadata)
   - Severity (🔴/🟡/🟢)
   - Category (Security, Performance, etc.)
   - Issue description
   - Original problematic code
   - Suggested fix

**Step 4b.3: Store Comment Context**

Create a structured list of existing review comments:
```json
[
  {
    "comment_id": 123456,
    "resolved": false,
    "file_path": "path/to/file.ts",
    "line_number": 42,
    "severity": "critical",
    "category": "Security",
    "description": "Issue description",
    "is_inline": true
  }
]
```

Display summary to user:
```
Found {count} existing review comments on this PR:
- Resolved/Outdated: {resolved_count}
- Active: {active_count}
  - Inline comments: {inline_count}
  - General comments: {general_count}
```

## Step 5: Launch Code Review Agent

Use the Task tool to launch the fullstack-code-reviewer agent with the following comprehensive prompt:

```
You are reviewing a GitHub Pull Request in the context of a Linear issue.

**Linear Issue Context:**
{Insert Linear issue details from Step 2, including:
- Issue ID, title, description
- Status/State, priority
- Labels, assignee, project
- Estimate (if set)
- All custom fields
- All comments with authors and timestamps}

**Pull Request Details:**
{Insert PR details from Step 3}

**Existing Review Comments (From Step 4b):**
{Insert list of existing review comments with their details}

**Your Task:**
You have TWO primary objectives:

**OBJECTIVE 1: Verify Existing Review Comments**
For each existing review comment provided above, check if the issue is still present in the current code:
1. Locate the file and line mentioned in the discussion
2. Analyze if the issue described is still present
3. Determine the verification status:
   - "FIXED" - The issue has been resolved
   - "STILL_PRESENT" - The issue remains in the code
   - "CANNOT_VERIFY" - Cannot determine (file removed, line changed significantly, etc.)
4. Provide evidence (code snippet showing it's fixed or still problematic)

**OBJECTIVE 2: Find New Issues**
Review the following code changes line by line. For each file, analyze:
1. Security vulnerabilities
2. Performance issues (especially N+1 queries, missing indexes)
3. DRY principle violations
4. Clean Code standard violations
5. Missing or inadequate tests
6. Logic errors or bugs
7. Alignment with Linear issue requirements
8. Consideration of discussion points from Linear comments
9. **Observability & Troubleshooting** — review all logging, error reporting, and traceability practices:
   - **Missing logs**: Are critical paths, state transitions, and business events logged? Entry/exit of important operations should be logged at appropriate levels (debug, info, warn, error).
   - **Log quality**: Do log messages include enough context to diagnose issues without reading code? Check for: correlation/trace IDs, user/request identifiers, relevant payload fields (avoid logging sensitive data like passwords/tokens), and structured fields (prefer structured/JSON logging over string concatenation).
   - **Log levels**: Are levels used correctly? (debug=dev detail, info=normal flow, warn=recoverable anomaly, error=requires attention, fatal=system cannot continue). Avoid logging errors for expected/business exceptions.
   - **Traceability**: Is there a consistent trace/correlation ID propagated through async calls, background jobs, and service boundaries? Without this, distributed debugging is nearly impossible.
   - **Error reporting to external tools (e.g. Sentry, Datadog, Rollbar)**: Are errors captured and sent to the error tracking tool? Check that: exceptions are not silently swallowed, `Sentry.capture_exception` (or equivalent) is called in rescue/catch blocks for unexpected errors, extra context (user, request, tags) is attached before capturing, and business/expected errors are NOT sent to Sentry (to reduce noise).
   - **Avoid double logging**: Don't log AND capture to Sentry for the same error in multiple layers — pick one consistent place per layer.
   - **Log rotation/volume**: Are there any log statements inside tight loops or high-frequency paths that could flood logs? Suggest rate-limiting or sampling if so.
   - **Sensitive data in logs**: Flag any log statement that may accidentally log PII, credentials, tokens, or payment data.

**Changed Files:**
{Insert organized file changes from Step 4}

**Important Instructions:**
- Review EACH file separately
- For EACH issue found, provide:
  - **File path** and **line numbers** affected
  - **Severity**: Critical (🔴), Warning (🟡), or Info (🟢)
  - **Category**: Security, Performance, Best Practice, Testing, Bug, Linear Alignment, or Observability
  - **Description**: Clear explanation of the issue
  - **Recommendation**: Specific, actionable fix with code example if applicable
  - **Original code snippet**: Show the problematic code
  - **Suggested code snippet**: Show the improved version

- Format each issue as a separate item that can be posted as a GitHub review comment
- Use the exact file path and line numbers from the diff
- If code aligns well with Linear issue requirements, mention this positively

**Output Format:**
Structure your response as a JSON object with two arrays:

```json
{
  "existing_comments_verification": [
    {
      "comment_id": 123456,
      "file_path": "path/to/file.ts",
      "line_number": 42,
      "status": "FIXED|STILL_PRESENT|CANNOT_VERIFY",
      "evidence": "Code snippet or explanation showing current state",
      "notes": "Additional context about the verification"
    }
  ],
  "new_issues": [
    {
      "file_path": "path/to/file.ts",
      "line_number": 42,
      "severity": "critical|warning|info",
      "category": "Security|Performance|Best Practice|Testing|Bug|Linear Alignment|Observability",
      "title": "Brief issue title",
      "description": "Detailed explanation",
      "original_code": "problematic code snippet",
      "suggested_code": "improved code snippet",
      "recommendation": "Specific action to take"
    }
  ]
}
```

Ensure the JSON is valid and can be parsed programmatically.
```

## Step 6: Process Review Results

After the fullstack-code-reviewer agent completes:

**Step 6a: Parse and Validate JSON Response**
1. Parse the JSON response containing both `existing_comments_verification` and `new_issues` arrays
2. Validate that all required fields are present

**Step 6b: Process Existing Comments Verification**

Count and categorize the verification results:
- Fixed: {count}
- Still Present: {count}
- Cannot Verify: {count}

Display summary:
```
## Existing Review Comments Verification

✅ Fixed Issues: {fixed_count}
   - These comments can be resolved

❌ Still Present: {still_present_count}
   - These issues still need attention

⚠️ Cannot Verify: {cannot_verify_count}
   - Manual verification needed
```

**Step 6c: Process New Issues**

Count new issues by severity:
- Critical (🔴): {count}
- Warnings (🟡): {count}
- Info (🟢): {count}

Display summary:
```
## New Issues Found

- Total files reviewed: {count}
- Critical issues (🔴): {count}
- Warnings (🟡): {count}
- Info/suggestions (🟢): {count}
```

**Step 6d: Ask for User Confirmation**

Ask the user with options:
```
What would you like to do?
1. Resolve fixed comments and post new comments (recommended)
2. Only resolve fixed comments
3. Only post new comments
4. Do nothing (review only)

Enter your choice (1-4):
```

## Step 6e: Resolve Fixed Review Comments

If user chooses option 1 or 2 (resolve fixed comments), proceed with resolving:

**Step 6e.1: Identify Comments to Resolve**

Filter the `existing_comments_verification` array for items with status "FIXED".

**Step 6e.2: Resolve Each Fixed Comment**

For each fixed comment:

```
Use MCP tool: mcp__github__resolve_review_thread (or similar - check /mcp inspect)
Parameters:
- Owner: {repository owner}
- Repo: {repository name}
- Pull number: {PR number}
- Comment ID: {from verification result}
```

Note: GitHub's review comment resolution may work differently than GitLab. Check the available MCP tools - you may need to:
- Reply to the comment thread indicating it's fixed
- Use a conversation resolution API if available
- Mark the thread as resolved (API support varies)

Optionally, add a reply to the comment before resolving:

```
Use MCP tool: mcp__github__create_review_comment_reply (or similar)
Parameters:
- Owner: {repository owner}
- Repo: {repository name}
- Pull number: {PR number}
- Comment ID: {from verification result}
- Body:
  "✅ This issue has been verified as fixed.

  **Evidence:**
  {evidence from verification result}

  {notes from verification result}

  ---
  🤖 Verified and resolved by Claude Code"
```

**Step 6e.3: Track Resolution Progress**

For each resolution attempt:
- Show progress: "Resolving comment {n} of {total}..."
- Handle errors gracefully:
  - If resolution fails (permissions, comment already resolved, etc.), log error and continue
  - If adding reply fails but resolution succeeds, that's acceptable
- Track successful and failed resolutions

Display progress:
```
Resolving Fixed Review Comments:
[✅] Comment #1 - Security issue in auth.ts:42
[✅] Comment #2 - Performance issue in query.ts:89
[❌] Comment #3 - Failed: Permission denied
...

Successfully resolved: {success_count} / {total_count}
```

## Step 7: Post New Review Comments to GitHub

If user chooses option 1 or 3 (post new comments), proceed with posting.

**IMPORTANT:** Only post comments from the `new_issues` array. Do NOT re-post issues that are already in existing review comments (even if status is "STILL_PRESENT").

**PRIORITY ORDER FOR POSTING COMMENTS:**
1. **FIRST PRIORITY**: Post as inline review comment on specific line
2. **SECOND PRIORITY**: Post as general PR comment (without position) only if inline fails

**Step 7a: Attempt Inline Review Comment (First Priority)**

For each review item in the `new_issues` JSON array, **ALWAYS ATTEMPT INLINE COMMENT FIRST**:

**CRITICAL: Before attempting inline comments, verify you have the correct commit SHA values:**
- From Step 3, you should have extracted: `base.sha` and `head.sha`
- Display these values to confirm: "Using SHAs - base: {base_sha}, head: {head_sha}"
- If these are missing or null, inline comments will fail

```
Use MCP tool: mcp__github__create_review_comment (or similar - check /mcp inspect)
Parameters:
- Owner: {repository owner}
- Repo: {repository name}
- Pull number: {PR number}
- Body (formatted as markdown):
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

- Commit ID: {head commit SHA from Step 3 PR details}
- Path: {file_path from review item - must match exact file path in diff}
- Line: {line_number from review item - the line number in the diff}
- Side: "RIGHT" (for new code) or "LEFT" (for old code, rare)
```

**IMPORTANT NOTES ABOUT LINE NUMBERS:**
- Line number must correspond to the position in the diff, not the absolute file line
- GitHub uses the diff position for review comments
- The line must be visible in the PR diff
- Use "RIGHT" side for commenting on new/modified code (most common)
- Use "LEFT" side only for commenting on deleted code

**Why inline comments are preferred:**
- They appear directly on the code line in the PR diff view
- Easier for developers to see exactly what needs to be fixed
- Better context and navigation in GitHub UI
- More professional and precise code review experience

**Step 7b: Fallback to General PR Comment (Second Priority)**

**ONLY if Step 7a fails** (position invalid, line doesn't exist, or API error), retry as a general PR comment:

```
Use MCP tool: mcp__github__create_issue_comment (or similar)
Parameters:
- Owner: {repository owner}
- Repo: {repository name}
- Issue number: {PR number} (PRs use the same API as issues for general comments)
- Body (formatted as markdown):
  "**{severity_emoji} {category}: {title}**

  **📍 Location:** `{file_path}` at line **{line_number}**

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

**Format Guidelines for General Threads:**
- Use the 📍 emoji to clearly mark the location information
- Make file path a code span (`file_path`) for readability
- Bold the line number for emphasis
- Include full context with current code and suggested fix
- Add the bot signature for consistent tracking

**Progress Tracking:**

For each posting attempt:
1. **Start with inline**: Log "Posting inline review comment {n} of {total} on {file_path}:{line_number}..."
   - Log the position parameters being used: "Position: commit={commit_id}, path={path}, line={line}, side={side}"
2. **If inline succeeds**: Log "✅ Inline review comment posted successfully" and move to next item
3. **If inline fails**:
   - Log the FULL error message: "⚠️ Inline posting failed with error: {full_error_message}"
   - Include the error code if available
   - Log "Retrying as general PR comment..."
4. **If general succeeds**: Log "✅ General PR comment posted as fallback"
5. **If both fail**: Log "❌ Failed to post comment: {error}" and continue with next item

Track separately:
- Successful inline review comments: {inline_count}
- Successful general PR comments (fallbacks): {general_count}
- Failed postings: {failed_count}

**Error Handling:**
- If inline position is invalid (line no longer exists), retry as general PR comment
- If comment creation fails completely, log the error and continue with next item
- Common errors:
  - Position invalid: Retry as general comment
  - Rate limiting: Wait briefly and retry
  - Duplicate content: Skip and note as duplicate
  - Permission errors: Log and inform user
  - Network errors: Retry once, then skip

**Severity Emoji Mapping:**
- Critical (🔴): Use red circle emoji
- Warning (🟡): Use yellow circle emoji
- Info (🟢): Use green circle emoji

## Step 8: Test Case Creation

After posting review comments, launch the qa-test-engineer agent to generate test cases for the changed code.

**Step 8a: Ask User for TC Creation**

Ask the user:
```
Would you like me to generate test cases for this PR?
1. Yes - Generate test cases (positive, negative, edge cases)
2. No - Skip test case creation
```

**Step 8b: Launch QA Test Engineer Agent**

If the user chooses Yes, use the Task tool to launch the qa-test-engineer agent with the following prompt:

```
You are creating comprehensive test cases for a Pull Request that has just been code-reviewed.

**PR/Issue Context:**
{Insert PR title, description, and Linear issue details from earlier steps}

**Changed Files & Logic:**
{Insert summary of what changed from the diff — focus on new behavior, modified logic, and business rules}

**Code Review Findings:**
{Insert the list of new_issues from the review — especially bugs and logic issues — so test cases can target those risk areas}

**Your Task:**
Generate comprehensive test cases covering ALL of the following categories:

### ✅ Positive Test Cases
- Happy path scenarios where inputs are valid and expected behavior occurs
- Each key user flow or feature path introduced/modified in this PR
- Verify expected outputs, state changes, UI feedback, and side effects

### ❌ Negative Test Cases
- Invalid inputs, missing required fields, malformed data
- Unauthorized access attempts (wrong role, unauthenticated)
- Business rule violations (e.g. duplicate entries, exceeded limits)
- API error responses (400, 401, 403, 404, 422, 500)

### ⚠️ Edge Cases
- Boundary values (min/max, empty strings, zero, null)
- Concurrent operations or race conditions if applicable
- Large data sets or pagination edge cases
- Locale/timezone edge cases if dates/times are involved
- Network interruption or timeout scenarios

### 🔍 Observability & Logging Test Cases
- Verify that errors are reported to Sentry (or equivalent) when failures occur
- Verify that trace/correlation IDs appear in logs for key operations
- Verify that sensitive data (passwords, tokens) does NOT appear in logs
- Verify correct log level is used (no errors logged for expected business exceptions)

**Output Format:**
For each test case provide:
- **TC-ID**: Sequential ID (TC-001, TC-002, ...)
- **Title**: Short descriptive name
- **Category**: Positive / Negative / Edge Case / Observability
- **Priority**: Critical / High / Medium / Low
- **Preconditions**: What must be true before running
- **Test Steps**: Numbered, executable steps
- **Expected Result**: What should happen
- **Test Data**: Any specific data required
```

**Step 8c: Display TC Summary**

After the agent completes, display:
```
## Test Cases Generated

| Category | Count |
|---|---|
| ✅ Positive | {count} |
| ❌ Negative | {count} |
| ⚠️ Edge Cases | {count} |
| 🔍 Observability | {count} |
| **Total** | **{total}** |

**Priority Breakdown:**
- Critical: {count}
- High: {count}
- Medium: {count}
- Low: {count}
```

**Step 8d: Ask User for TC Destination**

Ask the user:
```
Where would you like to save the test cases?
1. Post as a PR comment on GitHub (summary + link to full list)
2. Output here only (no posting)
3. Create Jira/Linear subtasks for each TC (if issue tracker MCP available)
```

If option 1 is chosen, post the full TC list as a general PR comment using:
```
Use MCP tool: mcp__github__create_issue_comment
Body: Formatted markdown with all test cases grouped by category
```

## Step 9: Comprehensive Summary Report

After all operations are complete, provide a comprehensive final summary:

```
## GitHub PR Review Complete ✅

**Pull Request:** {PR URL}
**Linear Issue:** {Linear Issue ID} - {Title}

### 📊 Existing Review Comments Status

**Total Existing Review Comments:** {total_existing_comments}
- ✅ Fixed & Resolved: {fixed_and_resolved_count}
- ❌ Still Present (needs attention): {still_present_count}
- ⚠️ Cannot Verify (manual check needed): {cannot_verify_count}
- 📌 Already Resolved (unchanged): {already_resolved_count}

**Resolution Actions:**
- Successfully resolved: {successful_resolutions} / {attempted_resolutions}
- Failed to resolve: {failed_resolutions}

### 🆕 New Issues Identified

**Total Files Reviewed:** {files_count}

**New Comments Posted:** {new_comments_posted} / {new_issues_found}
- Inline review comments: {inline_count}
- General PR comments: {general_count}
- Failed to post: {failed_count}

**By Severity:**
- Critical Issues (🔴): {critical_count}
- Warnings (🟡): {warning_count}
- Suggestions (🟢): {info_count}

**By Category:**
- Security: {security_count}
- Performance: {performance_count}
- Best Practice: {best_practice_count}
- Testing: {testing_count}
- Bug: {bug_count}
- Linear Alignment: {linear_alignment_count}
- Observability: {observability_count}

### 🎯 Overall Summary

**Total Active Review Threads:** {total_active_threads}
- Open threads requiring attention: {open_threads_count}
- Resolved threads: {total_resolved_count}

**Code Quality Assessment:**
- ✅ Issues resolved this review: {fixed_count}
- 🆕 New issues identified: {new_issues_found}
- ⚠️ Remaining open issues: {remaining_open_issues}

### 📋 Next Steps

1. **Immediate Actions** (if critical issues exist):
   - Address {critical_count} critical issue(s) before merging
   - Review security vulnerabilities

2. **Before Merge** (if warnings exist):
   - Consider {warning_count} warning(s) for code quality
   - Review performance implications

3. **Code Quality** (if suggestions exist):
   - Review {info_count} suggestion(s) for improvements
   - Consider best practice recommendations

4. **Linear Integration:**
   - Update Linear issue status if all requirements are met
   - Link resolved threads to Linear comments if needed

5. **Follow-up:**
   - Manually verify {cannot_verify_count} comment(s) that couldn't be auto-verified
   - Review inline comments on specific lines: {PR URL}/files

### Cost Consumption


After all operations are complete, calculate token usage and provide a comprehensive final summary:

**Calculate Token Usage and Cost**

Calculate the total tokens used and estimated cost:

```
Total Tokens Used = Current Token Count - Starting Token Count (from Token Usage Tracking section)

Cost Estimation (based on Claude Sonnet 4.5 pricing):
- Input tokens: $3.00 per million tokens
- Output tokens: $15.00 per million tokens

Estimated Cost Calculation:
- Input cost = (Input tokens / 1,000,000) × $3.00
- Output cost = (Output tokens / 1,000,000) × $15.00
- Total estimated cost = Input cost + Output cost
```

**Note:** Token count breakdown (input vs output) may not be directly visible. Provide total token usage and a conservative cost estimate assuming a typical input:output ratio for code review tasks (approximately 70:30 ratio).

**Display Comprehensive Summary**

Provide a comprehensive final summary:

### 🔗 Links

- **View PR Review Comments:** {PR URL}/files
- **View Linear Issue:** https://linear.app/issue/{LINEAR_ISSUE_ID}
- **PR Overview:** {PR URL}

---
🤖 Automated review completed by Claude Code
```

## Error Handling

Throughout the process, handle these potential errors:

**Initial Setup Errors:**
- **MCP Server Not Connected**: If GitHub or Linear MCP server is not available, inform the user and stop
- **Invalid PR URL or number**: Validate the format before attempting API calls
- **Linear issue not found**: Check if the issue ID is valid and accessible
- **Permission Errors**: User may not have access to the PR or Linear issue

**Review Comment Fetching Errors (Step 4b):**
- **Failed to fetch review comments**: If comment listing fails, log error but continue with review (just won't be able to check existing comments)
- **Malformed comment data**: If comment parsing fails, skip that comment and continue with others
- **No review comments found**: This is normal for new PRs, proceed with normal review

**Code Review Errors (Step 5):**
- **MCP Tool Errors**: If an MCP tool call fails, check the error message and suggest solutions
- **Invalid diff format**: Handle cases where diff data is malformed or incomplete
- **Agent fails to return valid JSON**: Ask agent to retry or manually parse the response

**Comment Resolution Errors (Step 6e):**
- **Failed to resolve comment**: Log error with comment ID and continue with others
  - Common causes: Already resolved, insufficient permissions, comment deleted
- **Failed to add reply before resolving**: This is non-critical, attempt resolution anyway
- **Comment not found**: Skip and log (may have been deleted)

**Comment Posting Errors (Step 7):**
- **Failed to post comments**: If position is outdated, retry as general PR comment
- **Invalid line number**: The line may have changed; post as general comment with file/line reference
- **Rate limiting**: If API rate limit is hit, wait and retry
- **Duplicate comment**: If a review comment already exists at the same line, skip posting

**General Error Handling Strategy:**
For each error:
1. Log the error with context (step, PR number, comment ID, etc.)
2. Provide clear guidance to the user on how to resolve it
3. Continue with remaining operations when possible
4. Include error summary in the final report

## Notes About MCP Integration

**GitHub MCP Server** (check available implementations):
- Tool: `get_pull_request` - Fetch PR details
- Tool: `get_pull_request_files` or `list_pull_request_files` - Get changed files and diffs
- Tool: `list_review_comments` - List all review comments on a PR (used in Step 4b)
- Tool: `create_review_comment` - Create inline review comments on specific lines
- Tool: `create_issue_comment` - Create general comments on the PR (fallback)
- Tool: `create_review_comment_reply` - Reply to existing review comments (used in Step 6e)
- Tool: `resolve_review_thread` - Resolve a review comment thread (if available, used in Step 6e)

**Linear MCP Server** (various implementations available):
- Common tools: Get issue, search issues, create/update issues, list comments
- Check your specific Linear MCP implementation with `/mcp inspect linear`
- Community servers available (check Linear MCP server implementations)

**General Notes:**
- The fullstack-code-reviewer agent has access to: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash
- Use TodoWrite to track review progress for transparency
- MCP tools handle authentication automatically (configured in MCP settings)
- The exact MCP tool prefix (e.g., `mcp__github__` or `mcp__linear__`) depends on how the server is named in your config
- Use `/mcp list` to see all connected servers and their tool prefixes
- Use `/mcp inspect <server-name>` to see available tools and parameters