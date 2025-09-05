---
title: "ADR-0001: ToolFlow API Modernization and Input Handling Enhancement"
status: "Accepted"
date: "2025-01-27"
authors: "Development Team"
tags: ["architecture", "decision", "toolflow", "api", "input-handling"]
supersedes: ""
superseded_by: ""
adr_references: ["ADR-0001-dynamic-input-builder-pattern", "ADR-0001-include-results-in-toolcall-with-severity-filtering"]
used_as_resource_in: []
---

# ADR-0001: ToolFlow API Modernization and Input Handling Enhancement

## Status

Proposed | **Accepted** | Rejected | Superseded | Deprecated

## Context

The ToolFlow system required several API enhancements to improve usability and consistency. The existing implementation had several limitations:

1. **Static Input Dependencies**: The `buildInputsFrom` parameter required explicit selection of which previous results to pass to `inputBuilder`, creating unnecessary complexity
2. **Required InputBuilder**: All steps required an `inputBuilder` function even for simple pass-through scenarios
3. **Optional Input Parameter**: The `ToolFlow.run()` method had an optional input parameter, making it unclear when input was actually needed
4. **Mixed Reference Types**: `includeResultsInToolcall` accepted both integers and strings, creating inconsistency
5. **Missing Token Tracking**: No mechanism to track OpenAI API token usage per step
6. **Required Model Parameter**: Every step required a model specification even when using default

## Decision

Implement a comprehensive API modernization with the following changes:

1. **Make inputBuilder optional**: When not provided, automatically pass the previous step's output as input using `toMap()`
2. **Require input parameter**: Make `ToolFlow.run(input:)` a required parameter and create an initial `TypedToolResult` from it
3. **Simplify previous results access**: Remove `buildInputsFrom` and pass all previous results to `inputBuilder`
4. **Standardize index-based references**: Change `includeResultsInToolcall` to only accept integers (step indices)
5. **Add per-step token limits**: Add optional `maxTokens` to `StepConfig`
6. **Make model optional**: Allow `ToolCallStep.model` to be optional with fallback to `OpenAIConfig`
7. **Track token usage**: Implement token usage tracking in `ToolFlow._state` via enhanced `ToolCallResponse`

## Consequences

### Positive

- **POS-001**: Simplified API reduces boilerplate code for common scenarios where steps pass output directly
- **POS-002**: Required input parameter makes the flow entry point more explicit and clear
- **POS-003**: All previous results available to inputBuilder enables more flexible input construction
- **POS-004**: Index-based references provide consistent, predictable ordering (input=0, step1=1, step2=2, etc.)
- **POS-005**: Per-step token limits and usage tracking enable better cost control and monitoring
- **POS-006**: Optional model parameter reduces redundancy when using consistent models

### Negative

- **NEG-001**: Breaking changes require updating all existing code that uses the ToolFlow API
- **NEG-002**: Results array now includes initial input, changing expected indices in existing code
- **NEG-003**: Index-based references are less descriptive than tool names but more predictable
- **NEG-004**: Enhanced service interface requires updating all mock implementations

## Alternatives Considered

### Keep buildInputsFrom with Index-Only References

- **ALT-001**: **Description**: Retain `buildInputsFrom` but limit it to integer indices only
- **ALT-002**: **Rejection Reason**: Still adds unnecessary complexity when most steps need access to all previous results

### Optional Input with Backward Compatibility

- **ALT-003**: **Description**: Keep input parameter optional and maintain old behavior
- **ALT-004**: **Rejection Reason**: Creates ambiguity about when input is needed and complicates initial result handling

### Separate Token Tracking Interface

- **ALT-005**: **Description**: Create a separate service interface for token tracking instead of enhancing ToolCallResponse
- **ALT-006**: **Rejection Reason**: Would complicate the service interface and require additional dependency injection

## Implementation Notes

- **IMP-001**: Initial input becomes index 0 in results array, with tool step results starting at index 1
- **IMP-002**: Default inputBuilder behavior passes `previousResults.last.output.toMap()` when no custom builder provided
- **IMP-003**: Token usage stored in `_state` map with keys like `step_{index}_usage` containing OpenAI usage structure
- **IMP-004**: Service interface returns `ToolCallResponse` with both output and usage information
- **IMP-005**: All existing tests updated to account for new result indexing and API changes

## References

- **REF-001**: Round 16 REQUESTED_UPDATES.md requirements
- **REF-002**: ADR-0001 Dynamic Input Builder Pattern (Round 6)
- **REF-003**: ADR-0001 Include Results in ToolCall with Severity Filtering (Round 13)
- **REF-004**: OpenAI API response structure in docs/open_ai_response_body.json