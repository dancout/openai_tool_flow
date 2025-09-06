---
title: "ADR-0001: Comprehensive Retry Attempt Tracking and System Message Enhancement"
status: "Accepted"
date: "2025-01-27"
authors: ["AI Assistant", "dancout (Package maintainer)"]
tags: ["architecture", "decision", "retry", "system-message", "toolflow", "debugging"]
supersedes: ""
superseded_by: ""
adr_references: ["ADR-MISC-002", "ADR-0001"]
used_as_resource_in: []
description: "Architectural decision to track all retry attempts and enhance system messages with both previous step results and current step retry attempts."
round: "17"
---

# ADR-0001: Comprehensive Retry Attempt Tracking and System Message Enhancement

## Status

**Accepted**

## Context

The openai_toolflow package orchestrates OpenAI tool calls with retry logic, but lacked comprehensive tracking and reporting of retry attempts. Several issues were identified:

- **Limited retry visibility**: Only the final successful/failed result was stored, losing context from intermediate retry attempts
- **Incomplete system message context**: Previous step results were included, but retry attempts from the current step were not visible in system messages
- **Debugging difficulties**: When tools failed after retries, users couldn't see the progression of outputs and issues across attempts
- **Missing output-issue correlation**: Users needed to see both outputs AND their corresponding issues from each retry attempt for effective debugging

The user specifically reported: "When there are issues related to outputs, we should be able to access both the output AND the corresponding issues from that particular output. Simply seeing the final output and all the accumulated issues is not acceptable because we are missing the context of why that issue may have arisen in the first place."

## Decision

Implement comprehensive retry attempt tracking and enhance system message generation to include both previous step results and current step retry attempts with severity filtering.

### Core Changes

1. **Retry Attempt Storage**: Store all retry attempts (including failed ones) in `ToolFlow._allAttempts` organized by step index
2. **Enhanced SystemMessageInput**: Add `currentStepRetries` field alongside existing `previousResults`
3. **System Message Distinction**: Clearly label "Previous step results" vs "Current step retry attempts" in system messages
4. **Severity Filtering**: Apply issue severity filtering to both previous results and retry attempts
5. **OpenAI Service Interface Extension**: Update `executeToolCall` to accept `currentStepRetries` parameter

### Implementation Details

- **Data Structure**: `Map<int, List<TypedToolResult>> _allAttempts` indexed by step position
- **Filtering Logic**: `_getCurrentStepAttempts()` method applies severity filtering to retry attempts
- **System Message Format**: Structured sections with clear headers and attempt numbering
- **Interface Compatibility**: Maintained backward compatibility with optional parameters

## Consequences

### Positive

- **POS-001**: Complete visibility into retry attempt progression for debugging and analysis
- **POS-002**: Enhanced system messages provide better context for subsequent tool calls
- **POS-003**: Clear separation between previous step context and current step retry history
- **POS-004**: Severity filtering ensures only relevant issues are included in system messages
- **POS-005**: Maintains existing `includeResultsInToolcall` functionality while adding retry context

### Negative

- **NEG-001**: Increased memory usage due to storing all retry attempts instead of just final results
- **NEG-002**: More complex system message generation logic with multiple data sources
- **NEG-003**: Additional computational overhead for filtering and formatting retry attempts
- **NEG-004**: Breaking changes to OpenAI service interface requiring updates to all implementations

## Alternatives Considered

### Store Only Failed Attempts

- **ALT-001**: **Description**: Track only failed retry attempts, excluding successful final results
- **ALT-002**: **Rejection Reason**: Users need to see the complete progression including the transition from failed to successful attempts

### Single System Message Section

- **ALT-003**: **Description**: Combine previous results and retry attempts into one section without distinction
- **ALT-004**: **Rejection Reason**: Reduces clarity about which context comes from previous steps vs current step retries

### Client-Side Retry Tracking

- **ALT-005**: **Description**: Let users implement their own retry tracking outside the framework
- **ALT-006**: **Rejection Reason**: Reduces framework value and creates inconsistent debugging experiences across implementations

## Implementation Notes

- **IMP-001**: Added `@visibleForTesting` getter `getStepAttempts()` for test verification without exposing internal state
- **IMP-002**: Updated all OpenAI service implementations (DefaultOpenAiToolService, MockOpenAiToolService) to match new interface
- **IMP-003**: Maintained original `includeResultsInToolcall` logic - only include results that have filtered issues matching severity criteria
- **IMP-004**: System message formatting uses attempt numbering (Attempt 1, Attempt 2) for clarity
- **IMP-005**: All retry attempts are stored immediately after execution, regardless of success/failure status

## References

- **REF-001**: Round 17 REQUESTED_UPDATES.md - User requirements for retry attempt tracking
- **REF-002**: ADR-MISC-002: Remove PreviousResults from ToolInput - Related system message architecture
- **REF-003**: ADR-0001: Dynamic Input Builder Pattern - Related to input construction and previous results
- **REF-004**: SystemMessageInput class in openai_service.dart - Core data structure enhanced
- **REF-005**: ToolFlow._buildSystemMessage implementation - System message generation logic