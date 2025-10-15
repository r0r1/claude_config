@"
---
argument-hint: [MERGE_REQUEST_URL_OR_ID] [JIRA_ISSUE_ID]
description: Review GitLab MR with JIRA issue specification and post threaded feedback to GitLab
---

# Review GitLab MR with JIRA Issue Specification

You will review a GitLab Merge Request in the context of a JIRA issue, performing a comprehensive code review and posting findings as threaded discussions on GitLab.

## Token Optimization Strategy

**IMPORTANT:** This command is optimized to minimize token usage:
- **Only unresolved discussions** are fetched and verified (resolved discussions are skipped)
- Discussions are processed **one by one** or in small batches (max 5 at a time)
- This approach prevents token limit issues on MRs with extensive discussion history
- Progress is displayed incrementally to keep you informed

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

## Token Usage Tracking

**IMPORTANT: Note the starting token count** when this command begins execution. This will be used to calculate total token usage and cost estimation at the end.

At the start of execution, record:
- Starting token count (visible in system warnings)
- This baseline will be used to calculate: `Total Tokens Used = Final Token Count - Starting Token Count`

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

## Step 4: Fetch MR Changes (Complete Diff)

**IMPORTANT:** Fetch ALL changes in the MR (from base branch to head branch), NOT just the latest commit.

Use the GitLab MCP server tool `list_merge_request_diffs` to fetch the detailed changes:

```
Use MCP tool: mcp__gitlab__list_merge_request_diffs
Parameters:
- Merge request identifier (same as Step 3)
```

This will return a list of diff versions for the merge request. **You need the COMPLETE diff** showing ALL changes from the target branch (base) to the source branch (head).

**CRITICAL:** Ensure you're getting the FULL MR diff, not individual commit diffs:
- The diff should show ALL accumulated changes in the MR
- This is the diff from `target_branch...source_branch` (three-dot diff)
- NOT just the latest commit's changes
- NOT just changes since the last review

If `list_merge_request_diffs` returns multiple versions, you typically want the latest version, but ensure it represents the COMPLETE cumulative diff.

**Alternative if the above doesn't work:**
If the MCP tool returns individual commit diffs or incomplete data, you may need to use:
```
Use MCP tool: mcp__gitlab__get_merge_request_changes
Parameters:
- Merge request identifier (same as Step 3)
```

This tool specifically returns the complete set of changes (files and diffs) for the entire MR.

Parse the response to extract:
- **All changed files** (paths) - every file modified in the entire MR
- Line-by-line diffs for each file showing additions (+) and deletions (-)
- Old and new file paths (for renamed/moved files)
- New line numbers for each change (critical for posting inline comments)
- Diff content with proper context
- **Verify completeness**: The diff should include ALL commits in the MR, not just recent ones

Organize the changes by file for systematic review. For each file, structure the diff in a readable format:
```
File: path/to/file.rb
Old path: path/to/old_file.rb (if renamed)
Lines changed: 42-56, 89-102

Diff:
[Full diff content with line numbers and context]
```

**Verification Check:**
Before proceeding, verify you have the COMPLETE diff:
- Check the number of files changed matches what's shown in the GitLab MR UI
- The diff should span from the base branch to the current head
- If you only see changes from the latest 1-2 commits, you have the WRONG diff

Make sure to preserve the exact line numbers from the diff, as these will be used in Step 7 to post inline comments.

## Step 4b: Fetch Existing Discussions

**IMPORTANT:** Fetch ALL existing discussions (both resolved and unresolved) to properly update them instead of creating duplicates.

Before reviewing the code, check ALL existing discussions to:
- Avoid duplicate comments on already-flagged issues
- Check if previously flagged issues have been fixed and resolve them
- Check if previously resolved issues have regressed and unresolve them
- Update existing discussions instead of ignoring them

**Step 4b.1: List ALL Discussions**

Use the GitLab MCP server tool to fetch ALL discussions:

```
Use MCP tool: mcp__gitlab__discussion_list
Parameters:
- Merge request identifier (same as used in Steps 3-4)
- No filter (fetch both resolved and unresolved)
```

