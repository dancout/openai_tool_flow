---
title: "ADR-0001: Structured OutputSchema Implementation and Code Cleanup"
status: "Accepted"
date: "2025-09-01"
authors: "Development Team"
tags: ["architecture", "schema", "cleanup", "type-safety"]
supersedes: ""
superseded_by: ""
adr_references: ["ADR-0002-typedtoolresult-wrapper-implementation.md"]
used_as_resource_in: []
---

# ADR-0001: Structured OutputSchema Implementation and Code Cleanup

## Status

**Accepted** | Proposed | Rejected | Superseded | Deprecated

## Context

Round 9 requirements specified several improvements to the codebase:

1. **Code Bloat**: The codebase contained unused methods marked `@visibleForTesting` and unused static getters that weren't providing value
2. **Unstructured Schema Definition**: The `outputSchema` field in `StepConfig` was a loose `Map<String, dynamic>` that provided no type safety and was error-prone
3. **Manual Schema Specification**: Users had to manually specify output schemas even when the information could be derived from typed `ToolOutput` classes
4. **Schema Coupling**: There was no tight coupling between `ToolOutput` types and their expected schemas

The existing approach required users to manually write JSON Schema-like structures in maps, which was verbose, error-prone, and didn't leverage the existing type system.

## Decision

**Implement structured OutputSchema classes and remove unused code while maintaining backward compatibility.**

### Key Changes Made

1. **Code Cleanup**:
   - **CLN-001**: Removed unused `@visibleForTesting` methods from `ToolFlow` class (currentState, currentResults, etc.)
   - **CLN-002**: Removed unused `nonBlockingConfig` static getter from example configurations
   - **CLN-003**: Removed unused import statements and fixed linting issues

2. **Structured Schema Implementation**:
   - **SCH-001**: Created `PropertyEntry` class for defining individual schema properties with type safety
   - **SCH-002**: Created `OutputSchema` class to replace loose map-based schemas
   - **SCH-003**: Implemented schema inference from `ToolOutput.toMap()` method
   - **SCH-004**: Made `outputSchema` optional in `StepConfig` with automatic derivation fallbacks

3. **Backward Compatibility**:
   - **BWD-001**: Used `dynamic` type for `outputSchema` field to accept both `OutputSchema` objects and `Map<String, dynamic>`
   - **BWD-002**: Implemented automatic conversion in `getEffectiveOutputSchema()` method
   - **BWD-003**: Updated all example code to use new structured approach while maintaining test compatibility

4. **Schema Derivation**:
   - **DER-001**: Implemented `OutputSchema.fromToolOutput()` for automatic schema generation
   - **DER-002**: Added `getEffectiveOutputSchema()` method that attempts multiple derivation strategies
   - **DER-003**: Provided sensible fallback schemas when derivation is not possible

## Consequences

### Positive

- **POS-001**: Eliminated code bloat by removing 6 unused `@visibleForTesting` methods and 1 unused static getter
- **POS-002**: Improved type safety for schema definitions through structured classes
- **POS-003**: Reduced verbosity in schema specification with convenient factory methods
- **POS-004**: Enabled automatic schema derivation reducing manual specification burden
- **POS-005**: Maintained full backward compatibility for existing tests and code
- **POS-006**: Enhanced IDE support with autocompletion and type checking for schema properties
- **POS-007**: Achieved zero linting errors in final implementation

### Negative

- **NEG-001**: Added complexity with dual-type support for `outputSchema` field  
- **NEG-002**: Schema inference is limited for complex `ToolOutput` subclasses without sample instances
- **NEG-003**: Requires migration path planning for future versions to remove map-based support

## Alternatives Considered

### Make Breaking Changes to outputSchema Type

- **ALT-001**: **Description**: Change `outputSchema` to only accept `OutputSchema` objects
- **ALT-002**: **Rejection Reason**: Would break all existing tests and examples, requiring extensive migration work

### Keep Map-Based Approach

- **ALT-003**: **Description**: Continue using `Map<String, dynamic>` for schemas
- **ALT-004**: **Rejection Reason**: Misses opportunity for type safety improvements and doesn't address user experience issues

### Remove outputSchema Completely

- **ALT-005**: **Description**: Rely entirely on automatic derivation from `ToolOutput`
- **ALT-006**: **Rejection Reason**: Users still need ability to specify custom schemas that differ from `ToolOutput` structure

## Implementation Notes

- **IMP-001**: `PropertyEntry` supports nested properties for object types and array item definitions
- **IMP-002**: Schema inference uses heuristics based on value types (string, number, boolean, array, object)
- **IMP-003**: Fallback schemas provide meaningful defaults when derivation fails
- **IMP-004**: All example code updated to demonstrate new structured approach
- **IMP-005**: Test suite continues to use map-based schemas to verify backward compatibility

## References

- **REF-001**: Round 9 REQUESTED_UPDATES.md requirements
- **REF-002**: ADR-0002 TypedToolResult wrapper implementation (referenced for type safety patterns)
- **REF-003**: Existing `ToolOutput` and `ToolOutputRegistry` implementations