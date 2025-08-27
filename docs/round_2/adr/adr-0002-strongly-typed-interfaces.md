---
title: "ADR-0002: Strongly-Typed Tool Interfaces and Backward Compatibility"
status: "Accepted"
date: "2024-12-19"
authors: ["AI Assistant", "Package Maintainer"]
tags: ["architecture", "typing", "interfaces", "compatibility"]
supersedes: ""
superseded_by: ""
adr_references: []
used_as_resource_in: []
---

# ADR-0002: Strongly-Typed Tool Interfaces and Backward Compatibility

## Status

**Accepted**

## Context

The original package design used generic `Map<String, dynamic>` for both tool inputs and outputs, which provided flexibility but lacked type safety and IDE support. Users requested concrete result types with explicit parameters for better integration with OpenAI API and downstream step references.

Key requirements identified:
- Provide type safety for tool inputs and outputs
- Enable precise typing and validation
- Maintain backward compatibility with existing Map-based interface
- Support extensibility for new tool types
- Allow optional adoption (not force typed interfaces)

The challenge was implementing strong typing without breaking existing codebases while providing clear migration paths.

## Decision

**Implement dual-interface system with abstract base classes and optional typed interfaces.**

The solution provides:

1. **Abstract Base Classes**: `ToolInput` and `ToolOutput` define contracts for typed interfaces
2. **Concrete Implementations**: Example classes like `PaletteExtractionInput`, `ColorRefinementOutput`
3. **Registry System**: `ToolOutputRegistry` for type-safe creation and registration
4. **Backward Compatible ToolResult**: Added optional `typedInput`/`typedOutput` fields while preserving Map interface
5. **Optional Adoption**: Typed interfaces are opt-in, generic maps remain functional

## Consequences

### Positive

- **POS-001**: **Type Safety**: Compile-time validation of tool parameters and outputs
- **POS-002**: **IDE Support**: Auto-completion and IntelliSense for tool interfaces
- **POS-003**: **Validation**: Built-in input validation through `validate()` methods
- **POS-004**: **Backward Compatibility**: Existing Map-based code continues to work unchanged
- **POS-005**: **Gradual Migration**: Teams can adopt typed interfaces incrementally
- **POS-006**: **Documentation**: Concrete types serve as living documentation of tool contracts
- **POS-007**: **OpenAI Integration**: Structured types align better with OpenAI tool schemas

### Negative

- **NEG-001**: **Code Complexity**: Additional abstract classes and registry pattern increase codebase size
- **NEG-002**: **Learning Curve**: Developers need to understand both Map and typed approaches
- **NEG-003**: **Maintenance Overhead**: Need to maintain concrete types alongside generic interfaces
- **NEG-004**: **Registry Management**: Manual registration required for typed outputs

## Alternatives Considered

### Pure Generic Approach (Status Quo)

- **ALT-001**: **Description**: Continue using only `Map<String, dynamic>` for all interfaces
- **ALT-002**: **Rejection Reason**: Lacks type safety, IDE support, and validation capabilities requested by users

### Force Typed Interfaces Only

- **ALT-003**: **Description**: Replace Map interface entirely with strongly-typed classes
- **ALT-004**: **Rejection Reason**: Would break backward compatibility and force migration of existing code

### Union Types with Sealed Classes

- **ALT-005**: **Description**: Use Dart's sealed classes to create union types for inputs/outputs
- **ALT-006**: **Rejection Reason**: More complex pattern, less familiar to developers, harder to extend

### Code Generation Approach

- **ALT-007**: **Description**: Generate typed interfaces from JSON schemas or annotations
- **ALT-008**: **Rejection Reason**: Adds build complexity and tooling requirements without clear benefit over manual approach

## Implementation Notes

- **IMP-001**: **Registry Pattern**: `ToolOutputRegistry.register()` allows runtime registration of typed creators
- **IMP-002**: **Optional Fields**: `ToolResult.typedInput` and `typedOutput` are optional, maintaining compatibility
- **IMP-003**: **Validation Support**: `ToolInput.validate()` provides built-in parameter validation
- **IMP-004**: **Conversion Methods**: All typed classes provide `toMap()` and `fromMap()` for seamless interop
- **IMP-005**: **Example Implementations**: Concrete examples for palette extraction, color refinement, and theme generation

## References

- **REF-001**: OpenAI API function calling documentation and best practices
- **REF-002**: Dart type system and abstract class patterns
- **REF-003**: Gang of Four Registry pattern for type management