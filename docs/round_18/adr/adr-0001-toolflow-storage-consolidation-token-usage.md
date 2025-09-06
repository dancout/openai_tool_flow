---
title: "ADR-0001: ToolFlow Storage Consolidation and Token Usage Enhancement"
status: "Accepted"
date: "2024-12-28"
authors: "GitHub Copilot"
tags: ["architecture", "storage", "token-usage", "performance"]
supersedes: ""
superseded_by: ""
adr_references: ["ADR-0001-comprehensive-retry-tracking-system-message", "ADR-0002-typedtoolresult-wrapper-implementation"]
used_as_resource_in: []
---

# ADR-0001: ToolFlow Storage Consolidation and Token Usage Enhancement

## Status

**Accepted**

## Context

Round 18 requirements specified significant refactoring to improve ToolFlow architecture:

1. **Duplicate Storage Problem**: ToolFlow maintained both `_results` (List<TypedToolResult>) and `_allAttempts` (Map<int, List<TypedToolResult>>), where `_results` was essentially a subset of `_allAttempts`
2. **Missing Token Usage**: Token usage was stored in state maps but not accessible on individual TypedToolResult objects
3. **Index Confusion**: Manual `i-1`, `i`, `i+1` calculations led to error-prone step indexing
4. **Hardcoded Values**: Usage statistics contained hardcoded maxRetries_used instead of calculated values
5. **Duplicated Filtering Logic**: `_getIncludedResults` and `_getCurrentStepAttempts` contained identical filtering code
6. **Constructor Bloat**: ToolFlowResult required allIssues parameter despite being derivable from results

## Decision

**Implement consolidated storage architecture with enhanced token tracking and simplified indexing.**

### Core Changes

1. **Storage Consolidation**: Replace `_results` + `_allAttempts` with single `_stepAttempts: List<List<TypedToolResult>>`
   - Index 0: Initial input data (single attempt)
   - Index 1+: Step attempts (multiple attempts for retries)
   - Eliminates data duplication and synchronization issues

2. **Token Usage Integration**: Add `TokenUsage` class to TypedToolResult
   - Comprehensive tracking: promptTokens, completionTokens, totalTokens
   - Optional inclusion via `includeTokenUsage` parameter (default: true)
   - Zero-value support for initial input and error cases

3. **Consistent Indexing**: Implement helper methods for step index management
   - `_getStepStorageIndex(stepIndex)`: Converts step index to storage index
   - `getFinalStepResult(stepIndex)`: Gets final result for specific step
   - `getInitialInputResult()`: Gets initial input result
   - Eliminates manual index calculations

4. **Configurable Result Inclusion**: Add `includeAllAttempts` parameter
   - true: Return all attempts for each step (default)
   - false: Return only final attempt for each step
   - Enables memory optimization for production use

5. **Filtering Logic Consolidation**: Create `_filterAttemptsBySeverity` helper
   - Eliminates code duplication between `_getIncludedResults` and `_getCurrentStepAttempts`
   - Consistent filtering behavior across all usage contexts

6. **Derived allIssues**: Convert ToolFlowResult.allIssues to computed getter
   - Removes constructor parameter requirement
   - Automatically derives from current results
   - Eliminates potential inconsistency

## Consequences

### Positive

- **POS-001**: **Storage Efficiency**: Single storage structure eliminates data duplication and reduces memory usage
- **POS-002**: **Type Safety**: Consistent List<List<TypedToolResult>> structure provides clear type expectations
- **POS-003**: **Token Transparency**: Token usage accessible at granular level enables detailed cost analysis
- **POS-004**: **Index Clarity**: Helper methods eliminate error-prone manual index calculations
- **POS-005**: **Performance Control**: includeAllAttempts parameter enables memory optimization
- **POS-006**: **Code Maintainability**: Consolidated filtering logic reduces code duplication
- **POS-007**: **Data Consistency**: Derived allIssues ensures consistency with actual results

### Negative

- **NEG-001**: **Breaking Changes**: ToolFlowResult.results now returns List<List<TypedToolResult>> instead of List<TypedToolResult>
- **NEG-002**: **Migration Required**: Existing code must be updated to use new result structure
- **NEG-003**: **Memory Overhead**: Token usage storage adds memory overhead when enabled
- **NEG-004**: **Complexity**: Nested List structure adds conceptual complexity

## Alternatives Considered

### Maintain Separate Storage

- **ALT-001**: **Description**: Keep _results and _allAttempts separate but synchronized
- **ALT-002**: **Rejection Reason**: Continued data duplication and synchronization complexity

### Map-Based Storage

- **ALT-003**: **Description**: Use Map<int, List<TypedToolResult>> for all storage
- **ALT-004**: **Rejection Reason**: Less intuitive than List structure and complicates iteration

### Optional Token Tracking

- **ALT-005**: **Description**: Make TokenUsage completely optional with nullable field
- **ALT-006**: **Rejection Reason**: Zero-value approach provides consistent interface without null checks

## Implementation Notes

- **IMP-001**: **Backward Compatibility**: Added `finalResults` getter and deprecated `flatResults` for migration support
- **IMP-002**: **Index Management**: Storage index = step index + 1 (index 0 reserved for initial input)
- **IMP-003**: **Token Usage Creation**: Uses TokenUsage.fromMap() for API responses, TokenUsage.zero() for initial/error cases
- **IMP-004**: **Dynamic Calculation**: maxRetries_used now calculated from actual attempt counts instead of hardcoded values
- **IMP-005**: **Performance**: includeTokenUsage=false eliminates token tracking overhead in performance-critical scenarios

## References

- **REF-001**: Round 18 REQUESTED_UPDATES.md - User requirements for storage consolidation
- **REF-002**: ADR-0001: Comprehensive Retry Attempt Tracking - Related retry attempt storage architecture
- **REF-003**: ADR-0002: TypedToolResult Wrapper Implementation - Foundation for enhanced TypedToolResult
- **REF-004**: TokenUsage class implementation in token_usage.dart
- **REF-005**: Usage statistics calculation in example/usage.dart