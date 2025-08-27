---
title: "ADR-0002: Implement Selective Previous Issues Inclusion"
status: "Accepted"
date: "2024-12-19"
authors: "GitHub Copilot"
tags: ["architecture", "decision", "data-flow", "optimization"]
supersedes: ""
superseded_by: ""
adr_references: []
used_as_resource_in: []
---

# ADR-0002: Implement Selective Previous Issues Inclusion

## Status

Proposed | **Accepted** | Rejected | Superseded | Deprecated

## Context

The original implementation included ALL previous issues from ALL executed steps in the previousIssues field when building step input. This created unnecessary noise and potentially irrelevant context for tool execution, especially in complex workflows where early steps might have issues that don't impact later specialized steps.

The system was already carefully choosing which previous outputs to carry forward through the includeOutputsFrom configuration, but this selective inclusion did not extend to issues.

## Decision

Modify the _buildStepInput function to only include issues from steps that are specified in the includeOutputsFrom configuration:

1. **Filter issues by included steps**: When includeOutputsFrom is configured, only include issues from those specific steps
2. **Maintain backward compatibility**: When includeOutputsFrom is not configured, include all previous issues as before
3. **Add helper method**: Create _getIncludedResults method to centralize the logic for determining which results to include

## Consequences

### Positive

- **POS-001**: Reduces noise in tool inputs by providing only relevant contextual issues
- **POS-002**: Aligns issue inclusion with output inclusion strategy for consistency
- **POS-003**: Improves tool performance by reducing irrelevant context in API calls
- **POS-004**: Maintains existing behavior when includeOutputsFrom is not specified

### Negative

- **NEG-001**: Potentially loses some contextual information that might be relevant across step boundaries
- **NEG-002**: Adds complexity to the step input building logic
- **NEG-003**: Requires careful configuration to ensure relevant issues are not excluded

## Alternatives Considered

### Manual Issue Filtering Configuration

- **ALT-001**: **Description**: Add separate includeIssuesFrom configuration parameter
- **ALT-002**: **Rejection Reason**: Would add complexity and configuration overhead when the existing includeOutputsFrom already provides logical grouping

### Global Issue History Retention

- **ALT-003**: **Description**: Keep all previous issues but add metadata to indicate relevance
- **ALT-004**: **Rejection Reason**: Would not reduce the noise problem and would add complexity to downstream processing

## Implementation Notes

- **IMP-001**: _getIncludedResults helper method handles both int (step index) and String (tool name) references
- **IMP-002**: Issue filtering respects the same inclusion rules as output forwarding
- **IMP-003**: Backward compatibility maintained when includeOutputsFrom is empty or not specified

## References

- **REF-001**: docs/round_4/REQUESTED_UPDATES.md - Original requirement for selective issue inclusion
- **REF-002**: lib/src/tool_flow.dart - _buildStepInput and _getIncludedResults implementation
- **REF-003**: lib/src/step_config.dart - includeOutputsFrom configuration