Display initial count:
```
Found {total_count} existing discussions on this MR:
- Unresolved: {unresolved_count}
- Resolved: {resolved_count}

Processing discussions to check their current status...
```

**Step 4b.2: Process Discussions One by One**

**CRITICAL:** Do NOT load all discussion details at once. Process incrementally:

For each discussion (both resolved and unresolved):
1. Fetch individual discussion details if needed
2. Extract the discussion ID and current resolved status
3. Check if it's a bot-generated discussion (contains "🤖 Automated review by Claude Code")
4. Parse the discussion body to extract:
   - File path (from inline position or from body text)
   - Line number (from inline position or from body text)
   - Severity (🔴/🟡/🟢)
   - Category (Security, Performance, etc.)
   - Issue description
   - Original problematic code
   - Suggested fix

**Token Management:**
- Process discussions in batches of 5 if there are many
- Display progress: "Processing discussion {n} of {total}..."
- Store both resolved and unresolved discussions for verification

**Step 4b.3: Store ALL Discussion Context**

Create a structured list of ALL discussions:
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
  },
  {
    "discussion_id": "def456",
    "resolved": true,
    "file_path": "path/to/file.rb",
    "line_number": 89,
    "severity": "warning",
    "category": "Performance",
    "description": "N+1 query issue",
    "is_inline": true
  }
]
```

Display summary to user:
```
Processed {count} discussions:
- Unresolved discussions: {unresolved_count}
- Resolved discussions: {resolved_count}
- Inline comments: {inline_count}
- General threads: {general_count}
```

## Step 4c: Detect Project Type

Before launching the code review agent, detect if this is a Flutter/Dart project by checking the changed files:

**Detection Criteria:**
1. Check if any changed file paths contain `.dart` extension
2. Check if any changed file paths include `pubspec.yaml` or `pubspec.lock`
3. Check if any changed file paths contain common Flutter directories: `lib/`, `test/`, `integration_test/`, `android/app/`, `ios/Runner/`

**Detection Logic:**
```bash
# Analyze the file paths from the MR changes (Step 4)
# Count .dart files
# Check for pubspec.yaml
# Check for Flutter-specific directory structure
```

**Set Project Type Variable:**
- If Flutter indicators found: `project_type = "flutter"`
- Otherwise: `project_type = "fullstack"`

Display to user:
```
Detected project type: [Flutter/Dart | Fullstack]
Selected agent: [mobile-code-reviewer | fullstack-code-reviewer]
```

## Step 5: Launch Code Review Agent

Based on the project type detected in Step 4c, launch the appropriate code review agent:
- **Flutter/Dart projects**: Use the `mobile-code-reviewer` agent
- **Other projects**: Use the `fullstack-code-reviewer` agent

Use the Task tool to launch the selected agent with the following comprehensive prompt:

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
{Insert list of ALL discussions (both resolved and unresolved) with their details}

**IMPORTANT:** Both resolved and unresolved discussions are provided to check their current status and update them accordingly.

**Your Task:**
You have TWO primary objectives:

**OBJECTIVE 1: Verify ALL Existing Discussions**
For each discussion provided above (both resolved and unresolved), check if the issue is still present in the current code:
1. Locate the file and line mentioned in the discussion
2. Analyze if the issue described is still present
3. Determine the verification status:
   - "FIXED" - The issue has been resolved (should be marked as resolved)
   - "STILL_PRESENT" - The issue remains in the code (should remain/become unresolved)
   - "REGRESSED" - Previously resolved issue has returned (should be unresolve)
   - "CANNOT_VERIFY" - Cannot determine (file removed, line changed significantly, etc.)
4. Provide evidence (code snippet showing it's fixed or still problematic)
5. Note if the current resolved status matches the verification status

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

**CRITICAL:** The diff provided above contains ALL changes in the MR (from base branch to head branch), not just the latest commit. You must review ALL these changes comprehensively.

**Important Instructions:**
- Review EACH file separately
- Review ALL changes shown in the complete MR diff (not just recent commits)
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
      "current_resolved_status": true,
      "file_path": "path/to/file.rb",
      "line_number": 42,
      "status": "FIXED|STILL_PRESENT|REGRESSED|CANNOT_VERIFY",
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

**Status Definitions:**
- FIXED: Issue was present but is now resolved → should be marked as resolved
- STILL_PRESENT: Issue is still in the code → should remain unresolved (or unresolve if currently resolved)
- REGRESSED: Issue was previously fixed but has returned → should be unresolved with a note about regression
- CANNOT_VERIFY: Cannot determine status → manual review needed, keep current status

Ensure the JSON is valid and can be parsed programmatically.
```

