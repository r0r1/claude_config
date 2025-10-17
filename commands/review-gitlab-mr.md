@"
---
argument-hint: [MERGE_REQUEST_URL_OR_ID] [JIRA_ISSUE_ID]
description: Review GitLab MR with JIRA issue specification and post threaded feedback to GitLab
---

# Review GitLab MR with JIRA Issue Specification

You will review a GitLab Merge Request in the context of a JIRA issue, performing a comprehensive code review and posting findings as threaded discussions on GitLab.

## Arguments Provided
- **Merge Request**: $1 (URL or MR ID)
- **JIRA Issue**: $2 (Issue key, e.g., PROJ-123)

## Prerequisites Check

Before starting, verify that the required MCP servers are connected:

Use the `/mcp list` command to check for:
- **GitLab MCP Server** - For accessing GitLab API (merge requests, diffs, posting discussions)
- **JIRA MCP Server** - For fetching JIRA issue details

If either MCP server is not connected, inform the user with instructions:
```
❌ Required MCP servers not found.

Please ensure you have the following MCP servers configured in your Claude Code settings:

1. **GitLab MCP Server**
   - Provides access to GitLab API for MR operations
   - Configuration: Add to your MCP settings with your GitLab token

2. **JIRA MCP Server**
   - Provides access to JIRA API for issue details
   - Configuration: Add to your MCP settings with your JIRA credentials

To configure MCP servers, refer to: https://docs.claude.com/en/docs/claude-code/mcp
```

List available MCP tools with: `Use the Bash tool to run: /mcp inspect <server-name>` to see what tools are available from each server.

## Step 1: Extract GitLab Project and MR Information

Parse the merge request argument to extract:
- If URL provided: Extract project path and MR IID from URL
  - Format: `https://gitlab.com/{project_path}/-/merge_requests/{iid}`
- If numeric ID provided: Ask user for project path (e.g., "namespace/project")

Use the Bash tool to extract this information:
```bash
# Extract project and MR IID from URL or use provided values
```

## Step 2: Fetch JIRA Issue Details

**IMPORTANT: You MUST use JIRA MCP tools exclusively. DO NOT use WebFetch, Bash with curl, or access JIRA URLs directly.**

**JIRA Base URL:** https://ioh-smb.atlassian.net/

**Step 2a: Discover Available JIRA MCP Tools**

First, run `/mcp list` to verify the JIRA MCP server is connected and get its exact name/prefix.

Then run `/mcp inspect <jira-server-name>` to see all available JIRA tools and their parameters.

**Step 2b: Fetch Issue Details via MCP**

Use the JIRA MCP server tool to fetch the issue details:

```
Use the MCP tool from JIRA server (e.g., mcp__jira__get_issue or similar) with:
- Issue key: $2 (e.g., PROJ-123)
- Fields: summary, description, issuetype, priority, status, acceptance criteria, and all custom fields
```

Common JIRA MCP tool patterns:
- `mcp__jira__get_issue` - Get a single issue by key
- `mcp__jira__search_issues` - Search for issues using JQL
- `mcp__atlassian__get_issue` - Some servers use this naming
- Check the actual tool name with `/mcp list` and `/mcp inspect`

**Step 2c: Fetch JIRA Comments via MCP**

After fetching the issue details, fetch all comments on the issue:

```
Use the MCP tool from JIRA server (e.g., mcp__jira__get_comments or mcp__jira__list_comments) with:
- Issue key: $2 (e.g., PROJ-123)
```

If there's no dedicated comments tool, comments may be included in the issue details response. Check the issue response for a `comment` or `comments` field.

**Step 2d: Extract and Store Context**

Extract and summarize from the JIRA MCP responses:
- Issue summary
- Description
- Acceptance criteria (often in custom fields or description)
- Status
- Priority
- Issue type
- Any relevant custom fields (story points, labels, components, etc.)
- **All comments** with author and timestamp

Store this context for the code review. This will be used to validate that the MR changes align with the JIRA requirements and consider any discussion points from comments.

**If JIRA MCP tool call fails:**
- Check the error message carefully
- Verify the issue key format is correct
- Ensure you have permissions to access the issue
- DO NOT fall back to API/URL methods - inform the user to check their MCP configuration

