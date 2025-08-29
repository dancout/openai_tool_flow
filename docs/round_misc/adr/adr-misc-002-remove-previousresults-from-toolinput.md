---
title: "ADR-MISC-002: Remove PreviousResults from ToolInput in Favor of InputBuilder"
status: "Accepted"
date: "2025-08-28"
authors: ["DAN (Package maintainer, workflow architect)"]
tags: ["architecture", "decision", "ToolInput", "inputBuilder", "workflow"]
supersedes: ""
superseded_by: ""
adr_references: ["ADR-MISC-001", "ADR-0001"]
used_as_resource_in: []
description: "Architectural decision to remove the previousResults field from ToolInput and rely on inputBuilder for workflow context."
round: "MISC"
---

## Context

The openai_toolflow package orchestrates OpenAI tool calls in a pipeline, passing structured outputs and issues between steps. ToolInput previously included a previousResults field to carry context from prior steps. Recent design reviews and refactors have clarified that inputBuilder functions are responsible for constructing the input for each tool call, using previous results as needed. The package aims for explicit, auditable, and extensible workflow configuration.

## Decision

Remove the previousResults field from ToolInput. Instead, pass previous results directly to inputBuilder functions, which will extract and map relevant data for each tool call. ToolInput will only represent parameters for a single tool call, not workflow context.

## Alternatives

- **ALT-001:** Retain previousResults on ToolInput and hide context mapping logic inside ToolInput. (Rejected: Reduces clarity, limits extensibility, and couples input objects to workflow state.)
- **ALT-002:** Use a hybrid approach, keeping previousResults on ToolInput but also supporting inputBuilder. (Rejected: Adds complexity and ambiguity, with no clear benefit over inputBuilder-only.)

## Stakeholders

- DAN: Package maintainer, workflow architect
- Contributors: Developers extending or integrating openai_toolflow
- End Users: Dart/Flutter projects using the package for tool orchestration

## Consequences

- **POS-001:** API is cleaner and more focused; ToolInput only represents single-call parameters
- **POS-002:** Input construction logic is explicit, auditable, and easy to customize per step
- **NEG-001:** Slightly more responsibility on the user to handle previous results in inputBuilder
- **NEG-002:** Migration required for projects relying on previousResults in ToolInput

## Rejection Rationale

- Hiding previousResults inside ToolInput reduces transparency and makes input construction harder to debug and extend
- Hybrid approaches add complexity without clear benefits

## References

- ADR-MISC-001: Retain InputSanitizer for Framework-Level Input Transformation
- ADR-0001: Dynamic Input Builder Pattern

---
