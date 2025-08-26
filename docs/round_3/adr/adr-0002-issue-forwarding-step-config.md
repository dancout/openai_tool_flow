---
title: "ADR-0002: Issue Forwarding and Step Configuration Enhancement"
status: "Proposed"
date: "2024-12-19"
authors: ["AI Assistant", "Package Maintainer"]
tags: ["architecture", "configuration", "issue-forwarding", "state-management"]
supersedes: ""
superseded_by: ""
---

# ADR-0002: Issue Forwarding and Step Configuration Enhancement

## Status

**Proposed**

## Context

The current implementation passes all issues and outputs from previous steps to subsequent steps, which leads to token bloat and noise. Users need selective forwarding where:

- Step 1 issues may be relevant to steps 2 & 3, but not step 4
- Some steps need outputs from multiple previous steps
- Issues need to be paired with their associated outputs for context
- Step configuration is currently matched by index, creating fragile coupling

Additional requirements:
- Output sanitization between steps (configurable transformation)
- Direct StepConfig integration into ToolCallStep
- Tool name-based result retrieval for easier access
- Removal of global audits in favor of per-step configuration

## Decision

**Implement selective issue/output forwarding with enhanced StepConfig integration.**

The solution provides:

1. **Selective Forwarding**: Configure which previous step outputs/issues are passed to each step
2. **Output Sanitization**: Optional transformation of step outputs before use as inputs
3. **Direct StepConfig Integration**: Embed StepConfig directly in ToolCallStep
4. **Tool Name Keying**: Enable result retrieval by tool name
5. **Multi-Step Input Composition**: Allow step inputs from multiple previous outputs
6. **Remove Global Audits**: All audits specified at StepConfig level

## Consequences

### Positive

- **POS-001**: **Token Efficiency**: Reduced token usage by filtering irrelevant issues/outputs
- **POS-002**: **Context Preservation**: Issues maintain association with their outputs
- **POS-003**: **Configuration Clarity**: StepConfig directly coupled with ToolCallStep
- **POS-004**: **Flexible Composition**: Steps can compose inputs from multiple sources
- **POS-005**: **Clean Architecture**: No global audit configuration
- **POS-006**: **Easy Retrieval**: Tool name-based result access

### Negative

- **NEG-001**: **Configuration Complexity**: More configuration options to manage
- **NEG-002**: **Breaking Changes**: Significant API changes required
- **NEG-003**: **Memory Usage**: Potentially more complex state management

## Alternatives Considered

### Global Filtering Rules

- **ALT-001**: **Description**: Apply filtering rules globally rather than per-step
- **ALT-002**: **Rejection Reason**: Less flexible and doesn't address step-specific needs

### Separate Configuration Object

- **ALT-003**: **Description**: Keep StepConfig separate from ToolCallStep
- **ALT-004**: **Rejection Reason**: Maintains fragile index-based coupling

## Implementation Notes

- **IMP-001**: **Forward Configuration**: Add fields to specify which steps' outputs/issues to forward
- **IMP-002**: **Sanitization Functions**: Optional transformation functions in StepConfig
- **IMP-003**: **Result Keying**: Maintain both list and map-based result access
- **IMP-004**: **Backward Compatibility**: Provide migration helpers for existing code
- **IMP-005**: **Validation**: Ensure referenced steps exist and prevent circular dependencies

## References

- **REF-001**: REQUESTED_UPDATES.md Round 3 user-defined requests
- **REF-002**: Token optimization best practices for LLMs
- **REF-003**: Configuration management patterns