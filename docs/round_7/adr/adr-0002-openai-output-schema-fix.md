---
title: "ADR-0002: OpenAI Tool Definition Schema Fix - Output-Based Instead of Input-Based"
status: "Accepted"
date: "2024-12-19"
authors: ["AI Assistant", "Package Maintainer"]
tags: ["openai", "schema", "tool-definition", "output-schema", "api-integration"]
supersedes: ""
superseded_by: ""
adr_references: []
used_as_resource_in: []
---

# ADR-0002: OpenAI Tool Definition Schema Fix - Output-Based Instead of Input-Based

## Status

**Accepted**

## Context

The `DefaultOpenAiToolService._buildToolDefinition` method was incorrectly using the input schema to define what the OpenAI tool call response should conform to, rather than using the expected output schema. This fundamental misalignment caused several issues:

- OpenAI tool calls were forced to conform to input structure instead of desired output structure
- TODO comment explicitly identified this as wrong: "This function is enforcing that the response of the open ai tool call confroms to the INPUT schema, which is wrong!"
- Mismatch between what we expect the tool to return and what we're telling OpenAI to return
- Potential for sanitization functions to receive incorrectly structured data

The request specified that tool calls should conform to an expected `ToolOutput` schema, with consideration for output sanitization that transforms data while maintaining the same schema structure.

## Decision

**Refactor OpenAI tool definition generation to use output schema configuration instead of input-derived schema.**

### Core Changes

1. **Add outputSchema to StepConfig**: New optional field for defining expected tool output structure
2. **Replace _buildParameterSchema**: New `_buildOutputSchema` method uses StepConfig.outputSchema
3. **Schema source change**: Tool definitions now based on expected output rather than provided input
4. **Fallback schema**: Generic schema provided when no specific output schema is configured
5. **StepConfig integration**: Schema definition co-located with other step-specific configuration

### Implementation Pattern

```dart
// StepConfig with output schema
final stepConfig = StepConfig(
  outputSchema: {
    'type': 'object',
    'properties': {
      'colors': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Array of hex color codes'
      },
      'confidence': {
        'type': 'number',
        'minimum': 0.0,
        'maximum': 1.0,
        'description': 'Confidence score'
      }
    },
    'required': ['colors', 'confidence']
  }
);

// OpenAI tool definition now uses outputSchema
// instead of deriving from input parameters
```

## Consequences

### Positive

- **POS-001**: **Correct schema alignment**: OpenAI responses now conform to expected output structure
- **POS-002**: **Better tool reliability**: Tools return data in the format we actually need
- **POS-003**: **Schema co-location**: Output schema defined alongside other step configuration
- **POS-004**: **Sanitization compatibility**: Output sanitizers receive properly structured data
- **POS-005**: **Eliminates TODO**: Directly addresses the identified architectural flaw

### Negative

- **NEG-001**: **Additional configuration**: Developers must define output schemas for optimal results
- **NEG-002**: **Schema duplication**: Output schema might duplicate information from ToolOutput classes
- **NEG-003**: **Fallback limitations**: Generic fallback schema may not provide optimal results

## Alternatives Considered

### Add Schema to ToolCallStep Instead

- **ALT-001**: **Description**: Place outputSchema directly on ToolCallStep rather than StepConfig
- **ALT-002**: **Rejection Reason**: Less discoverable than StepConfig which already contains step-specific configuration

### Use Function-Based Schema Generation

- **ALT-003**: **Description**: Pass a function that generates schema based on runtime context
- **ALT-004**: **Rejection Reason**: More complex for users than declarative schema definition

### Derive Schema from ToolOutput Registry

- **ALT-005**: **Description**: Automatically generate schemas from registered ToolOutput types
- **ALT-006**: **Rejection Reason**: Would require complex reflection and might not capture all constraints

### Keep Input-Based Schema with Warnings

- **ALT-007**: **Description**: Keep current implementation but add warnings about the mismatch
- **ALT-008**: **Rejection Reason**: Doesn't fix the fundamental architectural issue

## Implementation Notes

- **IMP-001**: **Backward compatibility**: Steps without outputSchema get a generic fallback schema
- **IMP-002**: **Schema structure**: Uses standard JSON Schema format compatible with OpenAI strict mode
- **IMP-003**: **Discoverability**: Output schema is part of StepConfig, making it easy to find and configure
- **IMP-004**: **Future extensibility**: Foundation for more sophisticated schema validation and generation

## References

- **REF-001**: Round 7 REQUESTED_UPDATES.md - "Update the DefaultOpenAiToolService._buildToolDefinition function"
- **REF-002**: TODO comment in openai_service_impl.dart line 127-128
- **REF-003**: OpenAI API documentation on tool definitions and strict mode
- **REF-004**: StepConfig architecture from previous rounds