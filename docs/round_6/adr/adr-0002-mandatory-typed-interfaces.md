---
title: "ADR-0002: Mandatory Typed Interfaces for ToolResult"
status: "Proposed"
date: "2024-12-19"
authors: ["AI Assistant", "Package Maintainer"]
tags: ["architecture", "type-safety", "interfaces", "ToolResult"]
supersedes: ""
superseded_by: ""
adr_references: []
used_as_resource_in: []
---

# ADR-0002: Mandatory Typed Interfaces for ToolResult

## Status

**Proposed** | Accepted | Rejected | Superseded | Deprecated

## Context

The current ToolResult implementation has a dual approach to input/output handling:

1. **Map-based fields**: `final Map<String, dynamic> input;` and `final Map<String, dynamic> output;`
2. **Optional typed fields**: `final ToolInput? typedInput;` and `final ToolOutput? typedOutput;`

This creates several problems:

1. **Data Redundancy**: We store the same data twice - once in Map form and once in typed form
2. **Inconsistent Usage**: Code sometimes uses Map fields, sometimes typed fields
3. **Lost Type Safety**: Map-based access loses compile-time type checking
4. **Conversion Overhead**: Constant conversion between Map and typed forms
5. **Interface Confusion**: Users don't know which interface to use

The Round 6 requirements specifically call for:
- Making TypedInput and TypedOutput required (not optional)
- Removing the redundant Map-based input/output fields
- Using ToolInput.toMap() only when actually needed for serialization

## Decision

**Replace optional typed interfaces with required typed interfaces in ToolResult.**

### Core Changes

1. **Remove**: `final Map<String, dynamic> input;` and `final Map<String, dynamic> output;`
2. **Replace with**: `final ToolInput input;` (required) and `final ToolOutput output;` (required)
3. **Update**: All ToolResult creation to provide typed interfaces
4. **Update**: Serialization methods to call .toMap() only when needed
5. **Update**: All consumers to use typed interfaces directly

### Interface Contract

- **ToolResult Constructor**: Both input and output parameters are required, no more optional typedInput/typedOutput
- **Serialization**: `toJson()` calls `input.toMap()` and `output.toMap()` for JSON serialization
- **Type Safety**: All access to input/output data goes through typed interfaces
- **Backward Compatibility**: Breaking change acceptable per Round 6 requirements (version 0.0)

### Migration Pattern

```dart
// Before (Round 5)
ToolResult(
  toolName: 'example',
  input: {'key': 'value'},
  output: {'result': 'data'},
  typedInput: exampleInput,
  typedOutput: exampleOutput,
)

// After (Round 6)
ToolResult(
  toolName: 'example',
  input: exampleInput,    // Required ToolInput
  output: exampleOutput,  // Required ToolOutput
)
```

## Consequences

### Positive

- **POS-001**: Eliminates data redundancy between Map and typed fields
- **POS-002**: Enforces type safety throughout the system
- **POS-003**: Simplifies ToolResult interface with single source of truth
- **POS-004**: Reduces memory usage by eliminating duplicate data storage
- **POS-005**: Prevents inconsistent usage patterns between Map and typed access

### Negative

- **NEG-001**: Breaking change requiring updates to all ToolResult creation sites
- **NEG-002**: Forces all tools to have typed input/output definitions
- **NEG-003**: May require creating simple typed wrappers for basic Map-based tools
- **NEG-004**: Removes flexibility for tools that don't need structured interfaces

## Alternatives Considered

### Keep Both Interfaces with Synchronization

- **ALT-001**: **Description**: Maintain both Map and typed fields, keep them synchronized
- **ALT-002**: **Rejection Reason**: Increases complexity, still has redundancy, prone to synchronization bugs

### Make Maps Computed Properties

- **ALT-003**: **Description**: Remove Map fields, add computed getters that call .toMap()
- **ALT-004**: **Rejection Reason**: Still redundant computation, doesn't solve interface confusion

### Gradual Migration Approach

- **ALT-005**: **Description**: Deprecate Map fields gradually while keeping backward compatibility
- **ALT-006**: **Rejection Reason**: Round 6 explicitly allows breaking changes; gradual migration adds complexity

## Implementation Notes

- **IMP-001**: All tool implementations must provide concrete ToolInput and ToolOutput subclasses
- **IMP-002**: Mock services need to return proper typed interfaces, not just Map data
- **IMP-003**: Serialization performance may improve due to elimination of duplicate data
- **IMP-004**: ToolOutputRegistry becomes mandatory for proper system operation

## References

- **REF-001**: Round 6 REQUESTED_UPDATES.md - "Update the ToolResult to require a TypedInput and TypedOutput"
- **REF-002**: Current ToolResult implementation with dual interfaces
- **REF-003**: ToolInput.toMap() redundancy mentioned in requirements