## Step 3: Fetch GitLab MR Details

Use the GitLab MCP server tool `get_merge_request` to fetch the merge request details:

```
Use MCP tool: mcp__gitlab__get_merge_request (or check with /mcp list for exact prefix)
Parameters:
- Merge request identifier (format depends on MCP server config - may be project/MR IID combination)
```

The exact parameter format may vary. If needed, check `/mcp inspect gitlab` to see parameter requirements.

Extract and display from the MR response:
- MR title
- Description
- Source branch
- Target branch (destination branch)
- Author
- Status (open, merged, closed)
- Web URL
- Base commit SHA, start commit SHA, and head commit SHA (needed for posting comments to specific lines)

## Step 4: Fetch MR Changes (Diff)

Use the GitLab MCP server tool `list_merge_request_diffs` to fetch the detailed changes:

```
Use MCP tool: mcp__gitlab__list_merge_request_diffs
Parameters:
- Merge request identifier (same as Step 3)
```

This will return a list of diff versions for the merge request. Typically, you want the latest diff version.

Parse the response to extract:
- All changed files (paths)
- Line-by-line diffs for each file showing additions (+) and deletions (-)
- Old and new file paths (for renamed/moved files)
- New line numbers for each change (critical for posting inline comments)
- Diff content with proper context

Organize the changes by file for systematic review. For each file, structure the diff in a readable format:
```
File: path/to/file.rb
Old path: path/to/old_file.rb (if renamed)
Lines changed: 42-56, 89-102

Diff:
[Full diff content with line numbers and context]
```

Make sure to preserve the exact line numbers from the diff, as these will be used in Step 7 to post inline comments.

## Step 4b: Fetch Existing Discussions

Before reviewing the code, fetch all existing discussions on the MR to:
- Avoid duplicate comments on already-flagged issues
- Check if previously flagged issues have been fixed
- Resolve discussions where issues are addressed

**Step 4b.1: List All Discussions**

Use the GitLab MCP server tool to fetch all discussions:

```
Use MCP tool: mcp__gitlab__discussion_list
Parameters:
- Merge request identifier (same as used in Steps 3-4)
```

**Step 4b.2: Parse and Categorize Discussions**

For each discussion returned:
1. Extract the discussion ID and resolved status
2. Check if it's a bot-generated discussion (contains "🤖 Automated review by Claude Code")
3. Parse the discussion body to extract:
   - File path (from inline position or from body text)
   - Line number (from inline position or from body text)
   - Severity (🔴/🟡/🟢)
   - Category (Security, Performance, etc.)
   - Issue description
   - Original problematic code
   - Suggested fix

**Step 4b.3: Store Discussion Context**

Create a structured list of existing discussions:
```json
[
  {
    "discussion_id": "abc123",
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

Display summary to user:
```
Found {count} existing discussions on this MR:
- Resolved: {resolved_count}
- Open: {open_count}
  - Inline comments: {inline_count}
  - General threads: {general_count}
```

## Step 5: Launch Code Review Agent

Use the Task tool to launch the fullstack-code-reviewer agent with the following comprehensive prompt:

```
You are reviewing a GitLab Merge Request in the context of a JIRA issue.

**JIRA Issue Context:**
{Insert JIRA issue details from Step 2, including:
- Issue key, summary, description
- Status, priority, issue type
- Acceptance criteria
- All custom fields (story points, labels, components)
- All comments with authors and timestamps}

**Merge Request Details:**
{Insert MR details from Step 3}

**Existing Discussions (From Step 4b):**
{Insert list of existing discussions with their details}

**Your Task:**
You have TWO primary objectives:

**OBJECTIVE 1: Verify Existing Discussions**
For each existing discussion provided above, check if the issue is still present in the current code:
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
7. Alignment with JIRA acceptance criteria
8. Consideration of discussion points from JIRA comments

**Changed Files:**
{Insert organized file changes from Step 4}

