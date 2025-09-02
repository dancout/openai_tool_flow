## Round 13 Implementation Summary

This implementation successfully fulfills all the requirements from Round 13:

### Key Changes

1. **Replaced `includeOutputsFrom` with `includeResultsInToolcall`**
   - StepConfig now accepts `includeResultsInToolcall` parameter
   - Supports both step indices (int) and tool names (String)
   - Includes both tool outputs and their associated issues

2. **Added Severity Filtering**
   - New `issuesSeverityFilter` parameter in StepConfig
   - Defaults to `IssueSeverity.high` (includes high and critical issues)
   - Only includes results if they have issues matching the severity filter

3. **System Message Integration**
   - Previous results and filtered issues are included in OpenAI system messages
   - Follows the exact format specified in requirements
   - Only adds content when there are relevant issues

### Usage Example

```dart
// Step 1: Generate colors with potential issues
ToolCallStep(
  toolName: 'generate_colors',
  stepConfig: StepConfig(
    audits: [ColorValidationAudit()], // Creates high severity issues
  ),
),

// Step 2: Refine colors with context from step 1
ToolCallStep(
  toolName: 'refine_colors', 
  stepConfig: StepConfig(
    includeResultsInToolcall: [0], // Include step 0
    issuesSeverityFilter: IssueSeverity.high, // Only high+ severity
  ),
),
```

### System Message Output

When step 2 executes, the OpenAI system message will include:

```
Previous step results and associated issues:
  Step: generate_colors -> Output keys: colors, confidence
    Associated issues:
      - HIGH: Color harmony needs improvement
        Suggestions: Use complementary colors, Check color contrast
      - CRITICAL: Invalid hex format detected
        Suggestions: Validate hex codes
```

### Testing

- All 72 tests pass
- Added comprehensive tests for severity filtering
- Added tests for system message generation
- Verified both step index and tool name references work correctly

### Documentation

- Created ADR-0001 documenting all architectural decisions
- Updated ADR appendix with new entry
- No linting errors introduced