## Step 6: Process Review Results

After the fullstack-code-reviewer agent completes:

**Step 6a: Parse and Validate JSON Response**
1. Parse the JSON response containing both `existing_discussions_verification` and `new_issues` arrays
2. Validate that all required fields are present

**Step 6b: Process Existing Discussions Verification**

Count and categorize the verification results for ALL discussions:
- Fixed: {count} - Issues that have been resolved
- Still Present: {count} - Issues that remain in the code
- Regressed: {count} - Previously resolved issues that have returned
- Cannot Verify: {count} - Cannot determine current status

Display summary:
```
## Existing Discussions Verification

✅ Fixed Issues: {fixed_count}
   - Will be resolved

❌ Still Present: {still_present_count}
   - Will remain/become unresolved

🔄 Regressed Issues: {regressed_count}
   - Previously resolved but returned, will be unresolved

⚠️ Cannot Verify: {cannot_verify_count}
   - Manual verification needed, status unchanged
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
1. Update all discussions and post new comments (recommended)
2. Only update existing discussions (resolve/unresolve as needed)
3. Only post new comments
4. Do nothing (review only)

Enter your choice (1-4):
```

## Step 6e: Update Existing Discussions

If user chooses option 1 or 2, proceed with updating discussions:

**Step 6e.1: Categorize Discussions by Action Needed**

Categorize the `existing_discussions_verification` array:
- **To Resolve**: status = "FIXED" and current_resolved_status = false
- **To Unresolve**: status = "STILL_PRESENT" or "REGRESSED" and current_resolved_status = true
- **No Change Needed**:
  - status = "FIXED" and current_resolved_status = true
  - status = "STILL_PRESENT" and current_resolved_status = false
  - status = "CANNOT_VERIFY" (keep current status)

**Step 6e.2: Resolve Fixed Discussions**

For each discussion that needs to be resolved (status = "FIXED" and currently unresolved):

1. First, add a note to the discussion:
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

2. Then, resolve the discussion:
```
Use MCP tool: mcp__gitlab__discussion_resolve
Parameters:
- Merge request identifier (same as used in previous steps)
- Discussion ID: {from verification result}
- Resolved: true
```

**Step 6e.3: Unresolve Regressed/Still Present Discussions**

For each discussion that needs to be unresolved (status = "STILL_PRESENT" or "REGRESSED" and currently resolved):

1. First, add a note to the discussion:
```
Use MCP tool: mcp__gitlab__discussion_add_note
Parameters:
- Merge request identifier
- Discussion ID: {from verification result}
- Note content:
  For STILL_PRESENT:
  "⚠️ This issue is still present in the current code.

  **Evidence:**
  {evidence from verification result}

  {notes from verification result}

  Please address this issue before merging.

  ---
  🤖 Verified by Claude Code"

  For REGRESSED:
  "🔄 This previously resolved issue has regressed and returned to the code.

  **Evidence:**
  {evidence from verification result}

  {notes from verification result}

  This needs immediate attention as it's a regression.

  ---
  🤖 Verified by Claude Code"
```

2. Then, unresolve the discussion:
```
Use MCP tool: mcp__gitlab__discussion_unresolve
Parameters:
- Merge request identifier (same as used in previous steps)
- Discussion ID: {from verification result}
```

**Step 6e.4: Track Update Progress**

For each update attempt:
- Show progress: "Updating discussion {n} of {total}..."
- Indicate action: "Resolving..." or "Unresolving..." or "Keeping current status..."
- Handle errors gracefully:
  - If update fails (permissions, discussion already in target state, etc.), log error and continue
  - If adding note fails but status update succeeds, that's acceptable
- Track successful and failed updates

