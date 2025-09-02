---
title: "ADR-0001: Step Definition Pattern for Type-Safe Tool Configuration"
status: "Accepted"
date: "2025-01-03"
authors: "GitHub Copilot"
tags: ["architecture", "type-safety", "step-definition", "tool-configuration", "automation"]
supersedes: ""
superseded_by: ""
adr_references: []
used_as_resource_in: []
---

# ADR-0001: Step Definition Pattern for Type-Safe Tool Configuration

## Status

**Accepted**

## Context

The OpenAI ToolFlow package required a refactor to eliminate error-prone string usage in tool step configuration and automate typed output registration. The existing implementation had several pain points:

1. **Manual Registration**: Users had to manually call `ToolOutputRegistry.register()` for each tool output type, which was easy to forget and led to runtime errors.

2. **String-Based Configuration**: Tool steps were configured using raw string identifiers like `'extract_palette'`, which were prone to typos and provided no compile-time safety.

3. **Scattered Metadata**: Step names, output schemas, and factory methods were scattered across different files and classes, creating maintenance burden and potential inconsistencies.

4. **Duplicate Configuration**: The same step metadata (name, schema, factory) was specified in multiple places, violating the DRY principle.

5. **Runtime Error Discovery**: Missing registrations or incorrect step names were only discovered at runtime, making debugging difficult.

The Round 12 requirements specifically called for implementing step objects/classes that encapsulate step metadata and enable automatic registration while eliminating string-based references.

## Decision

Implement a **StepDefinition pattern** that encapsulates all tool step metadata and functionality in type-safe objects, with automatic registration and compile-time error detection where possible.

### Key Components Implemented

1. **StepDefinition Interface**: Abstract interface defining the contract for step metadata:
   - `stepName`: String identifier for the tool step
   - `outputSchema`: OutputSchema definition for the step
   - `fromMap`: Factory method for creating typed output from map data
   - `outputType`: Type information for the output class

2. **Static Step Names**: Added static `stepName` constants to existing ToolOutput classes:
   - `PaletteExtractionOutput.stepName = 'extract_palette'`
   - `ColorRefinementOutput.stepName = 'refine_colors'`
   - `ThemeGenerationOutput.stepName = 'generate_theme'`

3. **Concrete Step Definitions**: Implemented step definition classes that implement the StepDefinition interface:
   - `PaletteExtractionStepDefinition`
   - `ColorRefinementStepDefinition`
   - `ThemeGenerationStepDefinition`

4. **Enhanced ToolCallStep**: Added factory constructor `ToolCallStep.fromStepDefinition()` that:
   - Accepts a StepDefinition object instead of raw strings
   - Automatically registers the step definition in ToolOutputRegistry
   - Creates appropriate StepConfig with correct output schema
   - Eliminates duplicate schema specification

5. **Automatic Registration**: Extended ToolOutputRegistry with `registerStepDefinition()` method for seamless integration.

## Consequences

### Positive

- **POS-001**: **Elimination of Manual Registration**: Step definitions are automatically registered when `ToolCallStep.fromStepDefinition()` is called, preventing forgotten registrations.

- **POS-002**: **Compile-Time Safety**: Using static step name constants instead of raw strings enables better IDE support, refactoring safety, and reduces typo-related bugs.

- **POS-003**: **Single Source of Truth**: All step metadata (name, schema, factory) is centralized in step definition classes, eliminating duplication and ensuring consistency.

- **POS-004**: **Improved Developer Experience**: Developers can reference `PaletteExtractionOutput.stepName` instead of remembering raw strings, with full IDE autocomplete support.

- **POS-005**: **Runtime Error Prevention**: Automatic registration eliminates the class of runtime errors caused by missing tool output registrations.

- **POS-006**: **Maintainability**: Centralized step definitions make it easier to modify step configuration without hunting for scattered references.

### Negative

- **NEG-001**: **Additional Boilerplate**: Each tool output now requires a corresponding step definition class, increasing the number of files and classes to maintain.

- **NEG-002**: **Migration Complexity**: Existing code using raw strings needs to be updated to use the new pattern, requiring careful migration.

- **NEG-003**: **Learning Curve**: Developers need to understand the new step definition pattern and remember to use `ToolCallStep.fromStepDefinition()` instead of the raw constructor.

- **NEG-004**: **Runtime Registration**: While registration is automatic, it still happens at runtime during step creation rather than at compile time.

## Alternatives Considered

### Continue with Manual Registration

- **ALT-001**: **Description**: Keep the existing manual registration approach but improve documentation and error messages.
- **ALT-002**: **Rejection Reason**: This doesn't address the fundamental issues of error-prone string usage and scattered configuration. Manual registration remains a source of runtime errors.

### Global Static Registration

- **ALT-003**: **Description**: Use static initialization blocks or global registration to register all step definitions at startup.
- **ALT-004**: **Rejection Reason**: This approach would require importing all step definitions even when not used, and doesn't solve the string-based configuration issues.

### Code Generation Approach

- **ALT-005**: **Description**: Generate step definitions and registration code automatically from annotations or configuration files.
- **ALT-006**: **Rejection Reason**: This adds build complexity and tooling dependencies. The manual step definition approach provides better transparency and debugging capabilities.

### Enhance ToolOutput Classes Directly

- **ALT-007**: **Description**: Add step definition capabilities directly to ToolOutput classes without separate step definition classes.
- **ALT-008**: **Rejection Reason**: This would mix concerns by having output classes handle both data representation and step configuration. Separate step definition classes provide better separation of concerns.

## Implementation Notes

- **IMP-001**: **Backward Compatibility**: The original `ToolCallStep` constructor is preserved to maintain backward compatibility with existing code that hasn't migrated to the new pattern.

- **IMP-002**: **Gradual Migration**: Teams can migrate to the new pattern incrementally, starting with new steps and gradually updating existing ones.

- **IMP-003**: **Test Coverage**: Comprehensive tests verify that missing registrations and incorrect step names are caught at runtime, and that automatic registration works correctly.

- **IMP-004**: **Documentation Updates**: All examples and documentation are updated to demonstrate the new step definition pattern as the recommended approach.

- **IMP-005**: **IDE Support**: Static step name constants provide full IDE support for refactoring, find usages, and autocomplete functionality.

## References

- **REF-001**: Round 12 Requirements Document (`docs/round_12/REQUESTED_UPDATES.md`)
- **REF-002**: ToolFlow Type Safety ADRs (Round 8 ADR-0001, Round 11 ADR-0001)
- **REF-003**: Step Configuration Enhancement ADR (Round 3 ADR-0002)