---
title: "ADR-0001: Generic AuditFunction and ToolResult for Type Safety"
status: "Accepted"
date: "2024-12-19"
authors: ["AI Assistant", "Package Maintainer"]
tags: ["generics", "type-safety", "audit-function", "tool-result", "typescript-like-patterns"]
supersedes: ""
superseded_by: ""
adr_references: []
used_as_resource_in: []
---

# ADR-0001: Generic AuditFunction and ToolResult for Type Safety

## Status

**Accepted**

## Context

The current implementation of `AuditFunction` and `ToolResult` lacks type safety, requiring developers to use unsafe casting and map-based access to tool outputs. This led to several issues:

- Audit functions had to convert `result.output` to a map and hope specific keys existed (e.g., `result.output.toMap()['colors']`)
- No compile-time type checking for specialized audit functions working with specific output types
- Runtime errors when accessing non-existent properties
- Poor IDE support and autocomplete for typed output access
- TODO comment in `ColorQualityAuditFunction` specifically requesting this feature

The request was to allow specialized audit functions like `ColorQualityAuditFunction` to safely access properties specific to their output type (e.g., `result.output.colors` on `ToolResult<ColorsToolOutput>`).

## Decision

**Implement generic types for AuditFunction and ToolResult to provide compile-time type safety.**

### Core Changes

1. **Generic AuditFunction**: `AuditFunction<T extends ToolOutput>` where `T` specifies the expected output type
2. **Generic ToolResult**: `ToolResult<T extends ToolOutput>` where `T` is the strongly-typed output
3. **Typed run method**: `List<Issue> run(ToolResult<T> result)` provides direct access to typed output
4. **Backward compatibility**: General case uses `AuditFunction<ToolOutput>` and `ToolResult<ToolOutput>`

### Usage Pattern

```dart
// Specialized audit function with type safety
class ColorQualityAuditFunction extends AuditFunction<PaletteExtractionOutput> {
  @override
  List<Issue> run(ToolResult<PaletteExtractionOutput> result) {
    // Direct typed access - no casting needed!
    final colors = result.output.colors;
    // ... validation logic
  }
}

// General purpose audit function
class GeneralAuditFunction extends AuditFunction<ToolOutput> {
  @override
  List<Issue> run(ToolResult<ToolOutput> result) {
    // Use toMap() for general access
    final outputData = result.output.toMap();
    // ... validation logic
  }
}
```

## Consequences

### Positive

- **POS-001**: **Compile-time type safety**: Eliminates runtime casting errors and provides IDE autocomplete
- **POS-002**: **Better developer experience**: Direct property access instead of map-based casting
- **POS-003**: **Self-documenting code**: Audit function signatures clearly indicate expected input types
- **POS-004**: **Eliminates TODO comment**: Directly addresses the feature request in `ColorQualityAuditFunction`
- **POS-005**: **Backward compatibility**: Existing code continues to work with minimal changes

### Negative

- **NEG-001**: **Breaking change**: Requires updating audit function signatures to specify generic types
- **NEG-002**: **Increased complexity**: Developers need to understand generic syntax
- **NEG-003**: **Migration effort**: Existing audit functions need to specify their expected output types

## Alternatives Considered

### Keep Current Non-Generic Implementation

- **ALT-001**: **Description**: Maintain the existing `AuditFunction` and `ToolResult` without generics
- **ALT-002**: **Rejection Reason**: Doesn't solve the type safety issue or the specific TODO comment request

### Use Method Overloading

- **ALT-003**: **Description**: Provide multiple `run` method overloads for different output types
- **ALT-004**: **Rejection Reason**: Less type-safe than generics and would require complex runtime type checking

### Union Types / Dynamic Typing

- **ALT-005**: **Description**: Use Dart's dynamic typing more extensively with runtime type checks
- **ALT-006**: **Rejection Reason**: Moves errors from compile-time to runtime, reducing safety

## Implementation Notes

- **IMP-001**: **Migration pattern**: Existing audit functions specify `<ToolOutput>` for general use or specific types like `<PaletteExtractionOutput>`
- **IMP-002**: **Test compatibility**: Tests updated to use `SimpleAuditFunction<ToolOutput>` for general testing
- **IMP-003**: **JSON serialization**: `fromJson` method handles generics by casting from `ToolResult<ToolOutput>` 
- **IMP-004**: **Registry support**: ToolOutputRegistry continues to work with the generic system

## References

- **REF-001**: Round 7 REQUESTED_UPDATES.md - "Refactor the AuditFunction base class to support generics"
- **REF-002**: TODO comment in ColorQualityAuditFunction requesting typed access
- **REF-003**: Example typed interfaces in typed_interfaces.dart (PaletteExtractionOutput, etc.)