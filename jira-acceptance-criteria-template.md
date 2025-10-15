# Acceptance Criteria Template for Jira User Stories

## User Story
**As a** [type of user/persona]
**I want** [goal/desire/feature]
**So that** [benefit/value/reason]

---

## Acceptance Criteria (Gherkin Format)

### Scenario 1: [Primary Happy Path]
```gherkin
Given [initial context/precondition]
  And [additional context if needed]
When [action/trigger event]
Then [expected outcome/result]
  And [additional outcomes if applicable]
```

### Scenario 2: [Alternative Flow]
```gherkin
Given [initial context]
When [alternative action]
Then [expected alternative outcome]
```

### Scenario 3: [Edge Case/Boundary Condition]
```gherkin
Given [edge case context]
When [edge case action]
Then [expected handling]
```

---

## Functional Requirements

### Core Functionality
- [ ] **FR1:** [Specific functional requirement]
  - Acceptance: [How to verify this requirement is met]
- [ ] **FR2:** [Another functional requirement]
  - Acceptance: [Verification criteria]
- [ ] **FR3:** [Additional requirement]
  - Acceptance: [Verification criteria]

### Data Requirements
- [ ] **DR1:** [Data input/output requirement]
  - Format: [Expected format]
  - Validation: [Validation rules]
- [ ] **DR2:** [Data persistence requirement]
  - Storage: [Where/how data is stored]
  - Retention: [Data retention policy]

---

## Non-Functional Requirements

### Performance Criteria
- [ ] **Response Time:** [Action] must complete within [X seconds]
- [ ] **Throughput:** System must handle [X concurrent users/requests]
- [ ] **Load Capacity:** [Specific load requirements]

### Security Requirements
- [ ] **Authentication:** [Auth requirements]
- [ ] **Authorization:** [Permission/role requirements]
- [ ] **Data Protection:** [Encryption/privacy requirements]

### Accessibility Requirements
- [ ] **WCAG Compliance:** Meets WCAG 2.1 Level [A/AA/AAA]
- [ ] **Screen Reader:** Compatible with [specific screen readers]
- [ ] **Keyboard Navigation:** All functions accessible via keyboard

---

## Business Rules & Constraints

### Business Logic
1. **BR1:** [Business rule description]
   - Condition: [When this applies]
   - Action: [What happens]
   - Exception: [Any exceptions]

2. **BR2:** [Another business rule]
   - Condition: [Application criteria]
   - Action: [Expected behavior]

### System Constraints
- **Technical Constraint:** [e.g., Must use existing API]
- **Business Constraint:** [e.g., Must comply with regulation X]
- **Timeline Constraint:** [e.g., Must be live before date Y]

---

## Error Handling & Edge Cases

### Error Scenarios
| Error Type | Trigger Condition | Expected Behavior | User Message |
|------------|------------------|-------------------|--------------|
| Validation Error | [Invalid input condition] | [System response] | "[User-friendly error message]" |
| System Error | [System failure condition] | [Graceful degradation] | "[Error message to user]" |
| Network Error | [Connection failure] | [Retry/fallback behavior] | "[Connectivity message]" |

### Edge Cases
- [ ] **Empty State:** How system behaves with no data
- [ ] **Maximum Capacity:** Behavior at system limits
- [ ] **Concurrent Actions:** Handling simultaneous operations
- [ ] **Data Conflicts:** Resolution strategy for conflicts

---

## UX/UI Considerations

### User Interface Requirements
- [ ] **UI1:** [Visual requirement]
  - Desktop: [Desktop-specific behavior]
  - Mobile: [Mobile-specific behavior]
  - Tablet: [Tablet-specific behavior]

### User Experience Flow
1. **Entry Point:** [How user accesses feature]
2. **Primary Path:** [Step-by-step user journey]
3. **Exit Points:** [How user completes/exits]
4. **Feedback Mechanisms:** [Loading states, confirmations, errors]

### Design Specifications
- **Component:** [Reusable component to use]
- **Style Guide:** [Reference to design system]
- **Mockup/Wireframe:** [Link to design file]

---

## Definition of Done Checklist

### Development Complete
- [ ] Code implementation complete
- [ ] Unit tests written and passing (>80% coverage)
- [ ] Code reviewed by at least 1 team member
- [ ] No critical or high-priority bugs
- [ ] Technical documentation updated

