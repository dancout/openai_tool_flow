---
status: Accepted
date: 2025-01-27
decision-makers: Development Team
consulted: 
informed: 
tags: [tooloutputregistry, tooloutput, round-parameter, typedtoolresult, breaking-changes]
---

# ADR-0001: Non-Optional ToolOutputRegistry and Round Parameter Requirements

## Status

**Accepted**

## Context

As the openai_tool_flow package evolves from version 0.0.x, several API improvements were identified to enhance type safety, eliminate null handling complexity, and provide better debugging support for retry attempts. The existing implementation had several weaknesses:

1. **Nullable Return Types**: `ToolOutputRegistry.create()` and `getOutputType()` returned nullable types, requiring extensive null checking and fallback logic.
2. **Missing Round Context**: `ToolOutput` classes had no way to track which retry attempt they were created during, making debugging difficult.
3. **Legacy Result Types**: `ToolFlowResult.results` returned the legacy `List<ToolResult<ToolOutput>>` instead of the more type-safe `TypedToolResult`.
4. **Misplaced Utility Methods**: `issuesWithSeverity()` lived on `ToolFlowResult` but was only used in example code.

## Decision

**Implement breaking changes to improve API safety and developer experience:**

### 1. Make ToolOutputRegistry Methods Non-Optional

- **`create()`**: Now returns `ToolOutput` and throws an exception if no creator is registered
- **`getOutputType()`**: Now returns `Type` and throws an exception if no type is registered

### 2. Add Required Round Parameter to ToolOutput

- All `ToolOutput` constructors now require a `round: int` parameter
- Round information is stored and included in `toMap()` output as `_round`
- Factory methods updated to accept round parameter: `fromMap(Map<String, dynamic> map, int round)`

### 3. Update ToolFlowResult.results to Return TypedToolResult

- Changed from `List<ToolResult<ToolOutput>>` to `List<TypedToolResult>`
- Updated dependent methods like `getResultsWhere()` and `getResultsByToolNames()`
- Added typed counterparts like `getAllTypedResultsByToolName()`

### 4. Move issuesWithSeverity to Point of Use

- Removed `issuesWithSeverity()` method from `ToolFlowResult`
- Created helper function in `usage.dart` where it's actually used
- Follows principle of placing utility functions where they're needed

## Consequences

### Positive

- **Fail-Fast Behavior**: Registry issues are caught immediately with clear error messages instead of silent null returns
- **Enhanced Debugging**: Round numbers in outputs help trace which retry attempt produced specific results
- **Type Safety**: `TypedToolResult` provides better type information and consistency
- **Cleaner API**: Eliminates null checking boilerplate throughout the codebase
- **Better Organization**: Utility functions are located where they're used

### Negative

- **Breaking Changes**: All existing code must be updated to handle new signatures
- **Migration Effort**: Round parameters must be passed everywhere ToolOutput is created
- **Registry Registration**: All existing registrations need updating to new function signature

### Migration Impact

**Required Changes for Existing Code:**

1. **ToolOutput Subclasses**: Add `round` parameter to constructors and `fromMap` factories
2. **Registry Registration**: Update from `(data) => Output.fromMap(data)` to `(data, round) => Output.fromMap(data, round)`
3. **Result Access**: Code accessing `results` may need updates if it expects `ToolResult<ToolOutput>`
4. **Issue Filtering**: Replace `result.issuesWithSeverity()` calls with helper function

**Example Migration:**

```dart
// Before
ToolOutputRegistry.register('tool', (data) => MyOutput.fromMap(data));
final output = ToolOutputRegistry.create(toolName: 'tool', data: data);
if (output == null) {
  // handle null case
}

// After  
ToolOutputRegistry.register('tool', (data, round) => MyOutput.fromMap(data, round));
final output = ToolOutputRegistry.create(toolName: 'tool', data: data, round: round);
// No null checking needed - will throw if not found
```

## Implementation Notes

- **Registry Clearing**: Private fields cannot be cleared in tests, so unique tool names used per test
- **Error Messages**: Exception messages include tool names for easier debugging
- **Backward Compatibility**: Deprecated constructor maintained for legacy `ToolFlowResult` creation
- **Round Extraction**: JSON deserialization extracts round from output `_round` field or input fallback

## Alternatives Considered

### Incremental Migration
- **Description**: Keep nullable methods and add non-nullable variants
- **Rejection Reason**: Creates API confusion and doesn't force proper error handling

### Optional Round Parameter
- **Description**: Make round parameter optional with default value
- **Rejection Reason**: Loses debugging information for retry attempts

### Keep Legacy Results Type
- **Description**: Maintain `List<ToolResult<ToolOutput>>` return type
- **Rejection Reason**: Misses opportunity to improve type safety across the API

## Related Decisions

- Previous ADRs establishing `TypedToolResult` and registry patterns
- Future ADRs should consider impact on tool registration workflows

## Validation

- All existing tests updated and passing
- New comprehensive test suite covering error cases and round parameter behavior
- Integration tests confirm end-to-end functionality works correctly