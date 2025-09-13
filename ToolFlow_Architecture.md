# ToolFlow Architecture

This document explains how the ToolFlow pipeline works from user input to tool call step data manipulation to conversions to OpenAI API tool calls to the final ToolFlowResult.

## Overview

ToolFlow is a Dart package for orchestrating OpenAI tool calls with audits, enabling chaining of tool calls where each step can pass structured outputs or issues to later steps. The architecture provides type safety, audit functions, retry logic, and comprehensive state management.

## Core Components

### 1. ToolFlow (Main Orchestrator)
The central class that manages the entire workflow execution:

- **Purpose**: Orchestrates ordered execution of tool call steps with internal state management
- **Key Features**:
  - Executes steps in order
  - Manages internal state across steps
  - Collects issues from audits
  - Implements retry logic with configurable attempts
  - Provides structured results at the end
  - Supports dependency injection for OpenAI service (for testing)

### 2. ToolCallStep (Step Definition)
Defines a single tool call step in a ToolFlow:

- **Components**:
  - `toolName`: Name of the tool to call
  - `toolDescription`: Description for OpenAI tool function
  - `model`: OpenAI model to use (optional, falls back to config)
  - `inputBuilder`: Function to build step input from previous results
  - `includeResultsInToolcall`: List of step indices to include outputs/issues from
  - `stepConfig`: Configuration for audits, retries, sanitization
  - `outputSchema`: Schema definition for expected tool output

### 3. OpenAiToolService (API Interface)
Abstract interface for OpenAI tool execution with two implementations:

- **DefaultOpenAiToolService**: Makes actual API calls to OpenAI
- **MockOpenAiToolService**: Returns predefined responses for testing

### 4. StepConfig (Step Configuration)
Configuration for individual steps including:

- **Audit Functions**: Validation functions to run on outputs
- **Retry Logic**: Maximum retry attempts and pass/fail criteria
- **Token Management**: Max tokens for this specific step
- **Issue Filtering**: Severity level for including issues in system messages
- **Sanitization**: Input/output transformation functions

### 5. Typed Interfaces
Type-safe interfaces for inputs and outputs:

- **ToolInput**: Structured input parameters with round tracking
- **ToolOutput**: Base class for typed tool outputs
- **StepDefinition**: Interface for defining tool metadata and factory methods
- **ToolOutputRegistry**: Registry for creating typed outputs from results

## Execution Flow

### Phase 1: Initialization
1. **ToolFlow Creation**: User creates ToolFlow with config and list of ToolCallStep objects
2. **Service Injection**: OpenAI service is injected (default or mock for testing)
3. **State Setup**: Internal state map and step attempts storage are initialized

### Phase 2: Input Processing
1. **Input Validation**: User input is validated and stored in internal state
2. **Initial Result Creation**: Input is converted to TypedToolResult at index 0
3. **Storage Structure**: List<List<TypedToolResult>> where:
   - Index 0: Initial input
   - Index 1+: Step attempts (each inner list contains all retry attempts)

### Phase 3: Step Execution (Per Step)
For each ToolCallStep in the workflow:

#### 3.1 Input Building
1. **Previous Results Gathering**: Collect final attempts from all previous steps
2. **InputBuilder Execution**: 
   - If `inputBuilder` provided: Execute with previous results
   - If not provided: Use previous step's output as input
3. **Input Sanitization**: Apply `inputSanitizer` if configured

#### 3.2 Tool Call Preparation
1. **OpenAI Request Building**:
   - Create tool definition from step's outputSchema
   - Build system message with context from included results
   - Build user message from structured input
   - Handle model-specific parameters (GPT-5+ vs older models)

2. **Context Assembly**:
   - Include results from steps specified in `includeResultsInToolcall`
   - Apply severity filtering to issues
   - Include current step retry attempts for context

#### 3.3 API Execution
1. **Tool Call Execution**: OpenAI service executes the tool call
2. **Response Processing**: Extract tool output and usage information
3. **Output Sanitization**: Apply `outputSanitizer` if configured

#### 3.4 Type Safety & Validation
1. **Typed Output Creation**: Use ToolOutputRegistry to create typed output
2. **Audit Execution**: Run all configured audit functions on the output
3. **Issue Collection**: Gather issues from audits with round information