### Testing Complete
- [ ] All acceptance criteria scenarios pass
- [ ] Integration tests executed successfully
- [ ] Regression testing completed
- [ ] Performance benchmarks met
- [ ] Security scan completed (no critical vulnerabilities)
- [ ] Cross-browser testing completed
- [ ] Mobile responsiveness verified

### Quality Assurance
- [ ] Accessibility audit passed
- [ ] User acceptance testing (UAT) approved
- [ ] Analytics/tracking implemented
- [ ] Error monitoring configured
- [ ] Feature flags configured (if applicable)

### Documentation & Deployment
- [ ] User documentation/help text created
- [ ] Release notes prepared
- [ ] API documentation updated (if applicable)
- [ ] Deployment pipeline configured
- [ ] Rollback plan documented

---

## Test Data & Scenarios

### Test Data Requirements
```
Test User 1: [Persona/Role]
- Username: [test_user_1]
- Characteristics: [Key attributes]
- Test Purpose: [What this tests]

Test User 2: [Different Persona/Role]
- Username: [test_user_2]
- Characteristics: [Different attributes]
- Test Purpose: [What this tests]
```

### Critical Test Scenarios
1. **Positive Test:** [Happy path scenario]
2. **Negative Test:** [Failure scenario]
3. **Boundary Test:** [Edge case scenario]
4. **Integration Test:** [Cross-system scenario]

---

## Dependencies & Risks

### Dependencies
- [ ] **Internal:** [Team/system dependency]
  - Status: [Current status]
  - Owner: [Responsible party]
- [ ] **External:** [Third-party dependency]
  - Status: [Integration status]
  - Fallback: [Contingency plan]

### Identified Risks
| Risk | Probability | Impact | Mitigation Strategy |
|------|------------|---------|-------------------|
| [Risk description] | Low/Medium/High | Low/Medium/High | [How to address] |

---

## Acceptance Sign-off

### Stakeholder Approval
- [ ] Product Owner: _____________ Date: _______
- [ ] Technical Lead: _____________ Date: _______
- [ ] QA Lead: _____________ Date: _______
- [ ] UX/Design Lead: _____________ Date: _______

### Notes & Additional Context
```
[Any additional information, assumptions, or clarifications that don't fit in above sections]
```

---

## Example: E-commerce Cart Feature

### User Story Example
**As a** online shopper
**I want** to add items to my shopping cart
**So that** I can purchase multiple items in a single transaction

### Acceptance Criteria Example
```gherkin
Scenario 1: Successfully adding item to cart
Given I am viewing a product detail page
  And the product is in stock
  And I am logged into my account
When I click the "Add to Cart" button
Then the item should be added to my cart
  And the cart icon should update to show the new item count
  And I should see a confirmation message "Item added to cart"
  And the cart total should reflect the new item price

Scenario 2: Adding item when not logged in
Given I am viewing a product detail page
  And I am not logged in
When I click the "Add to Cart" button
Then the item should be added to a guest cart
  And I should see a prompt to login or continue as guest
  And the cart should persist for the session

Scenario 3: Adding out-of-stock item
Given I am viewing a product detail page
  And the product is out of stock
When I attempt to click the "Add to Cart" button
Then the button should be disabled
  And I should see the text "Out of Stock"
  And I should have the option to "Notify me when available"
```

---

## Template Usage Guidelines

### Best Practices
1. **Be Specific:** Avoid ambiguous terms like "user-friendly" or "fast"
2. **Make it Testable:** Each criterion should be verifiable as pass/fail
3. **Consider All Users:** Include different personas and accessibility needs
4. **Think Edge Cases:** Document boundary conditions and error scenarios
5. **Keep it Maintainable:** Update criteria as requirements evolve

### Common Pitfalls to Avoid
- ❌ Writing implementation details instead of behavior
- ❌ Creating criteria that can't be tested
- ❌ Forgetting non-functional requirements
- ❌ Ignoring error scenarios
- ❌ Missing accessibility requirements

### When to Use Each Section
- **Mandatory Sections:** User Story, Acceptance Criteria, Definition of Done
- **Recommended Sections:** Business Rules, Error Handling, UX/UI Considerations
- **Optional Sections:** Test Data, Dependencies (include when relevant)

---

*Template Version: 2.0*
*Last Updated: [Current Date]*
*Maintained by: Product Management Team*