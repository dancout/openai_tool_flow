---
title: "ADR-0001: Dynamic Input Builder Pattern"
status: "Proposed"
date: "2024-12-19"
authors: ["AI Assistant", "Package Maintainer"]
tags: ["architecture", "input-building", "dynamic-execution", "type-safety"]
supersedes: ""
superseded_by: ""
---

# ADR-0001: Dynamic Input Builder Pattern

## Status

**Proposed** | Accepted | Rejected | Superseded | Deprecated

## Context

The current ToolCallStep implementation uses static `params` that are defined at step configuration time. This creates a fundamental limitation:

1. **Static Limitation**: Step parameters cannot be determined based on outputs from previous steps
2. **Usage Problem**: The usage.dart example shows a TODO where step 2 colors are marked as "Will be populated..." because they depend on step 1 results
3. **Inflexibility**: No way to dynamically construct step inputs based on execution-time context
4. **Interface Redundancy**: The current system has both `params` in ToolCallStep and similar data in ToolInput, creating confusion

The Round 6 requirements specifically call for replacing static `params` with an `inputBuilder` function that:
- Takes a `List<ToolResult>` from specified previous steps
- Returns a lightweight structure with just the essential input data
- Executes at runtime when actual previous results are available

## Decision

**Replace static params with dynamic inputBuilder function in ToolCallStep.**

### Core Changes

1. **Remove**: `final Map<String, dynamic> params;` from ToolCallStep
2. **Add**: `final Map<String, dynamic> Function(List<ToolResult>) inputBuilder;` (required)
3. **Add**: `final List<Object> buildInputsFrom;` (similar to includeOutputsFrom pattern)
4. **Update**: ToolFlow to call inputBuilder at execution time instead of using static params

### Input Builder Contract

- **Input**: `List<ToolResult>` - Results from steps specified in `buildInputsFrom` in order
- **Output**: `Map<String, dynamic>` - Lightweight input data (no round, previousResults, temperature, etc.)
- **Responsibility**: User only provides core input data; ToolFlow adds metadata fields

### Example Usage Pattern

```dart
ToolCallStep(
  toolName: 'refine_colors',
  model: 'gpt-4',
  buildInputsFrom: ['extract_palette'], // or [0] for step index
  inputBuilder: (previousResults) {
    final paletteResult = previousResults.first;
    return {
      'colors': paletteResult.output['colors'],
      'enhance_contrast': true,
      'target_accessibility': 'AA',
    };
  },
  stepConfig: StepConfig(audits: [colorFormatAudit]),
)
```

## Consequences

### Positive

- **POS-001**: Enables dynamic input construction based on actual execution results
- **POS-002**: Eliminates the "TODO" problem in usage examples where inputs depend on previous steps
- **POS-003**: Provides cleaner separation between static configuration and dynamic data
- **POS-004**: Maintains type safety while adding runtime flexibility
- **POS-005**: Aligns with existing patterns like includeOutputsFrom

### Negative

- **NEG-001**: Breaking change requiring updates to all existing ToolCallStep definitions
- **NEG-002**: Slightly more complex API for simple cases that don't need dynamic inputs
- **NEG-003**: Additional runtime overhead of function execution for each step
- **NEG-004**: Potential for runtime errors if inputBuilder function fails

## Alternatives Considered

### Keep Static Params with Optional Input Builder

- **ALT-001**: **Description**: Maintain params for simple cases, add optional inputBuilder
- **ALT-002**: **Rejection Reason**: Creates API confusion and inconsistency; users wouldn't know which to use

### Use Template Strings in Params

- **ALT-003**: **Description**: Allow template strings like "${step1.colors}" in static params
- **ALT-004**: **Rejection Reason**: Less type-safe, harder to debug, and more complex parsing logic

### Separate Input and Params

- **ALT-005**: **Description**: Keep params for tool metadata, add separate inputBuilder for data
- **ALT-006**: **Rejection Reason**: Unclear distinction between metadata and data; existing pattern is confusing enough

## Implementation Notes

- **IMP-001**: For steps with empty buildInputsFrom, inputBuilder receives empty list and can return static data
- **IMP-002**: ToolFlow creates full ToolInput by merging inputBuilder output with metadata (round, previousResults, etc.)
- **IMP-003**: Error handling: if inputBuilder throws, wrap in ToolResult with critical issue
- **IMP-004**: buildInputsFrom supports same patterns as includeOutputsFrom (tool names, step indices)

## References

- **REF-001**: Round 6 REQUESTED_UPDATES.md requirements
- **REF-002**: usage.dart TODO comment about dynamic input construction
- **REF-003**: Existing includeOutputsFrom pattern in StepConfig