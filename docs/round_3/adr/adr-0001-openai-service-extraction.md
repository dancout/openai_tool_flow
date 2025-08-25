---
title: "ADR-0001: OpenAI Service Extraction and Dependency Injection"
status: "Proposed"
date: "2024-12-19"
authors: ["AI Assistant", "Package Maintainer"]
tags: ["architecture", "service", "testing", "dependency-injection"]
supersedes: ""
superseded_by: ""
---

# ADR-0001: OpenAI Service Extraction and Dependency Injection

## Status

**Proposed**

## Context

The current ToolFlow implementation contains OpenAI API call logic directly embedded within the main orchestration class. This creates several issues:

- Testing requires mock responses within ToolFlow itself (`useMockResponses` flag)
- OpenAI-specific logic is tightly coupled to flow orchestration
- Model-specific parameter handling (temperature vs max_tokens/max_completion_tokens for different models) is scattered
- Difficult to swap OpenAI implementations or add alternative providers
- System/user message building uses unstructured maps, prone to typos and errors

Users have requested:
- Ability to inject/mock the OpenAI service for testing
- Cleaner separation of concerns between orchestration and API calls
- Strongly typed input structures instead of generic maps
- Model-specific parameter handling in a centralized location

## Decision

**Extract OpenAI functionality into a dedicated service with dependency injection support.**

The solution provides:

1. **OpenAiToolService**: Dedicated service class handling all OpenAI API interactions
2. **OpenAiRequest**: Structured request class with model-specific parameter handling
3. **Typed Input Classes**: Strongly-typed classes for system/user message building
4. **Dependency Injection**: Allow service injection into ToolFlow for testing and flexibility
5. **Remove useMockResponses**: Replace with injectable service pattern

## Consequences

### Positive

- **POS-001**: **Separation of Concerns**: Clear boundary between orchestration and API calls
- **POS-002**: **Testability**: Easy mocking and testing without API calls
- **POS-003**: **Type Safety**: Strongly-typed request building reduces errors
- **POS-004**: **Model Flexibility**: Centralized handling of model-specific differences
- **POS-005**: **Extensibility**: Easy to add alternative AI providers in future
- **POS-006**: **Maintainability**: OpenAI logic isolated and easier to modify

### Negative

- **NEG-001**: **Complexity**: Additional abstraction layer adds complexity
- **NEG-002**: **Breaking Changes**: Requires updates to existing ToolFlow usage
- **NEG-003**: **Interface Maintenance**: Service interface must be maintained as OpenAI API evolves

## Alternatives Considered

### Keep OpenAI Logic in ToolFlow

- **ALT-001**: **Description**: Maintain current structure with improvements to mock handling
- **ALT-002**: **Rejection Reason**: Doesn't address core coupling issues and testing limitations

### Static Service Class

- **ALT-003**: **Description**: Create static utility class for OpenAI calls
- **ALT-004**: **Rejection Reason**: Doesn't enable dependency injection for testing

## Implementation Notes

- **IMP-001**: **Service Interface**: Define abstract base class for OpenAI service to enable mocking
- **IMP-002**: **Request Builder**: OpenAiRequest class handles model-specific parameter differences
- **IMP-003**: **Message Types**: Create MessageInput classes for system/user message building
- **IMP-004**: **Default Implementation**: Provide concrete OpenAI service implementation
- **IMP-005**: **Backward Compatibility**: Maintain factory methods for easy migration

## References

- **REF-001**: REQUESTED_UPDATES.md Round 3 requirements
- **REF-002**: Dependency Injection patterns for testability
- **REF-003**: OpenAI API documentation for model-specific parameters