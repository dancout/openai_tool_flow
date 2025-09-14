---
title: "ADR-0022: Image Editing API Integration"
status: "Accepted"
date: "2025-09-14"
authors: "AI Agent"
tags: ["architecture", "decision", "image-editing", "openai-integration"]
supersedes: ""
superseded_by: ""
adr_references: []
used_as_resource_in: []
---

# ADR-0022: Image Editing API Integration

## Status

Accepted

## Context

The ToolFlow pipeline previously supported only chat completions and image generation through OpenAI APIs. Round 21 requirements specified the need to add image editing functionality through OpenAI's `/images/edits` endpoint while maintaining the existing architecture and reusing as much code as possible. The challenge was to integrate a third API type (image editing) without disrupting the current pipeline structure and while providing clear type safety to distinguish between chat completions, image generation, and image editing operations.

Key constraints:
- Must support OpenAI's `/images/edits` endpoint 
- Should reuse existing pipeline infrastructure
- Need type safety to distinguish between three operation types
- Must handle multipart form data for image uploads
- Should provide comprehensive input validation
- Version 0.0.x allows breaking changes for better architecture

## Decision

Implement image editing support through input type-based detection and dedicated factory methods, creating:

1. **ImageEditInput/ImageEditOutput/ImageEditStepDefinition** classes following existing patterns
2. **Tool name-based API routing** in DefaultOpenAiToolService using ImageOperation enum 
3. **Factory methods** for type-safe step creation: `forImageGeneration()`, `forImageEditing()`, `forChatCompletion()`
4. **Comprehensive validation** for image editing parameters including gpt-image-1 and dall-e-2 specific features

## Consequences

### Positive

- **POS-001**: Type safety prevents runtime errors by distinguishing operation types at compile time through dedicated input classes
- **POS-002**: Factory methods eliminate user errors in step configuration and provide clear intent
- **POS-003**: Tool name-based detection using ImageOperation enum is more reliable and intuitive than model-based detection for distinguishing between image operations
- **POS-004**: Reuses existing pipeline infrastructure (retry logic, audit functions, state management) for image editing
- **POS-005**: Comprehensive validation prevents invalid API calls and provides clear error messages
- **POS-006**: Architecture supports future OpenAI API additions through the same pattern

### Negative

- **NEG-001**: Increases codebase size with new interface files and validation logic
- **NEG-002**: Requires users to learn new factory methods instead of generic constructors
- **NEG-003**: Tool name-based detection adds conditional logic but is more intuitive than input type detection
- **NEG-004**: Multipart form data handling may require future enhancement for file uploads

## Alternatives Considered

### Model-Based Detection

- **ALT-001**: **Description**: Use model names like 'dall-e-2' vs 'dall-e-3' for API routing
- **ALT-002**: **Rejection Reason**: Same model (dall-e-2) used for both generation and editing makes this approach ambiguous and error-prone

### Separate Service Classes

- **ALT-003**: **Description**: Create ImageEditingService, ImageGenerationService, ChatCompletionService
- **ALT-004**: **Rejection Reason**: Would duplicate retry logic, audit functions, and state management; violates DRY principle

### Generic Map-Based Configuration

- **ALT-005**: **Description**: Use configuration maps to specify operation type
- **ALT-006**: **Rejection Reason**: Lacks compile-time type safety and increases runtime error potential

## Implementation Notes

- **IMP-001**: Tool name-based detection using ImageOperation enum in _buildStepInput() method routes to appropriate input type creation
- **IMP-002**: Factory methods automatically register step definitions and assign distinct tool names ('generate_image', 'edit_image')
- **IMP-003**: Validation covers both dall-e-2 and gpt-image-1 specific parameters
- **IMP-004**: Example updated to demonstrate two-step workflow: generation followed by editing
- **IMP-005**: ImageOperation enum provides type-safe distinction between 'generation' and 'editing' operations
- **IMP-006**: Future multipart form data support can be added to _buildImageEditRequest() method

## References

- **REF-001**: OpenAI Images API documentation for /images/edits endpoint
- **REF-002**: Existing ImageGenerationStepDefinition pattern for consistency
- **REF-003**: ToolFlow Architecture documentation for pipeline integration