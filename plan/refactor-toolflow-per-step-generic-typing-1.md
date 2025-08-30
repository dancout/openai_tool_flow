---
goal: Refactor ToolFlow for Per-Step Generic ToolResult Typing and Audit Compatibility
version: 1.0
date_created: 2025-08-29
last_updated: 2025-08-29
owner: Daniel Couturier
tags: [refactor, generics, architecture, audit, bugfix, type-safety]
---
# Introduction

This plan refactors the `ToolFlow` orchestration system to support per-step generic typing for `ToolResult<T extends ToolOutput>`, enabling type-safe audit execution and eliminating runtime type errors. The goal is to propagate the correct output type for each tool step, ensuring that audits receive the expected typed result and that the system remains extensible and robust.

# Context
The current `ToolFlow` orchestration system manages a sequence of tool steps, each producing a result (`ToolResult<ToolOutput>`) and optionally running audits on that result. However, each tool step may produce a different output type (e.g., `PaletteExtractionOutput`, `SomeOtherOutput`), and audits expect to receive the specific typed result for their tool.

Currently, the system erases this type information by storing all results as `ToolResult<ToolOutput>`, which leads to runtime type errors when an audit expects a specific output type but receives a generic one. This breaks type safety and makes the system fragile and hard to extend.

The goal of this refactor is to propagate the correct output type for each tool step throughout the orchestration and audit system. Each step should produce and store a `ToolResult<T extends ToolOutput>`, and audits should receive the correct typed result. This requires changes to the orchestration logic, result storage, and audit interfaces to support heterogeneous types in a type-safe manner, leveraging Dart's generics and type registries.

The end result should be a robust, extensible, and type-safe system where each audit receives exactly the result type it expects, and the orchestration logic can handle flows with multiple steps producing different output types.


## 1. Requirements & Constraints
- **REQ-001**: Each tool step must produce a `ToolResult<T extends ToolOutput>` with the correct type parameter for its output.
- **REQ-002**: Audits must receive the correct typed result for their associated tool, matching the expected output type.
- **REQ-003**: The orchestration logic must support multiple steps with different output types in a single flow.
- **REQ-004**: The refactor must maintain backward compatibility for existing tool definitions and audit implementations.
- **CON-001**: Dart’s type system does not allow runtime generic type inference; explicit type propagation is required.
- **CON-002**: All changes must be limited to the `/lib/src/tool_flow.dart` and related type/interface files.
- **PAT-001**: Use factory methods, type registries, or wrapper classes to propagate type information.
- **GUD-001**: All new code must be fully documented and tested.
- **SEC-001**: No dynamic casting that could cause runtime type errors.
- **CON-003**: Do not use `List<dynamic>` for result storage; results must be stored in a type-safe structure that preserves access to common fields (e.g., issues, toolName).

## 2. Implementation Steps

### Implementation Phase 1

- GOAL-001: Refactor ToolFlow to support per-step generic ToolResult typing and type-safe audit execution.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Analyze all usages of `ToolResult<ToolOutput>` in `/lib/src/tool_flow.dart` and related files. Document every location where type information is lost or erased. | | |
| TASK-002 | Refactor the `ToolCallStep`, `StepConfig`, and `Audit` interfaces/classes to include an explicit type parameter for the expected output type. Ensure that each step and audit knows its output type. | | |
| TASK-003 | Update the `ToolFlow.run` method to instantiate and store each step’s result as `ToolResult<T extends ToolOutput>`, using the correct type for each step. Use a type registry or factory to obtain the type at runtime. | | |
| TASK-004 | Refactor the `_executeStep` and `_runAuditsForStep` methods to propagate the correct type parameter, ensuring that audits receive the expected typed result. | | |
| TASK-005 | Update all result storage collections (`_results`, `_resultsByToolName`, `_allResultsByToolName`) to support heterogeneous types, using a wrapper class, union type, or type registry. Document the chosen approach. | | |
| TASK-006 | Refactor the `ToolFlowResult` class to support retrieval of typed results per tool, updating all relevant methods and documentation. | | |
| TASK-007 | Update all usages of result retrieval and audit execution throughout the codebase to use the new type-safe interfaces. | | |
| TASK-008 | Add comprehensive documentation to all new and modified classes, methods, and interfaces, explaining the type propagation mechanism and usage patterns. | | |

