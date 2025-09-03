---
title: "ADR-0003: Generic ToolCallStep Implementation for True Type Safety"
status: "Accepted"
date: "2025-01-01"
authors: "GitHub Copilot"
tags: ["architecture", "generics", "type-safety", "breaking-change", "toolflow"]
supersedes: ""
superseded_by: ""
adr_references: ["ADR-0001", "ADR-0002"]
used_as_resource_in: []
---

# ADR-0003: Generic ToolCallStep Implementation for True Type Safety

## Status

Proposed | **Accepted** | Rejected | Superseded | Deprecated

## Context

In Round 8, ADR-0002 rejected implementing generic ToolCallStep (ALT-003/ALT-004) with the reasoning that it "Would be a breaking change requiring all existing code to specify type parameters and complicates flow composition". However, this rejection reason is no longer acceptable given the current project requirements.

The current implementation using TypedToolResult wrapper pattern, while functional, has several limitations:
1. **Runtime Type Checking**: Type safety is achieved at runtime rather than compile time
2. **Wrapper Complexity**: Additional API surface area with TypedToolResult wrapper
3. **Limited Type Propagation**: inputBuilder still receives `List<ToolResult>` without specific type information
4. **Inconsistent Type Safety**: Some parts of the system are type-safe while others rely on casting

The project has explicitly stated that:
- This is version 0.0.x, so backwards compatibility is not a concern
- Breaking changes are acceptable and encouraged
- Refactoring requirements should not prevent implementing proper type safety

## Decision

**Implement generic ToolCallStep with compile-time type propagation throughout the flow.**

### Core Changes

1. **Generic ToolCallStep**: `ToolCallStep<T extends ToolOutput>`
2. **Typed Input Builder**: Replace `List<ToolResult>` with properly typed parameters
3. **Type-Safe Flow Composition**: ToolFlow maintains type information throughout execution
4. **Simplified Type System**: Remove or simplify TypedToolResult wrapper since true generics handle type safety

### Implementation Strategy

#### Phase 1: Make ToolCallStep Generic
```dart
class ToolCallStep<T extends ToolOutput> {
  final String toolName;
  final String model;
  final Map<String, dynamic> Function(List<ToolResult>) inputBuilder;
  // ... other fields
}
```

#### Phase 2: Type-Safe Flow Execution
- ToolFlow stores generic steps: `List<ToolCallStep<dynamic>>`
- Execution maintains type information through ToolOutputRegistry
- Results are properly typed at each step

#### Phase 3: Enhanced Type Propagation
- inputBuilder parameters can be made more type-specific
- Audit execution uses compile-time generic types
- Registry system supports proper type resolution

## Consequences

### Positive

- **POS-001**: **True Compile-Time Type Safety**: Eliminates runtime type checking in favor of compile-time guarantees
- **POS-002**: **Simplified API Surface**: Removes wrapper pattern complexity
- **POS-003**: **Better Developer Experience**: IDE autocomplete and error detection at compile time
- **POS-004**: **Type Propagation**: Input builders and audits receive properly typed parameters
- **POS-005**: **Consistent Type System**: All parts of the system use the same type-safe approach

### Negative

- **NEG-001**: **Breaking Change**: All existing code must be updated to specify type parameters
- **NEG-002**: **Migration Effort**: Requires updating all ToolCallStep usages
- **NEG-003**: **Generic Complexity**: Developers must understand generic syntax and type constraints
- **NEG-004**: **Flow Composition**: Mixed-type flows require careful type handling

## Alternatives Considered

### Keep TypedToolResult Wrapper Pattern

- **ALT-001**: **Description**: Continue with the current TypedToolResult wrapper approach
- **ALT-002**: **Rejection Reason**: Does not provide compile-time type safety and adds unnecessary complexity

### Gradual Migration Approach

- **ALT-003**: **Description**: Implement generic ToolCallStep alongside existing non-generic version
- **ALT-004**: **Rejection Reason**: Would create API inconsistency and confusion; clean break is preferred

### Abstract Base Class Hierarchy

- **ALT-005**: **Description**: Create typed subclasses of ToolCallStep instead of using generics
- **ALT-006**: **Rejection Reason**: Less flexible than generics and doesn't solve the core type propagation issues

## Implementation Notes

- **IMP-001**: Use Dart's generic type system with proper bounds (`T extends ToolOutput`)
- **IMP-002**: Leverage ToolOutputRegistry for runtime type resolution where needed
- **IMP-003**: Maintain fromStepDefinition factory method with automatic type propagation
- **IMP-004**: Update all existing tests to use generic syntax
- **IMP-005**: Provide clear migration examples for common usage patterns

## Migration Path

### Before (Round 8 Implementation)
```dart
final step = ToolCallStep(
  toolName: 'extract_palette',
  model: 'gpt-4',
  inputBuilder: (results) => {'image': 'data'},
  stepConfig: StepConfig(),
  outputSchema: paletteSchema,
);
```

### After (Round 14 Implementation)
```dart
final step = ToolCallStep<PaletteExtractionOutput>(
  toolName: 'extract_palette',
  model: 'gpt-4',
  inputBuilder: (results) => {'image': 'data'},
  stepConfig: StepConfig(),
  outputSchema: paletteSchema,
);

// Or using StepDefinition (preferred)
final step = ToolCallStep.fromStepDefinition(
  PaletteExtractionStepDefinition(),
  model: 'gpt-4',
  inputBuilder: (results) => {'image': 'data'},
);
```

## References

- **REF-001**: ADR-0001: Refactor ToolFlow Orchestration for Per-Step Generic Typing
- **REF-002**: ADR-0002: TypedToolResult Wrapper Implementation for Per-Step Generic Typing
- **REF-003**: Round 14 REQUESTED_UPDATES.md: Generic typing implementation requirements
- **REF-004**: [Dart Generics Documentation](https://dart.dev/guides/language/language-tour#generics)