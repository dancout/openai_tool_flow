---
title: "ADR-0022: Local Step Execution without LLM Calls"
status: "Accepted"
date: "2025-11-01"
authors: "AI Agent"
tags: ["architecture", "decision", "local-execution", "computation"]
supersedes: ""
superseded_by: ""
adr_references: ["ADR-0002", "ADR-0012"]
used_as_resource_in: []
---

# ADR-0022: Local Step Execution without LLM Calls

## Status

**Accepted**

## Context

The ToolFlow library currently executes all steps through ToolCallStep, which makes LLM API calls via OpenAI. For certain operations like mathematical transformations, data processing, or generating variations of existing data (e.g., adjusting hex color values), it's more efficient and reliable to compute results locally rather than:
- Consuming API tokens
- Risking LLM hallucinations or inconsistencies
- Introducing network latency
- Depending on external API availability

**Use Case Example:**
- Step 1: LLM generates 5 base colors
- Steps 2-6: Locally compute 4 variations of each base color by adjusting hex values mathematically
- Step 7: LLM uses all colors (base + variations) to generate a comprehensive design system

This pattern reduces token usage while maintaining workflow orchestration benefits.

**Technical Requirements:**
- Execute computation locally without LLM API calls
- Maintain same interface as ToolCallStep (audits, retries, input builders, output schema)
- Support zero token tracking
- Allow local step results to flow to downstream steps
- Fit seamlessly into existing ToolFlow execution model

## Decision

We will implement a **LocalStep** class that:
1. Executes user-defined computation functions locally (async for consistency)
2. Maintains the same interface contract as ToolCallStep
3. Tracks TokenUsage.zero() for all executions
4. Supports the same features: audits, retries, input builders, output schema, step configuration
5. Produces ToolResult with identical structure to LLM steps

**Implementation approach:**
- Create `LocalStep` class parallel to `ToolCallStep`
- Add `LocalStepDefinition<T>` interface extending `StepDefinition<T>` with computation function
- Use factory pattern `LocalStep.fromStepDefinition()` for consistency
- ToolFlow handles both step types through polymorphism or type checking
- Computation function signature: `Future<Map<String, dynamic>> Function(Map<String, dynamic> input)`

**Naming rationale:**
- "LocalStep" clearly indicates execution happens locally
- Alternatives considered: "ComputedStep" (ambiguous), "SyntheticStep" (unclear meaning)
- "LocalStep" parallels industry terminology (local vs. remote execution)

## Consequences

### Positive

- **POS-001**: Significant token cost reduction for mathematical/deterministic operations
- **POS-002**: Eliminates LLM hallucination risk for deterministic computations
- **POS-003**: Faster execution (no network latency) for local operations
- **POS-004**: Maintains consistent workflow orchestration and debugging experience
- **POS-005**: Supports mixing LLM and local steps seamlessly in same workflow
- **POS-006**: Enables complex multi-step workflows with efficiency optimization
- **POS-007**: Zero token tracking provides accurate cost attribution

### Negative

- **NEG-001**: Adds another step type to understand and maintain
- **NEG-002**: Developers need to choose between LocalStep and ToolCallStep appropriately
- **NEG-003**: ToolFlow execution logic becomes slightly more complex (type handling)
- **NEG-004**: Computation function errors must be handled carefully (no LLM retry fallback)

## Alternatives Considered

### Alternative 1: Pre/Post Processing Hooks on ToolCallStep

- **ALT-001**: **Description**: Add preprocessing/postprocessing hooks to ToolCallStep that run before/after LLM calls
- **ALT-002**: **Rejection Reason**: This doesn't eliminate LLM calls entirely, still consumes tokens. Hooks are for transformation, not replacement. Creates confusion about what runs locally vs. remotely.

### Alternative 2: Special LLM Model Name (e.g., "local")

- **ALT-003**: **Description**: Use a special model name like "local" or "compute" to trigger local execution path within ToolCallStep
- **ALT-004**: **Rejection Reason**: Abuses the model parameter semantics. Makes code harder to understand. Doesn't provide type safety or clear API for computation functions.

### Alternative 3: Middleware/Plugin System

- **ALT-005**: **Description**: Implement a middleware/plugin system where steps can be intercepted and executed differently
- **ALT-006**: **Rejection Reason**: Over-engineered for this use case. Adds significant complexity. Current need is simple: run a function locally instead of calling LLM.

### Alternative 4: Async vs. Sync Computation Function

- **ALT-007**: **Description**: Make computation function synchronous (`Map<String, dynamic> Function(Map<String, dynamic>)`) since no I/O is expected
- **ALT-008**: **Rejection Reason**: While many computations are synchronous, async provides flexibility for future needs (e.g., reading from local cache, complex processing). Consistency with LLM steps (which are async) simplifies ToolFlow logic. Minimal overhead for async wrapper.

## Implementation Notes

- **IMP-001**: LocalStep will be defined in `lib/src/local_step.dart`
- **IMP-002**: LocalStepDefinition extends StepDefinition and adds computation function
- **IMP-003**: ToolFlow._executeStep() will check step type and route to appropriate execution path
- **IMP-004**: All LocalStep executions return TokenUsage.zero()
- **IMP-005**: LocalStep supports all StepConfig features: audits, retries, input/output sanitizers
- **IMP-006**: Retry logic applies if local computation fails validation (audits)
- **IMP-007**: LocalStep uses same ToolOutputRegistry registration as ToolCallStep

## References

- **REF-001**: ADR-0002 - Strongly-Typed Tool Interfaces (establishes ToolInput/ToolOutput/StepDefinition patterns)
- **REF-002**: ADR-0012 - Step Definition Pattern (establishes fromStepDefinition factory pattern)
- **REF-003**: Round 22 REQUESTED_UPDATES.md - Original feature request
