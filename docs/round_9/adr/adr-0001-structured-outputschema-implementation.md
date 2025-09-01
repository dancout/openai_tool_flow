---
title: "ADR-0001: Structured OutputSchema Implementation and Breaking Changes"
status: "Accepted"
date: "2025-09-01"
authors: "Development Team"
tags: ["architecture", "schema", "cleanup", "type-safety", "breaking-changes"]
supersedes: ""
superseded_by: ""
adr_references: ["ADR-0002-typedtoolresult-wrapper-implementation.md"]
used_as_resource_in: []
---

# ADR-0001: Structured OutputSchema Implementation and Breaking Changes

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

**Implement structured OutputSchema classes with breaking changes to enforce type safety and modern patterns.**

### Key Changes Made

1. **Code Cleanup**:
   - **CLN-001**: Removed unused `@visibleForTesting` methods from `ToolFlow` class (currentState, currentResults, etc.)
   - **CLN-002**: Removed unused `nonBlockingConfig` static getter from example configurations
   - **CLN-003**: Removed unused import statements and fixed linting issues

2. **Structured Schema Implementation**:
   - **SCH-001**: Created `PropertyType` enum to replace string types, preventing typos and ensuring type safety
   - **SCH-002**: Added required `name` parameter to `PropertyEntry` class for clearer property definitions
   - **SCH-003**: Changed `OutputSchema.properties` from `Map<String, PropertyEntry>` to `List<PropertyEntry>` for better ergonomics
   - **SCH-004**: Added convenient factory methods (`PropertyEntry.string()`, `PropertyEntry.array()`, etc.) for common use cases
   - **SCH-005**: Made `outputSchema` field accept only `OutputSchema` objects, removing `dynamic` type support

3. **Breaking Changes**:
   - **BRK-001**: Removed all map-based schema support - no backward compatibility maintained
   - **BRK-002**: Removed `OutputSchema.fromToolOutput()` method that provided inconsistent schema derivation
   - **BRK-003**: Removed fallback schema generation when derivation is not possible
   - **BRK-004**: Required all `ToolOutput` subclasses to implement `getOutputSchema()` method

4. **Schema Derivation**:
   - **DER-001**: Added `getOutputSchema()` abstract method to `ToolOutput` base class
   - **DER-002**: Enhanced `ToolOutputRegistry.getOutputSchema()` to derive schemas from registered outputs
   - **DER-003**: Modified `getEffectiveOutputSchema()` to throw clear errors when no schema can be derived

## Consequences

### Positive

- **POS-001**: Eliminated code bloat by removing 6 unused `@visibleForTesting` methods and 1 unused static getter
- **POS-002**: Improved type safety for schema definitions through structured classes and enums
- **POS-003**: Reduced verbosity in schema specification with convenient factory methods
- **POS-004**: Enabled automatic schema derivation from registered `ToolOutput` types
- **POS-005**: Enhanced IDE support with autocompletion and type checking for schema properties
- **POS-006**: Achieved zero linting errors in final implementation
- **POS-007**: Eliminated potential runtime errors from typos in property type strings
- **POS-008**: Simplified property definitions with List-based approach and named entries

### Negative

- **NEG-001**: Breaking changes require migration of all existing code using map-based schemas
- **NEG-002**: All `ToolOutput` subclasses must now implement `getOutputSchema()` method
- **NEG-003**: No fallback schemas available when derivation fails - explicit definition required
- **NEG-004**: Requires understanding of new factory method patterns for property creation

## Alternatives Considered

### Maintain Backward Compatibility

- **ALT-001**: **Description**: Continue supporting both Map-based and OutputSchema approaches
- **ALT-002**: **Rejection Reason**: Explicit requirement to not focus on backward compatibility and make necessary changes regardless of migration effort

### Keep Map-Based Approach

- **ALT-003**: **Description**: Continue using `Map<String, dynamic>` for schemas with improved validation
- **ALT-004**: **Rejection Reason**: Misses opportunity for type safety improvements and doesn't address user experience issues with typos and runtime errors

### Provide Automatic Fallback Schemas

- **ALT-005**: **Description**: Generate generic schemas when specific ones aren't available
- **ALT-006**: **Rejection Reason**: Requirement specified that ToolOutput should provide schemas "we can have 100% confidence in" rather than fallbacks

## Implementation Notes

- **IMP-001**: `PropertyType` enum prevents runtime errors from typos in type strings
- **IMP-002**: Factory methods (`PropertyEntry.string()`, `PropertyEntry.array()`, etc.) provide convenient and type-safe property creation
- **IMP-003**: List-based properties with named entries eliminate confusion about property names and improve readability
- **IMP-004**: All example code updated to demonstrate new structured approach with factory methods
- **IMP-005**: All test suites updated to use new OutputSchema objects instead of maps
- **IMP-006**: `ToolOutput.getOutputSchema()` method ensures every output type has a defined, reliable schema
- **IMP-007**: `ToolOutputRegistry.getOutputSchema()` enables automatic schema derivation for registered tools
- **IMP-008**: Error handling improved with clear messages when schemas cannot be derived

## References

- **REF-001**: Round 9 REQUESTED_UPDATES.md requirements
- **REF-002**: ADR-0002 TypedToolResult wrapper implementation (referenced for type safety patterns)
- **REF-003**: Existing `ToolOutput` and `ToolOutputRegistry` implementations