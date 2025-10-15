---
description: Update existing Jira issue with comprehensive acceptance criteria, test cases, and technical requirements
---

First, fetch the existing Jira issue details using the issue ID provided and analyze the current description, comments, and any existing requirements.

**CRITICAL: You MUST format the entire output using JIRA markdown syntax (see JIRA Markdown Format Requirements below). DO NOT use standard markdown or GitHub markdown.**

Then, generate a comprehensive Jira specification that enhances the existing issue with:

1. **Acceptance Criteria** (Product Owner Perspective)
   - User story in proper format (if not already present)
   - Given-When-Then scenarios for all flows (primary, alternative, edge cases)
   - Functional and non-functional requirements
   - Business rules and constraints
   - Error handling and edge cases
   - UX/UI considerations
   - Definition of Done checklist
   - Dependencies and risks

2. **Test Cases** (QA Engineer Perspective)
   - Complete test case specifications with IDs
   - Positive test scenarios (happy path)
   - Negative test scenarios (error handling)
   - Boundary value tests
   - Edge cases and security tests
   - Non-functional tests (performance, security, accessibility, usability)
   - Regression and integration tests
   - Automation recommendations (YES/NO/PARTIAL) with rationale
   - Playwright code examples for automatable tests
   - Test data requirements and test coverage summary

3. **Technical Requirements** (Senior Rails Developer Perspective)
   - Architecture and design patterns selection
   - Database schema changes with zero-downtime migrations
   - API endpoints specification (if applicable) with request/response formats
   - Service objects and business logic organization
   - Background jobs and async processing requirements
   - Performance optimization strategies (query optimization, caching, scalability)
   - Security considerations (authentication, authorization, data protection, input validation)
   - Third-party integrations and webhook handling
   - Error handling and structured logging strategy
   - Code organization structure (services, queries, forms, decorators, policies)
   - Comprehensive testing strategy with RSpec examples (models, services, controllers, jobs)
   - Deployment and rollback considerations with feature flags

**Usage:**
Provide the Jira issue ID (e.g., PROJ-123 or just 123)

**Process:**
1. Fetch the issue details from Jira
2. Analyze existing description, requirements, and context
3. Generate comprehensive specifications based on the issue
4. Format output in **JIRA markdown format** (NOT GitHub/CommonMark markdown) - see examples below
5. Include sections for Acceptance Criteria, Test Cases, and Technical Requirements
6. Attempt to update the Jira issue
7. **If update fails:** Save the generated specification to `/tmp/jira-update-{issue-id}-{timestamp}.md` instead of the root folder

**JIRA Markdown Format Requirements:**
- Headings: `h1.` `h2.` `h3.` `h4.` `h5.` `h6.` (NOT #)
- Bold: `*bold text*` (NOT **)
- Italic: `_italic text_` (NOT *)
- Bullet lists: `*` for bullets, `#` for numbered lists (NOT -)
- Code blocks: `{code:language}...{code}` (NOT ```)
- Inline code: `{{text}}` (NOT backticks)
- Links: `[text|url]` (NOT [text](url))
- Tables: `||heading 1||heading 2||` and `|cell 1|cell 2|`
- Quotes: `{quote}text{quote}` (NOT >)
- Panels: `{panel:title=Title}content{panel}`
- Color: `{color:red}text{color}`
- Line break: Use actual line breaks or `\\`

**JIRA Format Example (User Story Section):**
{code}
h1. User Story

*As a* business customer
*I want to* view the new Platinum Hub homepage
*So that I* can explore Platinum Business products and access role-specific features

h1. Design Reference

* Figma Design: [Design Link|https://www.figma.com/design/example]
* Icon Assets: [Google Drive|https://drive.google.com/drive/folders/example]

h1. Acceptance Criteria

h2. AC1: Page Layout and Branding

*Given* a user visits the Platinum Hub homepage
*When* the page loads
*Then* the following elements should be visible:

* IM3 Platinum Business Vertical logo in upper left corner
* "What is Platinum Business" section in left upper corner
* Header navigation with: Toko, Platinum Business, Academy, Wawasan
* Login button OR user icon (if authenticated) in header above banner
* Hero banner on upper right
* Footer with Indosat logo
* Contact email: {{platinumbusiness@ioh.co.id}} in footer
* Social media links pointing to IM3 official channels
{code}

**REMEMBER:**
- Start headings with `h1.` `h2.` etc (with a period and space)
- Use `*text*` for bold (single asterisks)
- Use `_text_` for italic (single underscores)
- Use `{{text}}` for inline code (double curly braces)
- Use `*` at the start of lines for bullet points

**Error Handling:**
- If the Jira update fails (network issues, permissions, etc.), save the generated content to `/tmp/jira-update-{issue-id}-{timestamp}.md`
- Inform the user of the file location so they can manually update Jira or retry later
- Preserve all generated content to avoid data loss

The output will be comprehensive, actionable, and ready for the development team to implement. Each section will be properly formatted for Jira markdown syntax.
