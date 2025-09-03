---
title: "ADR-0002: TypedToolResult Wrapper Implementation for Per-Step Generic Typing"
status: "Accepted"
date: "2024-12-19"
authors: "GitHub Copilot"
tags: ["architecture", "decision", "generics", "type-safety", "audit-execution", "toolflow"]
supersedes: ""
superseded_by: ""
adr_references: ["ADR-0001"]
used_as_resource_in: ["ADR-0003"]
---

# ADR-0002: TypedToolResult Wrapper Implementation for Per-Step Generic Typing

## Status

Proposed | **Accepted** | Rejected | Superseded | Deprecated

## Context

The ToolFlow orchestration system required per-step generic typing to enable type-safe audit execution as outlined in ADR-0001. The challenge was that Dart's type system does not allow heterogeneous generic collections without losing type information. Specifically, storing `ToolResult<PaletteOutput>` and `ToolResult<ThemeOutput>` in the same collection required type erasure to `ToolResult<ToolOutput>`, which broke type safety for audits expecting specific output types.

Additionally, Dart generics are not covariant, meaning `ToolResult<ToolOutput>` cannot be cast to `ToolResult<PaletteOutput>` even if the actual output is of the correct type. This created a fundamental challenge for maintaining type safety while supporting heterogeneous tool flows.

## Decision

Implement a **TypedToolResult wrapper pattern** with **enhanced ToolOutputRegistry** to achieve per-step generic typing while maintaining backward compatibility and working within Dart's type system constraints.

The solution consists of:

1. **TypedToolResult wrapper class**: Encapsulates `ToolResult<ToolOutput>` while preserving runtime type information
2. **Enhanced ToolOutputRegistry**: Tracks type mappings from tool names to expected output types
3. **Runtime type-safe audit execution**: Audits perform runtime type checking for safe access to specific output types
4. **Backward compatible interfaces**: All existing APIs continue to work with `ToolResult<ToolOutput>`

## Consequences

### Positive

- **POS-001**: Enables type-safe audit execution with proper runtime type checking and error handling
- **POS-002**: Maintains full backward compatibility with existing ToolFlow and audit interfaces
- **POS-003**: Works within Dart's type system constraints without requiring unsafe casting or dynamic operations
- **POS-004**: Provides heterogeneous result storage while preserving access to common fields (toolName, issues, etc.)
- **POS-005**: Enables compile-time type safety for new audit implementations through runtime type verification

### Negative

- **NEG-001**: Adds a wrapper layer that increases API surface area and conceptual complexity
- **NEG-002**: Requires runtime type checking in audits instead of compile-time type guarantees
- **NEG-003**: Audit functions must handle type mismatch scenarios explicitly
- **NEG-004**: Cannot provide true compile-time type safety for audit parameters due to Dart's type system limitations

## Alternatives Considered

### Dynamic Storage with Type Casting

- **ALT-001**: **Description**: Store results as `List<dynamic>` and cast at runtime based on registry information
- **ALT-002**: **Rejection Reason**: Loses type safety for common field access and violates requirement to avoid `List<dynamic>` storage

### Generic ToolCallStep with Type Parameters

- **ALT-003**: **Description**: Make `ToolCallStep<T extends ToolOutput>` generic and propagate types through the flow
- **ALT-004**: **Rejection Reason**: Would be a breaking change requiring all existing code to specify type parameters and complicates flow composition

### Union Type Approach

- **ALT-005**: **Description**: Create a union type that can hold different `ToolResult<T>` types with type-safe accessors
- **ALT-006**: **Rejection Reason**: Dart lacks native union types, and implementing a custom union would be more complex than the wrapper pattern

### Audit Interface Redesign

- **ALT-007**: **Description**: Redesign audits to work directly with typed outputs instead of full `ToolResult<T>`
- **ALT-008**: **Rejection Reason**: Would break existing audit implementations and lose access to input context and metadata

## Implementation Notes

- **IMP-001**: TypedToolResult uses composition rather than inheritance to wrap `ToolResult<ToolOutput>` while preserving type information
- **IMP-002**: ToolOutputRegistry enhanced with `getOutputType()` and `hasOutputType<T>()` methods for runtime type operations
- **IMP-003**: Audit execution uses runtime type checking with graceful error handling for type mismatches
- **IMP-004**: All new APIs provide type-safe alternatives while maintaining backward compatibility through delegation
- **IMP-005**: Comprehensive tests validate type safety, error handling, and backward compatibility scenarios

## References

- **REF-001**: ADR-0001: Refactor ToolFlow Orchestration for Per-Step Generic Typing
- **REF-002**: `/plan/refactor-toolflow-per-step-generic-typing-1.md`
- **REF-003**: [Dart Generics Documentation](https://dart.dev/guides/language/language-tour#generics)
- **REF-004**: [Dart Type System Variance](https://dart.dev/guides/language/sound-dart)