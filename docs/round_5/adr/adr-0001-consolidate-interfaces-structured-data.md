# ADR-0001: Consolidate Interfaces and Use Structured Data

## Status

Proposed | **Accepted** | Rejected | Superseded | Deprecated

## Context

The Round 5 requirements called for several interface improvements:

1. **Duplicate Interface Problem**: Both `StepInput` and `ToolInput` existed, with `StepInput` being just a typedef to `ToolInput`
2. **Data Duplication**: The system was passing around both `List<ToolResult>` and `List<Issue>` separately, when `ToolResult` already contains the issues
3. **Unstructured Data**: The system was converting to JSON too early in the pipeline, losing type safety
4. **Silent Failures**: When `ToolOutputRegistry.create` failed, the step would continue silently instead of failing
5. **Positional Parameters**: Private methods used positional parameters making code unclear

## Decision

### 1. Consolidate Input Interfaces
- **Removed** `StepInput` typedef completely
- **Use only** `ToolInput` throughout the codebase
- **Updated** all references and tests to use `ToolInput`

### 2. Use ToolResult as Single Source of Truth
- **Changed** `ToolInput.previousIssues: List<Issue>` to `ToolInput.previousResults: List<ToolResult>`
- **Updated** `SystemMessageInput` to take `previousResults: List<ToolResult>` instead of separate `previousResults` and `relevantIssues` lists
- **Removed** `_extractRelevantIssues` method from `DefaultOpenAiToolService`
- **Modified** `_buildSystemMessage` to clearly show which outputs map to which issues by iterating through ToolResult objects

### 3. Keep Structured Objects Until Last Moment
- **Maintain** `ToolResult` objects through the pipeline
- **Convert to JSON** only in `_buildOpenAiRequest` when building the actual API request
- **Updated** serialization to use `_previous_results` field containing full ToolResult JSON

### 4. Fail Fast on Typed Output Creation Errors
- **Added** check for `ToolOutputRegistry.hasTypedOutput()` before attempting creation
- **Throw exception** if typed output creation fails when a creator is registered
- This ensures users get clear feedback when their typed output definitions have issues

### 5. Use Named Parameters for Private Methods
- **Updated** all private methods in `ToolFlow` to use named parameters:
  - `_buildStepInput({required ToolCallStep step, required int stepIndex, required int round})`
  - `_executeStep({required ToolCallStep step, required int stepIndex, required int round})`
  - `_runAuditsForStep({required ToolResult result, required StepConfig stepConfig, required int stepIndex})`
  - `_getIncludedResults({required StepConfig stepConfig})`

## Alternatives Considered

### Keep StepInput as Separate Class
- **Rejected**: Would maintain unnecessary duplication
- **Reasoning**: No functional difference between StepInput and ToolInput

### Continue Passing Separate Lists
- **Rejected**: Violates DRY principle and increases complexity
- **Reasoning**: ToolResult already contains both output and issues

### Convert to JSON Earlier
- **Rejected**: Loses type safety and makes debugging harder
- **Reasoning**: Structured objects are easier to work with and debug

## Consequences

### Positive
- **Reduced Complexity**: Single interface instead of two
- **Better Type Safety**: Structured objects maintained longer
- **Clearer Relationships**: Output-to-issue mapping is explicit in system messages
- **Fail Fast**: Typed output errors are caught immediately
- **Better Code Clarity**: Named parameters make method calls self-documenting

### Negative
- **Breaking Change**: Any external code using StepInput will need updates
- **Migration Required**: Existing serialized data with `_previous_issues` needs migration to `_previous_results`
- **Slightly Larger Payloads**: Sending full ToolResult objects instead of just issues

## Implementation Notes

- **Backward Compatibility**: Not maintained per Round 5 instructions (version 0.0)
- **Test Updates**: All tests updated to reflect new interface
- **Serialization Format**: Changed from `_previous_issues` to `_previous_results` in ToolInput.toMap()
- **Message Building**: System messages now clearly delineate which issues belong to which outputs

## References

- **Round 5 Requirements**: `docs/round_5/REQUESTED_UPDATES.md`
- **Implementation**: 
  - `lib/src/typed_interfaces.dart` - Interface consolidation
  - `lib/src/tool_flow.dart` - Private method updates and error handling
  - `lib/src/openai_service.dart` - SystemMessageInput changes
  - `lib/src/openai_service_impl.dart` - Message building updates
  - `test/openai_toolflow_test.dart` - Test updates