**Important Instructions:**
- Review EACH file separately
- For EACH issue found, provide:
  - **File path** and **line numbers** affected
  - **Severity**: Critical (🔴), Warning (🟡), or Info (🟢)
  - **Category**: Security, Performance, Best Practice, Testing, Bug, or JIRA Alignment
  - **Description**: Clear explanation of the issue
  - **Recommendation**: Specific, actionable fix with code example if applicable
  - **Original code snippet**: Show the problematic code
  - **Suggested code snippet**: Show the improved version

- Format each issue as a separate item that can be posted as a GitLab discussion thread
- Use the exact file path and line numbers from the diff
- If code aligns well with JIRA requirements, mention this positively

**Output Format:**
Structure your response as a JSON object with two arrays:

```json
{
  "existing_discussions_verification": [
    {
      "discussion_id": "abc123",
      "file_path": "path/to/file.rb",
      "line_number": 42,
      "status": "FIXED|STILL_PRESENT|CANNOT_VERIFY",
      "evidence": "Code snippet or explanation showing current state",
      "notes": "Additional context about the verification"
    }
  ],
  "new_issues": [
    {
      "file_path": "path/to/file.rb",
      "line_number": 42,
      "severity": "critical|warning|info",
      "category": "Security|Performance|Best Practice|Testing|Bug|JIRA Alignment",
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
1. Parse the JSON response containing both `existing_discussions_verification` and `new_issues` arrays
2. Validate that all required fields are present

**Step 6b: Process Existing Discussions Verification**

Count and categorize the verification results:
- Fixed: {count}
- Still Present: {count}
- Cannot Verify: {count}

Display summary:
```
## Existing Discussions Verification

✅ Fixed Issues: {fixed_count}
   - These discussions can be resolved

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
1. Resolve fixed discussions and post new comments (recommended)
2. Only resolve fixed discussions
3. Only post new comments
4. Do nothing (review only)

Enter your choice (1-4):
```

## Step 6e: Resolve Fixed Discussions

If user chooses option 1 or 2 (resolve fixed discussions), proceed with resolving:

**Step 6e.1: Identify Discussions to Resolve**

Filter the `existing_discussions_verification` array for items with status "FIXED".

**Step 6e.2: Resolve Each Fixed Discussion**

For each fixed discussion:

```
Use MCP tool: mcp__gitlab__discussion_resolve
Parameters:
- Merge request identifier (same as used in previous steps)
- Discussion ID: {from verification result}
- Resolved: true
```

Optionally, add a final note to the discussion before resolving:

```
Use MCP tool: mcp__gitlab__discussion_add_note
Parameters:
- Merge request identifier
- Discussion ID: {from verification result}
- Note content:
  "✅ This issue has been verified as fixed.

  **Evidence:**
  {evidence from verification result}

  {notes from verification result}

  ---
  🤖 Verified and resolved by Claude Code"
```

**Step 6e.3: Track Resolution Progress**

For each resolution attempt:
- Show progress: "Resolving discussion {n} of {total}..."
- Handle errors gracefully:
  - If resolution fails (permissions, discussion already resolved, etc.), log error and continue
  - If adding note fails but resolution succeeds, that's acceptable
- Track successful and failed resolutions

Display progress:
```
Resolving Fixed Discussions:
[✅] Discussion #1 - Security issue in auth.rb:42
[✅] Discussion #2 - Performance issue in query.rb:89
[❌] Discussion #3 - Failed: Permission denied
...

Successfully resolved: {success_count} / {total_count}
```

## Step 7: Post New Review Comments to GitLab

If user chooses option 1 or 3 (post new comments), proceed with posting.

**IMPORTANT:** Only post comments from the `new_issues` array. Do NOT re-post issues that are already in existing discussions (even if status is "STILL_PRESENT").

**PRIORITY ORDER FOR POSTING COMMENTS:**
1. **FIRST PRIORITY**: Post as inline discussion thread on specific line (with position)
2. **SECOND PRIORITY**: Post as general discussion thread (without position) only if inline fails

**Step 7a: Attempt Inline Discussion Thread (First Priority)**

For each review item in the `new_issues` JSON array, **ALWAYS ATTEMPT INLINE COMMENT FIRST**:

**CRITICAL: Before attempting inline comments, verify you have the correct SHA values:**
- From Step 3, you should have extracted: `diff_refs.base_sha`, `diff_refs.head_sha`, `diff_refs.start_sha`
- Display these values to confirm: "Using SHAs - base: {base_sha}, start: {start_sha}, head: {head_sha}"
- If these are missing or null, inline comments will fail

```
Use MCP tool: mcp__gitlab__discussion_new
Parameters:
- Target resource: The merge request identifier (same as used in Steps 3-4)
- Body/Note content (formatted as markdown):
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

