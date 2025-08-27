---
title: "ADR-0003: Improve Output Sanitization and ToolResult Modification Patterns"
status: "Accepted"
date: "2024-12-19"
authors: "GitHub Copilot"
tags: ["architecture", "decision", "data-processing", "api-design"]
supersedes: ""
superseded_by: ""
adr_references: []
used_as_resource_in: []
---

# ADR-0003: Improve Output Sanitization and ToolResult Modification Patterns

## Status

Proposed | **Accepted** | Rejected | Superseded | Deprecated

## Context

The original implementation had two issues with output processing:

1. **Sanitization Order**: Output sanitization was happening AFTER typedOutput creation, meaning the typed output could be created from unsanitized data that might not match expected schemas
2. **ToolResult Modification**: When applying sanitization, the code manually constructed new ToolResult objects instead of using a more maintainable copyWith pattern

This created potential inconsistencies between sanitized output and typed output, and made ToolResult modifications more error-prone and verbose.

## Decision

Implement two improvements to output processing:

1. **Move sanitization before typedOutput creation**: Apply output sanitization immediately after receiving response from OpenAI service, before creating typedOutput
2. **Add copyWith method to ToolResult**: Provide a copyWith method for clean, maintainable ToolResult modifications
3. **Update sanitization flow**: Remove redundant sanitization in the main execution loop since it's now handled in _executeStep

## Consequences

### Positive

- **POS-001**: Ensures typedOutput is always created from properly sanitized data
- **POS-002**: Provides cleaner, less error-prone ToolResult modification pattern
- **POS-003**: Reduces code duplication in ToolResult construction
- **POS-004**: Maintains separation of concerns with sanitization happening at data ingress point

### Negative

- **NEG-001**: Slightly changes the order of operations in step execution
- **NEG-002**: Requires updating any code that manually constructs ToolResult modifications
- **NEG-003**: copyWith method adds to ToolResult API surface area

## Alternatives Considered

### Keep Sanitization After Typed Creation

- **ALT-001**: **Description**: Maintain current order but update typed output after sanitization
- **ALT-002**: **Rejection Reason**: Would require recreating typed output, adding complexity and potential for data loss

### Immutable Builder Pattern

- **ALT-003**: **Description**: Implement full builder pattern for ToolResult construction
- **ALT-004**: **Rejection Reason**: Would be overkill for the current use cases and add significant complexity

## Implementation Notes

- **IMP-001**: copyWith method supports optional parameters for all ToolResult fields
- **IMP-002**: Output sanitization moved to _executeStep method before typedOutput creation
- **IMP-003**: Redundant sanitization logic removed from main execution loop
- **IMP-004**: All existing tests pass, ensuring backward compatibility

## References

- **REF-001**: docs/round_4/REQUESTED_UPDATES.md - Original requirements for sanitization improvements
- **REF-002**: lib/src/tool_result.dart - copyWith method implementation  
- **REF-003**: lib/src/tool_flow.dart - Updated sanitization flow in _executeStep