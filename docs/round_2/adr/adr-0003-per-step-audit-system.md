---
title: "ADR-0003: Per-Step Audit System and Configurable Retry Logic"
status: "Accepted"
date: "2024-12-19"
authors: ["AI Assistant", "Package Maintainer"]
tags: ["architecture", "audits", "retry", "validation"]
supersedes: ""
superseded_by: ""
---

# ADR-0003: Per-Step Audit System and Configurable Retry Logic

## Status

**Accepted**

## Context

The original design ran all audit functions on every step, which was inefficient and didn't allow for step-specific validation requirements. Users requested:

- Audits assigned to specific steps rather than global execution
- Custom pass/fail criteria beyond simple issue presence
- Configurable retry logic with different thresholds per step
- Issue tracking across retry attempts to avoid regression
- Weighted scoring systems for complex validation scenarios

The challenge was designing a flexible system that supports various audit strategies while maintaining simplicity for basic use cases.

## Decision

**Implement StepConfig-based audit system with configurable retry logic and issue tracking.**

The solution provides:

1. **StepConfig Class**: Per-step configuration for audits, retries, and criteria
2. **Enhanced AuditFunction**: Added `passedCriteria()` and `getFailureReason()` methods
3. **Retry Logic**: Automatic retries based on audit pass/fail criteria with round tracking
4. **Issue Round Tracking**: Issues tagged with round number and related data
5. **Custom Criteria**: Override default pass/fail logic per step or audit
6. **Weighted Scoring**: Support for complex validation scenarios
7. **Backward Compatibility**: Legacy global audits still supported

## Consequences

### Positive

- **POS-001**: **Granular Control**: Different audit requirements per step enable more precise validation
- **POS-002**: **Efficient Execution**: Only relevant audits run for each step, improving performance
- **POS-003**: **Flexible Retry Logic**: Configurable attempts and criteria per step
- **POS-004**: **Issue Tracking**: Round-based tracking prevents regression and provides debugging context
- **POS-005**: **Custom Criteria**: Teams can implement domain-specific pass/fail logic
- **POS-006**: **Weighted Scoring**: Complex validation scenarios with severity-based thresholds
- **POS-007**: **Debugging Support**: Rich issue context with related data and round information

### Negative

- **NEG-001**: **Configuration Complexity**: StepConfig setup requires more upfront planning
- **NEG-002**: **Learning Curve**: Multiple configuration options may overwhelm simple use cases
- **NEG-003**: **Memory Usage**: Issue tracking across rounds increases memory footprint
- **NEG-004**: **Testing Complexity**: More configuration paths require comprehensive testing

## Alternatives Considered

### Global Audit with Conditional Logic

- **ALT-001**: **Description**: Keep global audits but add conditional logic based on step index
- **ALT-002**: **Rejection Reason**: Creates tight coupling between audits and specific steps, harder to maintain

### Simple Step-Audit Mapping

- **ALT-003**: **Description**: Basic Map<int, List<AuditFunction>> without additional configuration
- **ALT-004**: **Rejection Reason**: Doesn't support custom retry logic or pass/fail criteria

### Builder Pattern for Configuration

- **ALT-005**: **Description**: Use builder pattern for constructing step configurations
- **ALT-006**: **Rejection Reason**: More verbose than constructor approach, doesn't add significant value

### Annotation-Based Configuration

- **ALT-007**: **Description**: Use annotations on ToolCallStep to define audit requirements
- **ALT-008**: **Rejection Reason**: Less explicit, harder to see configuration at runtime

## Implementation Notes

- **IMP-001**: **StepConfig Factory Methods**: Convenience constructors for common configurations
- **IMP-002**: **Extension Methods**: `StepConfigExtension` provides helper methods for configuration maps
- **IMP-003**: **Round Tracking**: Issues include round number and related data for debugging
- **IMP-004**: **Backward Compatibility**: Existing `ToolFlow.audits` parameter still functions
- **IMP-005**: **Weighted Scoring**: Example implementation in `ColorDiversityAuditFunction`
- **IMP-006**: **Custom Criteria**: Support for both step-level and audit-level pass/fail logic
- **IMP-007**: **Failure Handling**: Configurable stop-on-failure behavior per step

## Examples

### Basic Per-Step Configuration
```dart
final stepConfigs = {
  0: StepConfig.withAudits([diversityAudit]),
  1: StepConfig.withRetries(maxRetries: 5, audits: [formatAudit]),
  2: StepConfig.noAudits(),
};
```

### Custom Criteria Configuration
```dart
final stepConfig = StepConfig.withCustomCriteria(
  passedCriteria: (issues) => issues.length < 3,
  failureReason: (issues) => 'Too many issues: ${issues.length}',
);
```

### Weighted Scoring Example
```dart
bool passedCriteria(List<Issue> issues) {
  double weight = 0.0;
  for (final issue in issues) {
    weight += issue.severity == IssueSeverity.critical ? 8.0 : 1.0;
  }
  return weight <= 5.0;
}
```

## References

- **REF-001**: Configuration pattern best practices in Dart
- **REF-002**: Retry logic patterns and exponential backoff strategies
- **REF-003**: Audit trail and issue tracking system design