Display progress:
```
Updating Existing Discussions:
[✅] Discussion #1 - Resolved: Security issue in auth.rb:42
[✅] Discussion #2 - Unresolved: Performance issue in query.rb:89 (regression)
[⏭️] Discussion #3 - No change: Already in correct state
[❌] Discussion #4 - Failed: Permission denied
...

Successfully updated: {success_count} / {total_count}
- Resolved: {resolved_count}
- Unresolved: {unresolved_count}
- Kept current status: {no_change_count}
- Failed: {failed_count}
```

## Step 7: Post New Review Comments to GitLab

If user chooses option 1 or 3 (post new comments), proceed with posting.

**IMPORTANT:** Only post comments from the `new_issues` array that don't already have existing discussions.

**Logic:**
- If an issue from `new_issues` matches a file/line that already has a discussion in `existing_discussions_verification`, SKIP posting it (the existing discussion will be updated in Step 6e)
- Only post issues that are genuinely new and not already tracked in existing discussions
- This prevents duplicate discussions for the same issue

**PRIORITY ORDER FOR POSTING COMMENTS:**
1. **First Priority**: Post as inline discussion thread on specific line (with position)
2. **Second Priority**: Post as general discussion thread (without position) only if inline fails

**Step 7a: Attempt Inline Discussion Thread (First Priority)**

For each review item in the JSON array, first attempt to post as an inline comment:

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

- Position (REQUIRED for inline comments):
  - base_sha: {from Step 3}
  - start_sha: {from Step 3}
  - head_sha: {from Step 3}
  - position_type: "text"
  - new_path: {file_path from review item}
  - new_line: {line_number from review item}
```

**Step 7b: Fallback to General Discussion Thread (Second Priority)**

**ONLY if Step 7a fails** (position invalid, line doesn't exist, or API error), retry as a general discussion thread:

```
Use MCP tool: mcp__gitlab__discussion_new
Parameters:
- Target resource: The merge request identifier (same as used in Steps 3-4)
- Body/Note content (formatted as markdown, with file/line info in the message):
  "**{severity_emoji} {category}: {title}**

  **File:** `{file_path}` **Line:** {line_number}

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

- Position: OMIT this parameter (no position = general thread)
```

**Important Notes:**
- ALWAYS attempt inline discussion thread first
- Only fall back to general thread if inline posting fails
- When posting as general thread, include file path and line number in the message body

For each posting:
- Show progress: "Posting comment {n} of {total}..."
- Indicate type: "Attempting inline comment..." or "Falling back to general thread..."
- Handle errors gracefully:
  - If inline position is invalid (line no longer exists), retry as general thread
  - If discussion creation fails completely, log the error and continue with next item
- Track successful inline, successful general, and failed postings separately

**Severity Emoji Mapping:**
- Critical (🔴): Use red circle emoji
- Warning (🟡): Use yellow circle emoji
- Info (🟢): Use green circle emoji

## Step 8: Comprehensive Summary Report

After all operations are complete, calculate token usage and provide a comprehensive final summary:

**Step 8a: Calculate Token Usage and Cost**

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

**Step 8b: Display Comprehensive Summary**

Provide a comprehensive final summary:

```
## GitLab MR Review Complete ✅

**Merge Request:** {MR URL}
**JIRA Issue:** {JIRA Issue Key} - {Summary}

### 💰 Token Usage & Cost

**Total Tokens Used:** {total_tokens_used:,}
**Estimated Cost:** ${estimated_cost} USD

*Cost breakdown (estimated):*
- Input tokens (~70%): {input_tokens:,} tokens ≈ ${input_cost}
- Output tokens (~30%): {output_tokens:,} tokens ≈ ${output_cost}

*Note: This is an estimate based on Claude Sonnet 4.5 pricing ($3/M input, $15/M output)*

### 📊 Existing Discussions Status

**Total Discussions Checked:** {total_discussions}
- ✅ Fixed (resolved): {fixed_count}
- ❌ Still Present (kept/became unresolved): {still_present_count}
- 🔄 Regressed (unresolved, previously fixed): {regressed_count}
- ⚠️ Cannot Verify (manual check needed): {cannot_verify_count}

**Update Actions Performed:**
- Successfully resolved: {successful_resolutions}
- Successfully unresolved: {successful_unresolutions}
- No change needed (already correct): {no_change_count}
- Failed to update: {failed_updates}