- Position (REQUIRED for inline comments - use exact structure):
  - base_sha: {diff_refs.base_sha from Step 3 MR details}
  - start_sha: {diff_refs.start_sha from Step 3 MR details}
  - head_sha: {diff_refs.head_sha from Step 3 MR details}
  - position_type: "text"
  - new_path: {file_path from review item - must match exact file path in diff}
  - new_line: {line_number from review item - must be a line that was ADDED (+) in the diff}
```

**IMPORTANT NOTES ABOUT LINE NUMBERS:**
- `new_line` must be a line number that appears in the NEW version of the file (after changes)
- The line must be visible in the diff (either added or in context)
- Lines that were only in the old file (deleted lines with -) cannot be commented on with new_line
- If you need to comment on a deleted line, you would use `old_line` instead (but typically we comment on new code)

**Why inline comments are preferred:**
- They appear directly on the code line in the diff view
- Easier for developers to see exactly what needs to be fixed
- Better context and navigation in GitLab UI
- More professional and precise code review experience

**Step 7b: Fallback to General Discussion Thread (Second Priority)**

**ONLY if Step 7a fails** (position invalid, line doesn't exist, or API error), retry as a general discussion thread:

```
Use MCP tool: mcp__gitlab__discussion_new
Parameters:
- Target resource: The merge request identifier (same as used in Steps 3-4)
- Body/Note content (formatted as markdown):
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

- Position: OMIT this parameter (creates a general thread, not inline)
```

**Format Guidelines for General Threads:**
- Use the 📍 emoji to clearly mark the location information
- Make file path a code span (`file_path`) for readability
- Bold the line number for emphasis
- Include full context with current code and suggested fix
- Add the bot signature for consistent tracking

**Progress Tracking:**

For each posting attempt:
1. **Start with inline**: Log "Posting inline comment {n} of {total} on {file_path}:{line_number}..."
   - Log the position parameters being used: "Position: base={base_sha}, start={start_sha}, head={head_sha}, path={new_path}, line={new_line}"
2. **If inline succeeds**: Log "✅ Inline comment posted successfully" and move to next item
3. **If inline fails**:
   - Log the FULL error message: "⚠️ Inline posting failed with error: {full_error_message}"
   - Include the error code if available
   - Log "Retrying as general thread..."
4. **If general succeeds**: Log "✅ General thread posted as fallback"
5. **If both fail**: Log "❌ Failed to post comment: {error}" and continue with next item

Track separately:
- Successful inline comments: {inline_count}
- Successful general threads (fallbacks): {general_count}
- Failed postings: {failed_count}

**Error Handling:**
- If inline position is invalid (line no longer exists), retry as general thread
- If discussion creation fails completely, log the error and continue with next item
- Common errors:
  - Position invalid: Retry as general thread
  - Rate limiting: Wait briefly and retry
  - Duplicate content: Skip and note as duplicate
  - Permission errors: Log and inform user
  - Network errors: Retry once, then skip

**Severity Emoji Mapping:**
- Critical (🔴): Use red circle emoji
- Warning (🟡): Use yellow circle emoji
- Info (🟢): Use green circle emoji

## Step 8: Comprehensive Summary Report

After all operations are complete, provide a comprehensive final summary:

```
## GitLab MR Review Complete ✅

**Merge Request:** {MR URL}
**JIRA Issue:** {JIRA Issue Key} - {Summary}

### 📊 Existing Discussions Status

**Total Existing Discussions:** {total_existing_discussions}
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
- Inline comments: {inline_count}
- General threads: {general_count}
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
- JIRA Alignment: {jira_alignment_count}

