---
title: "ADR-MISC-001: Retain InputSanitizer for Framework-Level Input Transformation"
status: "Accepted"
date: "2025-08-28"
authors: ["GitHub Copilot", "Daniel Couturier"]
tags: ["architecture", "input-sanitization", "inputBuilder", "framework-integration"]
supersedes: ""
superseded_by: ""
adr_references:
  - docs/round_6/adr/adr-0003-retain-input-sanitizer.md
  - docs/round_4/adr/adr-0003-output-sanitization-and-toolresult-patterns.md
used_as_resource_in:
  - docs/adr_appendix.md
---

# ADR-MISC-001: Retain InputSanitizer for Framework-Level Input Transformation

## Status

Accepted

## Context

The openai_toolflow package introduced the `inputBuilder` pattern, giving users direct control over how step inputs are constructed from previous results. This raised the question of whether the existing `inputSanitizer` functionality still serves a purpose.

- `inputBuilder` is user-controlled, focused on domain logic, and receives only previous results.
- `inputSanitizer` is an optional function in `StepConfig`, called after `inputBuilder` but before step execution, with access to both the output of `inputBuilder` and the full list of previous results.

## Decision

**Retain `inputSanitizer` as a post-`inputBuilder` transformation layer for framework-level concerns, standardization, and security.**

### Distinct Responsibilities

1. **inputBuilder**: Primary input construction from specified previous results
   - User-controlled input building from `buildInputsFrom` results
   - Returns domain-specific input data
   - Focused on data composition and transformation

2. **inputSanitizer**: Secondary processing layer for framework integration
   - Operates on inputBuilder output + framework state
   - Can sanitize data from `_state.entries` within ToolFlow
   - Provides last-mile filtering and cleanup
   - Handles framework-level concerns

### Use Cases for inputSanitizer

- **State Integration**: Inject global workflow context (e.g., user ID, session info, environment variables) into every step’s input, regardless of what the user’s inputBuilder does.
- **Security/Filtering**: Remove sensitive or internal fields that may have been accidentally included by a user’s inputBuilder or previous results.
- **Format Standardization**: Enforce input format standards regardless of what the user’s inputBuilder does.

### Example

```dart
StepConfig(
  inputSanitizer: ({required input, required previousResults}) {
    final sanitized = Map<String, dynamic>.from(input);
    // Inject global workflow context from framework state
    sanitized['workflow_context'] = ToolFlow.globalContext;
    // Remove any fields that start with _internal for security
    sanitized.removeWhere((key, value) => key.startsWith('_internal'));
    return sanitized;
  },
  // ...other config...
)
```

## Consequences

### Positive
- Maintains separation of concerns between user logic (inputBuilder) and framework logic (inputSanitizer)
- Provides safety net for data sanitization even if inputBuilder contains issues
- Enables framework-level state integration without complicating inputBuilder
- Preserves existing functionality while adding new inputBuilder capabilities
- Allows standardization across different inputBuilder implementations

### Negative
- Adds conceptual complexity with two transformation layers
- Potential for confusion about when to use inputBuilder vs inputSanitizer
- Additional performance overhead of double transformation
- Risk of redundant logic between inputBuilder and inputSanitizer

## Alternatives Considered

- Remove inputSanitizer completely and let inputBuilder handle all input construction and transformation (rejected: loses framework-level sanitization capabilities and state integration)
- Merge into inputBuilder and give it access to framework state (rejected: complicates inputBuilder API and mixes user concerns with framework concerns)
- Make inputSanitizer optional only for legacy (rejected: loses valuable framework-level sanitization capabilities for new implementations)

## Implementation Notes

- inputSanitizer executes AFTER inputBuilder, operating on its output
- inputSanitizer receives the full previous results list for context
- Documentation should clearly distinguish when to use inputBuilder vs inputSanitizer
- inputSanitizer has access to framework state that inputBuilder cannot access

## References
- Round 6 ADRs and REQUESTED_UPDATES.md - inputSanitizer evaluation request
- Current _buildStepInput implementation in ToolFlow
- inputBuilder pattern introduced in this round