#### 3.5 Retry Logic
1. **Pass/Fail Determination**: Check if step passes criteria based on audit results
2. **Retry Handling**: If failed and retries available:
   - Store failed attempt
   - Log retry reason
   - Attempt again with updated context
3. **Error Handling**: Convert exceptions to error results

### Phase 4: State Management
1. **Result Storage**: Store all attempts (successful and failed) by step
2. **State Updates**: Update internal state with step results and outputs
3. **Token Aggregation**: Accumulate token usage across all steps

### Phase 5: Flow Control
1. **Stop on Failure**: If step fails and `stopOnFailure` is true, halt execution
2. **Continue on Success**: Move to next step with updated state
3. **Error Propagation**: Handle and log critical errors

### Phase 6: Result Assembly
1. **Final Result Creation**: Create ToolFlowResult with:
   - All step attempts organized by step
   - Final state map
   - Token usage aggregation
   - Issue summaries
2. **Result Structure**:
   - `results`: List<List<TypedToolResult>> (all attempts by step)
   - `finalResults`: List<TypedToolResult> (final attempt of each step)
   - `finalState`: Map<String, dynamic> (accumulated state)
   - `allIssues`: List<Issue> (all issues from all attempts)

## Data Flow Transformations

### 1. User Input → Initial TypedToolResult
```dart
Map<String, dynamic> userInput
↓ (ToolFlow.run)
ToolInput initialInput 
↓ (wrapped)
ToolResult<ToolOutput> initialResult
↓ (type wrapper)
TypedToolResult initialTypedResult (stored at index 0)
```

### 2. Step Input Building
```dart
List<TypedToolResult> previousResults
↓ (inputBuilder function)
Map<String, dynamic> customData
↓ (ToolInput constructor)
ToolInput stepInput
↓ (input sanitization)
ToolInput sanitizedInput
```

### 3. OpenAI API Call
```dart
ToolCallStep + ToolInput
↓ (build tool definition)
Map<String, dynamic> toolDefinition
↓ (build system/user messages)
OpenAiRequest request
↓ (HTTP POST to OpenAI)
Map<String, dynamic> apiResponse
↓ (extract tool call)
ToolCallResponse (output + usage)
```

### 4. Output Processing
```dart
Map<String, dynamic> rawOutput
↓ (output sanitization)
Map<String, dynamic> sanitizedOutput
↓ (ToolOutputRegistry.create)
ToolOutput typedOutput
↓ (audit execution)
AuditResults auditResults
↓ (result assembly)
ToolResult<ToolOutput> result
↓ (type wrapper)
TypedToolResult finalResult
```

## Key Architectural Patterns

### 1. Dependency Injection
- OpenAI service can be injected for testing
- Enables mock responses and API call isolation

### 2. Type Safety with Backward Compatibility
- Strongly typed interfaces (ToolInput/ToolOutput)
- Registry pattern for type-safe output creation
- Graceful fallbacks for edge cases

### 3. Audit-Driven Validation
- Configurable audit functions per step
- Issue tracking with severity levels
- Custom pass/fail criteria

### 4. Comprehensive Retry Logic
- Per-step retry configuration
- Context-aware retry attempts
- Issue forwarding between attempts

### 5. State Accumulation
- Internal state management across steps
- Token usage tracking
- Result history preservation

### 6. Flexible Input Composition
- Dynamic input building from previous results
- Selective result inclusion in tool calls
- Input/output sanitization hooks

## Error Handling

### 1. Tool Execution Errors
- Wrapped in error ToolResult objects
- Converted to critical issues
- Retry logic still applies

### 2. Type Safety Errors
- Registry validation for typed outputs
- Clear error messages for missing registrations
- Fail-fast on configuration errors

### 3. API Errors
- HTTP error handling with status codes
- Token limit handling (finish_reason: 'length')
- Malformed response handling

### 4. Audit Execution Errors
- Caught and converted to audit execution issues
- Detailed error context for debugging
- System continues with error documentation

## Performance Considerations

### 1. Token Optimization
- Severity filtering for issue inclusion
- Configurable result inclusion
- Efficient state management

### 2. Memory Management
- Result storage organized by step
- Cleanup of sensitive data
- Efficient state accumulation

### 3. API Efficiency
- Single API call per step attempt
- Proper model parameter handling
- Usage tracking for cost monitoring

This architecture provides a robust, type-safe, and extensible framework for orchestrating complex OpenAI tool call workflows while maintaining clear separation of concerns and comprehensive error handling.