### 🎯 Overall Summary

**Total Active Discussions:** {total_active_discussions}
- Open discussions requiring attention: {open_discussions_count}
- Resolved discussions: {total_resolved_count}

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

4. **JIRA Integration:**
   - Update JIRA issue status if all acceptance criteria are met
   - Link resolved discussions to JIRA comments if needed

5. **Follow-up:**
   - Manually verify {cannot_verify_count} discussion(s) that couldn't be auto-verified
   - Review inline comments on specific lines: {MR URL}#notes

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

- **View MR Discussions:** {MR URL}#notes
- **View JIRA Issue:** https://ioh-smb.atlassian.net/browse/{JIRA_ISSUE_KEY}
- **MR Overview:** {MR URL}

---
🤖 Automated review completed by Claude Code
```

## Error Handling

Throughout the process, handle these potential errors:

**Initial Setup Errors:**
- **MCP Server Not Connected**: If GitLab or JIRA MCP server is not available, inform the user and stop
- **Invalid MR URL or ID**: Validate the format before attempting API calls
- **JIRA issue not found**: Check if the issue key is valid and accessible
- **Permission Errors**: User may not have access to the MR or JIRA issue

**Discussion Fetching Errors (Step 4b):**
- **Failed to fetch discussions**: If `discussion_list` fails, log error but continue with review (just won't be able to check existing discussions)
- **Malformed discussion data**: If discussion parsing fails, skip that discussion and continue with others
- **No discussions found**: This is normal for new MRs, proceed with normal review

**Code Review Errors (Step 5):**
- **MCP Tool Errors**: If an MCP tool call fails, check the error message and suggest solutions
- **Invalid diff format**: Handle cases where diff data is malformed or incomplete
- **Agent fails to return valid JSON**: Ask agent to retry or manually parse the response

**Discussion Resolution Errors (Step 6e):**
- **Failed to resolve discussion**: Log error with discussion ID and continue with others
  - Common causes: Already resolved, insufficient permissions, discussion deleted
- **Failed to add note before resolving**: This is non-critical, attempt resolution anyway
- **Discussion not found**: Skip and log (may have been deleted)

**Comment Posting Errors (Step 7):**
- **Failed to post comments**: If position is outdated, retry as general comment
- **Invalid line number**: The line may have changed; post as general comment with file/line reference
- **Rate limiting**: If API rate limit is hit, wait and retry
- **Duplicate discussion**: If a discussion already exists at the same line, skip posting

**General Error Handling Strategy:**
For each error:
1. Log the error with context (step, MR ID, discussion ID, etc.)
2. Provide clear guidance to the user on how to resolve it
3. Continue with remaining operations when possible
4. Include error summary in the final report

## Notes About MCP Integration

**GitLab MCP Server** (from https://gitlab.com/fforster/gitlab-mcp):
- Tool: `get_merge_request` - Fetch MR details
- Tool: `list_merge_request_diffs` - Get diff versions and changes
- Tool: `discussion_list` - List all discussions on an MR (used in Step 4b)
- Tool: `discussion_new` - Create discussion threads (inline or general)
- Tool: `discussion_add_note` - Reply to existing discussions (used in Step 6e)
- Tool: `discussion_resolve` - Resolve a discussion thread (used in Step 6e)
- Tool: `discussion_unresolve` - Unresolve a discussion (if needed)

**JIRA MCP Server** (various implementations available):
- Common tools: Search issues, get issue details, create/update issues
- Check your specific JIRA MCP implementation with `/mcp inspect jira`
- Official Atlassian MCP or community servers (cosmix/jira-mcp, sooperset/mcp-atlassian, etc.)

**General Notes:**
- The fullstack-code-reviewer agent has access to: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash
- Use TodoWrite to track review progress for transparency
- MCP tools handle authentication automatically (configured in MCP settings)
- The exact MCP tool prefix (e.g., `mcp__gitlab__` or `mcp__jira__`) depends on how the server is named in your config
- Use `/mcp list` to see all connected servers and their tool prefixes
- Use `/mcp inspect <server-name>` to see available tools and parameters
