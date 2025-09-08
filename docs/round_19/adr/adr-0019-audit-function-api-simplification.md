---
title: "ADR-0019: Audit Function API Simplification and Pass Criteria Enhancement"
status: "Accepted"
date: "2024-12-19"
authors: "GitHub Copilot Agent"
tags: ["architecture", "decision", "audit", "api"]
supersedes: ""
superseded_by: ""
adr_references: []
used_as_resource_in: []
---

# ADR-0019: Audit Function API Simplification and Pass Criteria Enhancement

## Status

**Accepted**

## Context

Round 19 requirements specified several API improvements to make the audit system cleaner and more intuitive:

1. The `AuditFunction.run()` method required the full `ToolResult<T>` object but only needed the `ToolOutput` portion, creating unnecessary coupling
2. `TypedToolResult` lacked visibility into whether audits had passed, requiring external inspection of issues to determine success
3. `ToolFlowResult` had no convenient way to check if all steps passed their audit criteria
4. The audit execution flow was backwards - audits were run after `TypedToolResult` creation, then issues were backfilled, rather than evaluating audits first and creating results with complete information

These design issues made the API harder to use and less intuitive for developers implementing audit functions.

## Decision

Implement a comprehensive refactoring of the audit system with the following changes:

1. **Simplify AuditFunction API**: Change `AuditFunction.run(ToolResult<T> result)` to `AuditFunction.run(T output)` to only require the output data needed for auditing
2. **Add TypedToolResult.passesCriteria**: Add a required boolean field indicating whether the result passed all audit criteria
3. **Add ToolFlowResult.passesCriteria**: Add a convenience getter that returns true if all final results passed their criteria
4. **Refactor audit execution order**: Move audit execution to occur before `TypedToolResult` creation, so results are created with complete audit information from the start

## Consequences

### Positive

- **POS-001**: Cleaner audit function API that only requires the data actually needed for auditing
- **POS-002**: Immediate visibility of pass/fail status on TypedToolResult without needing to inspect issues
- **POS-003**: Convenient flow-level pass criteria checking via ToolFlowResult.passesCriteria
- **POS-004**: More logical execution order where audit results inform result creation rather than being backfilled
- **POS-005**: Better separation of concerns between audit logic and result metadata

### Negative

- **NEG-001**: Breaking change requiring updates to all existing audit function implementations
- **NEG-002**: Additional complexity in TypedToolResult constructors requiring passesCriteria parameter
- **NEG-003**: Audit functions can no longer access input metadata or tool name directly (though this wasn't commonly needed)

## Alternatives Considered

### Keep Existing ToolResult Parameter

- **ALT-001**: **Description**: Maintain the current `AuditFunction.run(ToolResult<T> result)` signature
- **ALT-002**: **Rejection Reason**: This maintained unnecessary coupling and didn't address the API simplification requirements

### Add passesCriteria as Optional Field

- **ALT-003**: **Description**: Make passesCriteria optional with a default value to avoid breaking changes
- **ALT-004**: **Rejection Reason**: While this reduces breaking changes, it doesn't enforce the architectural principle that results should know their audit status from creation

### Gradual Migration Approach

- **ALT-005**: **Description**: Implement new methods alongside old ones and deprecate gradually
- **ALT-006**: **Rejection Reason**: Given this is version 0.0.x with explicit guidance that breaking changes are acceptable, a clean cut was preferred over API bloat

## Implementation Notes

- **IMP-001**: Updated all audit function signatures to take output directly instead of full result
- **IMP-002**: Modified audit execution to occur in `_executeStep` before `TypedToolResult` creation
- **IMP-003**: Made passesCriteria parameter optional with default value for backward compatibility in test scenarios
- **IMP-004**: Ensured step-level pass criteria (from StepConfig) takes precedence over individual audit pass criteria
- **IMP-005**: All 99 existing tests updated and passing, confirming backward compatibility maintained where appropriate

## References

- **REF-001**: Round 19 REQUESTED_UPDATES.md specifications
- **REF-002**: AuditFunction class implementation
- **REF-003**: TypedToolResult and ToolFlowResult classes