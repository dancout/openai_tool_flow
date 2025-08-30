---
title: "ADR-0001: Refactor ToolFlow Orchestration for Per-Step Generic Typing"
status: "Accepted"
date: "2025-08-29"
authors: "Daniel Couturier"
tags: ["architecture", "toolflow", "generics", "audit", "type-safety"]
supersedes: ""
superseded_by: ""
adr_references: []
used_as_resource_in: ["ADR-0002"]
---

# ADR-0001: Refactor ToolFlow Orchestration for Per-Step Generic Typing

## Status

**Accepted**

## Context

The ToolFlow orchestration system currently stores all tool step results as `ToolResult<ToolOutput>`, erasing the specific output type for each step. This causes runtime type errors when audits expect a specific output type (e.g., `PaletteExtractionOutput`) but receive a generic result. The lack of type safety makes the system fragile, hard to extend, and error-prone. The goal is to propagate the correct output type for each tool step, ensuring audits receive the expected typed result and the system remains robust and extensible.

## Decision

Refactor ToolFlow orchestration and related interfaces to support per-step generic typing. Each tool step will produce and store a `ToolResult<T extends ToolOutput>`, and audits will receive the correct typed result for their tool. Result storage will use a type-safe structure (not `List<dynamic>`), preserving access to common fields and enabling type-safe audit execution. The implementation will leverage Dart generics and type registries.

## Consequences

### Positive

- **POS-001**: Enables type-safe audit execution and eliminates runtime type errors.
- **POS-002**: Improves maintainability, extensibility, and robustness of the orchestration system.
- **POS-003**: Aligns with architectural principles of strong typing and modularity.

### Negative

- **NEG-001**: Increases initial refactor complexity and may require significant code changes.
- **NEG-002**: May introduce migration challenges for existing code and tests.
- **NEG-003**: Dart’s type system limitations may require workarounds for runtime type propagation.

## Alternatives Considered

### Dynamic Casting and Runtime Type Checks

- **ALT-001**: **Description**: Use dynamic casting and runtime type checks for audit execution.
- **ALT-002**: **Rejection Reason**: Rejected due to risk of runtime errors and loss of type safety.

### Single Output Type for All Steps

- **ALT-003**: **Description**: Refactor the entire flow to use a single output type for all steps.
- **ALT-004**: **Rejection Reason**: Rejected as it eliminates extensibility and type safety for heterogeneous tool outputs.

### List<dynamic> for Result Storage

- **ALT-005**: **Description**: Use `List<dynamic>` for result storage.
- **ALT-006**: **Rejection Reason**: Rejected because it loses type safety and makes it difficult to access common result fields in a structured way.

## Implementation Notes

- **IMP-001**: Update all relevant classes, interfaces, and result storage to support per-step generic typing.
- **IMP-002**: Migrate existing code and tests to the new architecture, ensuring all audits receive the correct typed result.
- **IMP-003**: Validate with comprehensive tests and update documentation to reflect the new design.

## References

- **REF-001**: `/plan/refactor-toolflow-per-step-generic-typing-1.md`
- **REF-002**: [ADR: Strongly Typed Interfaces](docs/round_2/adr/adr-0002-strongly-typed-interfaces.md)
- **REF-003**: [Dart Generics Documentation](https://dart.dev/guides/language/language-tour#generics)