**Note:** All discussions (both resolved and unresolved) were checked and updated according to their current status in the code.

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

**Total Discussions After Update:** {total_discussions_after_update}
- Open/Unresolved: {open_discussions_count}
- Resolved: {resolved_discussions_count}

**Code Quality Assessment:**
- ✅ Issues fixed and resolved: {fixed_count}
- ❌ Issues still present: {still_present_count}
- 🔄 Regressed issues: {regressed_count}
- 🆕 New issues identified: {new_issues_found}
- 📝 Total issues requiring attention: {total_open_issues}

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
   - Address {regressed_count} regressed issue(s) with high priority
   - Investigate why previously fixed issues have returned

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
- **Token limit exceeded**: If fetching all discussions causes token limit issues:
  - Process discussions one by one instead of all at once
  - Process in batches of 5 discussions at a time
  - Display progress to user: "Processing discussion {n} of {total}..."
  - If still hitting limits, consider processing only unresolved discussions first, then resolved ones
- **Malformed discussion data**: If discussion parsing fails, skip that discussion and continue with others
- **No discussions found**: This is normal for new MRs, proceed with normal review
- **Too many discussions**: If MR has 100+ discussions, warn user about potential token usage and consider processing in smaller batches

**Code Review Errors (Step 5):**
- **MCP Tool Errors**: If an MCP tool call fails, check the error message and suggest solutions
- **Invalid diff format**: Handle cases where diff data is malformed or incomplete
- **Agent fails to return valid JSON**: Ask agent to retry or manually parse the response

**Discussion Update Errors (Step 6e):**
- **Failed to resolve discussion**: Log error with discussion ID and continue with others
  - Common causes: Already resolved, insufficient permissions, discussion deleted
- **Failed to unresolve discussion**: Log error with discussion ID and continue with others
  - Common causes: Already unresolved, insufficient permissions, discussion deleted
  - Note: Some GitLab versions may not support unresolving via API
- **Failed to add note before updating**: This is non-critical, attempt status update anyway
- **Discussion not found**: Skip and log (may have been deleted)
- **No permission to update**: User may only have read access, log and continue

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
- Tool: `list_merge_request_diffs` - Get diff versions and changes (prefer this for COMPLETE MR diff)
- Tool: `get_merge_request_changes` - Alternative to get complete MR changes if list_merge_request_diffs doesn't work
- Tool: `discussion_list` - List all discussions on an MR (used in Step 4b)
- Tool: `discussion_new` - Create discussion threads (inline or general)
- Tool: `discussion_add_note` - Reply to existing discussions (used in Step 6e)
- Tool: `discussion_resolve` - Resolve a discussion thread (used in Step 6e)
- Tool: `discussion_unresolve` - Unresolve a discussion (if needed)

**Important:** When fetching diffs, ensure you get the COMPLETE cumulative diff (base to head), not individual commit diffs. The complete diff shows ALL changes in the MR, which is required for comprehensive review.

**JIRA MCP Server** (various implementations available):
- Common tools: Search issues, get issue details, create/update issues
- Check your specific JIRA MCP implementation with `/mcp inspect jira`
- Official Atlassian MCP or community servers (cosmix/jira-mcp, sooperset/mcp-atlassian, etc.)

**General Notes:**
- The code review agent (mobile-code-reviewer or fullstack-code-reviewer) has access to: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash
- The `mobile-code-reviewer` agent is specialized for Flutter/Dart projects with expertise in:
  - Flutter widgets, state management, and performance optimization
  - Dart best practices and null safety
  - Mobile-specific security concerns
  - Flutter testing strategies
  - Platform-specific considerations (iOS/Android)
- The `fullstack-code-reviewer` agent is for Ruby on Rails and Next.js projects
- Use TodoWrite to track review progress for transparency
- MCP tools handle authentication automatically (configured in MCP settings)
- The exact MCP tool prefix (e.g., `mcp__gitlab__` or `mcp__jira__`) depends on how the server is named in your config
- Use `/mcp list` to see all connected servers and their tool prefixes
- Use `/mcp inspect <server-name>` to see available tools and parameters
