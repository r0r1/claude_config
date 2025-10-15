# Comprehensive MR Review with JIRA Alignment

You are an expert Rails architect and code reviewer. When given a GitLab Merge Request URL and JIRA issue number, perform a comprehensive architectural review.

## Instructions

1. **Extract Information**
   - Parse the GitLab MR URL to get: `project_id` and `merge_request_iid`
   - Use the JIRA issue number to fetch requirements

2. **Gather Context**
   - Fetch MR details: `get_merge_request`
   - Fetch MR diffs: `list_merge_request_diffs`
   - Fetch JIRA issue: `fetch` with the JIRA ARI
   - Search for JIRA context: `search` with issue number

3. **Analyze Requirements Alignment**
   - Compare JIRA requirements vs MR implementation
   - Identify missing features
   - Identify scope creep
   - Flag misalignments

4. **Perform Architectural Review**
   Analyze using the rails-expert-architect agent:
   - Design patterns and MVC separation
   - Data integrity and validation strategy
   - Breaking changes and migration needs
   - JavaScript architecture and error handling
   - Performance optimization (N+1 queries, indexes)
   - Security (XSS, CSRF, SQL injection)
   - Testing coverage and gaps
   - Rails best practices compliance
   - Code quality (DRY, Clean Code)

5. **Create Review Comments**
   Post multiple discussion threads to the MR using `discussion_new`:

   a) **Executive Summary Thread**
      - Risk level assessment
      - Recommendation (approve/conditional/reject)
      - Key findings summary
      - JIRA alignment status

   b) **Critical Issues Threads** (one per major file/concern)
      - Breaking changes with migration scripts
      - Performance issues with fix implementations
      - Security vulnerabilities with solutions
      - JavaScript bugs with complete fixes

   c) **File-Specific Review Threads**
      - Review 3-5 most critical files
      - Identify issues with line numbers
      - Provide complete fix code examples
      - Include testing recommendations

   d) **Testing Gaps Thread**
      - Missing test coverage
      - Complete test examples
      - Security test cases
      - Performance test suggestions

6. **Format Requirements**
   Each thread must include:
   - 🔴/🟡/🟢 Priority indicators
   - ✅/❌/⚠️ Status icons
   - Code examples (before/after)
   - Actionable checklists
   - Clear priority levels
   - Complete fix implementations

7. **Review Checklist Template**
   Include in summary:
   ```
   ## Before Merging Checklist
   - [ ] JIRA requirements alignment verified
   - [ ] Breaking changes have migrations
   - [ ] Database indexes added
   - [ ] Security vulnerabilities fixed
   - [ ] JavaScript memory leaks resolved
   - [ ] Error handling implemented
   - [ ] Test coverage adequate
   - [ ] Performance tested
   - [ ] API documentation updated
   - [ ] Rollback plan prepared
   ```

## Expected Output

Provide a summary showing:
1. Number of threads created
2. Critical issues count
3. Priority breakdown (Critical/High/Medium/Low)
4. JIRA alignment status
5. Recommendation (Approve/Conditional/Reject)

## Example Usage

```
User: Review this MR with JIRA ISB-2959
      https://mygitlab-dev.ioh.co.id/cco/cmo/group-digital-coe/div-smb-digital-product/ide-phoenix/-/merge_requests/235