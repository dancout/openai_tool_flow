---
title: "ADR-0003: Retain Input Sanitizer with Enhanced Role"
status: "Proposed"
date: "2024-12-19"
authors: ["AI Assistant", "Package Maintainer"]
tags: ["architecture", "input-sanitization", "state-management", "inputBuilder"]
supersedes: ""
superseded_by: ""
---

# ADR-0003: Retain Input Sanitizer with Enhanced Role

## Status

**Proposed** | Accepted | Rejected | Superseded | Deprecated

## Context

The Round 6 requirements introduced the inputBuilder pattern which gives users direct control over how step inputs are constructed from previous results. This raised the question of whether the existing inputSanitizer functionality still serves a purpose.

**Current inputSanitizer functionality:**
- Takes the built input map and previous results 
- Allows transformation/filtering before step execution
- Can access both the inputBuilder output and _state entries from ToolFlow

**New inputBuilder functionality:**
- Users have direct control over input construction from previous results
- Executes at runtime with actual previous results
- Returns clean input data without framework metadata

**The question:** Does inputSanitizer still provide value when users can already control input construction through inputBuilder?

## Decision

**Retain inputSanitizer with enhanced role as a post-inputBuilder transformation layer.**

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

1. **State Integration**: Merge inputBuilder output with relevant state data
   ```dart
   inputSanitizer: ({required input, required previousResults}) {
     final sanitized = Map<String, dynamic>.from(input);
     // Add framework state that inputBuilder can't access
     sanitized['workflow_context'] = _state['workflow_context'];
     return sanitized;
   }
   ```

2. **Security/Filtering**: Remove sensitive data regardless of inputBuilder output
   ```dart
   inputSanitizer: ({required input, required previousResults}) {
     final cleaned = Map<String, dynamic>.from(input);
     cleaned.removeWhere((key, value) => key.startsWith('_internal'));
     return cleaned;
   }
   ```

3. **Format Standardization**: Ensure consistent input format regardless of inputBuilder variations
   ```dart
   inputSanitizer: ({required input, required previousResults}) {
     // Standardize color format regardless of inputBuilder output
     if (input['colors'] is List) {
       input['colors'] = (input['colors'] as List)
           .map((color) => color.toString().toUpperCase())
           .toList();
     }
     return input;
   }
   ```

## Consequences

### Positive

- **POS-001**: Maintains separation of concerns between user logic (inputBuilder) and framework logic (inputSanitizer)
- **POS-002**: Provides safety net for data sanitization even if inputBuilder contains issues
- **POS-003**: Enables framework-level state integration without complicating inputBuilder
- **POS-004**: Preserves existing functionality while adding new inputBuilder capabilities
- **POS-005**: Allows standardization across different inputBuilder implementations

### Negative

- **NEG-001**: Adds conceptual complexity with two transformation layers
- **NEG-002**: Potential for confusion about when to use inputBuilder vs inputSanitizer
- **NEG-003**: Additional performance overhead of double transformation
- **NEG-004**: Risk of redundant logic between inputBuilder and inputSanitizer

## Alternatives Considered

### Remove inputSanitizer Completely

- **ALT-001**: **Description**: Let inputBuilder handle all input construction and transformation
- **ALT-002**: **Rejection Reason**: Loses framework-level sanitization capabilities and state integration

### Merge into inputBuilder

- **ALT-003**: **Description**: Give inputBuilder access to framework state and expand its responsibilities  
- **ALT-004**: **Rejection Reason**: Complicates inputBuilder API and mixes user concerns with framework concerns

### Make inputSanitizer Optional Only for Legacy

- **ALT-005**: **Description**: Deprecate inputSanitizer for new code, keep only for backward compatibility
- **ALT-006**: **Rejection Reason**: Loses valuable framework-level sanitization capabilities for new implementations

## Implementation Notes

- **IMP-001**: inputSanitizer now executes AFTER inputBuilder, operating on its output
- **IMP-002**: inputSanitizer receives the full previous results list for context
- **IMP-003**: Documentation should clearly distinguish when to use inputBuilder vs inputSanitizer
- **IMP-004**: inputSanitizer has access to framework state that inputBuilder cannot access

## References

- **REF-001**: Round 6 REQUESTED_UPDATES.md - inputSanitizer evaluation request
- **REF-002**: Current _buildStepInput implementation in ToolFlow
- **REF-003**: inputBuilder pattern introduced in this round