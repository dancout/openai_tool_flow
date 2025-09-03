---
title: "ADR-0001: Replace includeOutputsFrom with includeResultsInToolcall and Severity Filtering"
status: "Proposed"
date: "2025-01-27"
authors: "Copilot Agent"
tags: ["stepconfig", "severity-filtering", "system-messages", "toolflow"]
supersedes: ""
superseded_by: ""
adr_references: []
used_as_resource_in: []
---

# ADR-0001: Replace includeOutputsFrom with includeResultsInToolcall and Severity Filtering

## Status

Proposed | **Accepted** | Rejected | Superseded | Deprecated

## Context

The current `StepConfig` implementation has an `includeOutputsFrom` parameter that allows including outputs from previous steps, but it lacks the ability to include associated issues and filter them by severity. This creates two problems:

1. **Lack of Issue Context**: Tool calls don't receive information about issues from previous steps, potentially causing repeated problems
2. **Token Bloat**: There's no way to filter which issues are relevant, leading to potential token waste when including all previous results and issues

The requirement is to replace `includeOutputsFrom` with a new `includeResultsInToolcall` parameter that includes both tool outputs and their associated issues, with optional severity-level filtering to control what gets included in the OpenAI system messages.

The goal is to provide context like "here's what you did previously and why it was wrong" while avoiding irrelevant information that would bloat the token count.

## Decision

Replace the `includeOutputsFrom` parameter in `StepConfig` with `includeResultsInToolcall` that supports:

1. **Step Reference Support**: Continue supporting step indices (int) and tool names (String) for identifying which previous results to include
2. **Severity Filtering**: Add optional `IssueSeverity` level filtering with a default of `IssueSeverity.high`
3. **System Message Integration**: Include filtered results and issues in the OpenAI system message using a consistent, readable format
4. **Consolidated Logic**: Create a reusable helper method similar to `_getInputBuilderResults` to avoid code duplication

The implementation will:
- Parse the list of step references (int/String) to identify relevant previous results
- Filter issues by the specified severity level (medium and higher if severity is medium)
- Format the results and filtered issues into the system message in a structured way
- Only include content if there are actually issues matching the severity filter

## Consequences

### Positive

- **POS-001**: Provides context to OpenAI tool calls about previous problems, reducing likelihood of repeated issues
- **POS-002**: Severity filtering prevents token bloat by only including relevant high-priority issues
- **POS-003**: Consolidated logic reduces code duplication between input building and result inclusion
- **POS-004**: Maintains backward compatibility for step reference syntax (int/String)
- **POS-005**: Clear separation between tool outputs and associated issues in system messages

### Negative

- **NEG-001**: Breaking change requiring updates to existing code using `includeOutputsFrom`
- **NEG-002**: Increases complexity of `StepConfig` with additional parameter
- **NEG-003**: May increase system message size when including previous results and issues
- **NEG-004**: Requires careful testing to ensure severity filtering works correctly

## Alternatives Considered

### Keep includeOutputsFrom and Add Separate Issues Parameter

- **ALT-001**: **Description**: Maintain `includeOutputsFrom` and add a separate `includeIssuesFrom` parameter
- **ALT-002**: **Rejection Reason**: Would create confusion about which outputs have issues and require separate configuration for related functionality

### Global Issue Context Instead of Per-Step

- **ALT-003**: **Description**: Provide global issue context to all steps rather than selective inclusion
- **ALT-004**: **Rejection Reason**: Would cause token bloat and include irrelevant issues that don't apply to current step

### Custom Formatter Function

- **ALT-005**: **Description**: Allow users to provide custom formatting functions for how results/issues appear in system messages
- **ALT-006**: **Rejection Reason**: Adds unnecessary complexity when a standard format should suffice

## Implementation Notes

- **IMP-001**: Default severity level set to `IssueSeverity.high` to include high and critical issues
- **IMP-002**: If no issues match the severity filter for included results, nothing is added to system message
- **IMP-003**: Format follows the pattern shown in the requirements: step info, output keys, and nested issue details
- **IMP-004**: Consolidate result resolution logic into a reusable helper method `_getIncludedResults`
- **IMP-005**: All existing tests using `includeOutputsFrom` must be updated to use `includeResultsInToolcall`

## References

- **REF-001**: Round 13 REQUESTED_UPDATES.md requirements
- **REF-002**: Existing `_getInputBuilderResults` method in `ToolFlow` class
- **REF-003**: `IssueSeverity` enum for filtering logic