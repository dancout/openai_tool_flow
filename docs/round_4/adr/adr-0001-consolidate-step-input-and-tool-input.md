---
title: "ADR-0001: Consolidate StepInput and ToolInput Classes"
status: "Accepted"
date: "2024-12-19"
authors: "GitHub Copilot"
tags: ["architecture", "decision", "interfaces", "consolidation"]
supersedes: ""
superseded_by: ""
adr_references: []
used_as_resource_in: []
---

# ADR-0001: Consolidate StepInput and ToolInput Classes

## Status

Proposed | **Accepted** | Rejected | Superseded | Deprecated

## Context

The codebase had two similar classes for representing tool inputs:
- `ToolInput`: An abstract base class for strongly-typed tool inputs
- `StepInput`: A concrete class extending ToolInput with system fields and custom data

This duplication created confusion about which class to use when, especially in the example code where concrete implementations were extending ToolInput directly rather than StepInput. The TODO comment in the code explicitly questioned whether StepInput should be the base or if ToolInput should be concrete.

Additionally, the system had issues with:
- Redundant setting of typedInput to stepInput in _executeStep function
- Converting structured Issue objects to Maps unnecessarily early
- Including all previous issues instead of only relevant ones
- Manual ToolResult construction instead of using copyWith pattern

## Decision

Consolidate StepInput and ToolInput by making ToolInput a concrete class that encompasses all the functionality previously split between the two classes:

1. **Make ToolInput concrete**: Convert ToolInput from abstract to concrete class with all fields from StepInput
2. **Create type alias**: Make StepInput a typedef to ToolInput for backward compatibility
3. **Use structured Issue objects**: Change previousIssues from `List<Map<String, dynamic>>` to `List<Issue>`
4. **Filter previous issues**: Only include issues from steps specified in includeOutputsFrom
5. **Add copyWith method**: Add copyWith to ToolResult and use it consistently
6. **Improve sanitization order**: Sanitize output before creating typedOutput

## Consequences

### Positive

- **POS-001**: Eliminates confusion between StepInput and ToolInput usage patterns
- **POS-002**: Maintains backward compatibility through type alias
- **POS-003**: Improves type safety by using structured Issue objects longer
- **POS-004**: Reduces noise in previous issues by filtering to relevant steps only
- **POS-005**: Provides cleaner ToolResult modification pattern with copyWith
- **POS-006**: Ensures typedOutput is created from sanitized data

### Negative

- **NEG-001**: Slight increase in ToolInput complexity by absorbing StepInput fields
- **NEG-002**: Requires updating import statements in some places
- **NEG-003**: Changes internal data flow for previous issues handling

## Alternatives Considered

### Keep Both Classes Separate

- **ALT-001**: **Description**: Maintain StepInput and ToolInput as separate classes with clearer boundaries
- **ALT-002**: **Rejection Reason**: Would not address the fundamental confusion about which class to use when, and would require more extensive refactoring of example code

### Make StepInput the Base Class

- **ALT-003**: **Description**: Make StepInput the concrete base and ToolInput abstract
- **ALT-004**: **Rejection Reason**: Would break existing concrete implementations that extend ToolInput directly

## Implementation Notes

- **IMP-001**: All existing functionality preserved through type alias and method compatibility
- **IMP-002**: New tests added to verify ToolInput works with structured Issue objects
- **IMP-003**: _buildStepInput method updated to filter issues based on includeOutputsFrom configuration
- **IMP-004**: Output sanitization moved before typedOutput creation in _executeStep

## References

- **REF-001**: docs/round_4/REQUESTED_UPDATES.md - Original requirements
- **REF-002**: lib/src/typed_interfaces.dart - Updated interface definitions
- **REF-003**: lib/src/tool_flow.dart - Updated flow execution logic