### Implementation Phase 2

- GOAL-002: Validate, test, and document the refactor for correctness and maintainability.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-009 | Implement unit and integration tests for multi-step flows with heterogeneous output types, verifying that audits receive the correct typed results and that no runtime type errors occur. | | |
| TASK-010 | Validate backward compatibility by running all existing tests and flows, ensuring that legacy tool definitions and audits continue to work. | | |
| TASK-011 | Update or create new test cases for edge scenarios, such as steps with missing type information, audit failures, and mixed-type result retrieval. | | |
| TASK-012 | Review and update all documentation, including README, ADRs, and code comments, to reflect the new type propagation architecture. | | |
| TASK-013 | Perform a final code review and static analysis to ensure type safety, code quality, and maintainability. | | |

## 3. Alternatives

- **ALT-001**: Use dynamic casting and runtime type checks for audit execution. Rejected due to risk of runtime errors and loss of type safety.
- **ALT-002**: Refactor the entire flow to use a single output type for all steps. Rejected as it eliminates extensibility and type safety for heterogeneous tool outputs.

- **ALT-003**: Use `List<dynamic>` for result storage. Rejected because it loses type safety and makes it difficult to access common result fields in a structured way.

## 4. Dependencies

- **DEP-001**: Existing type registry or factory for tool output types (e.g., `ToolOutputRegistry`).
- **DEP-002**: All related type/interface files: `tool_result.dart`, `tool_output.dart`, `step_config.dart`, `audit_function.dart`, etc.
- **DEP-003**: Existing test suite for ToolFlow and audits.

## 5. Files

- **FILE-001**: `/lib/src/tool_flow.dart` — Main orchestration logic and result storage.
- **FILE-002**: `/lib/src/tool_result.dart` — Generic result type definition.
- **FILE-003**: `/lib/src/step_config.dart` — Step configuration and audit interface.
- **FILE-004**: `/lib/src/audit_function.dart` — Audit function interface and implementation.
- **FILE-005**: `/lib/src/typed_interfaces.dart` — Type registry and output type definitions.
- **FILE-006**: `/test/openai_toolflow_test.dart` — Test cases for multi-step flows and audits.

## 6. Testing

- **TEST-001**: Unit tests for flows with multiple steps, each producing a different output type, verifying correct type propagation and audit execution.
- **TEST-002**: Integration tests for audit functions, ensuring they receive the correct typed result and produce expected issues.
- **TEST-003**: Regression tests for legacy flows and audits, verifying backward compatibility.
- **TEST-004**: Edge case tests for missing type information, audit failures, and mixed-type result retrieval.

## 7. Risks & Assumptions

- **RISK-001**: Refactor may introduce breaking changes if not carefully managed; thorough testing is required.
- **RISK-002**: Dart’s type system limitations may require workarounds for runtime type propagation.
- **ASSUMPTION-001**: All tool output types are registered and accessible via a type registry or factory.
- **ASSUMPTION-002**: Existing audits and tool definitions follow the expected interface contracts.

## 8. Related Specifications / Further Reading

- [ADR: Strongly Typed Interfaces](docs/round_2/adr/adr-0002-strongly-typed-interfaces.md)
- [ADR: Per-Step Audit System](docs/round_2/adr/adr-0003-per-step-audit-system.md)
- [Dart Generics Documentation](https://dart.dev/guides/language/language-tour#generics)
- [ToolOutputRegistry Implementation](lib/src/typed_interfaces.dart)
- [ADR-0001: ToolFlow Per-Step Generic Typing](docs/round_8/adr/adr-0001-toolflow-per-step-generic-typing.md)
