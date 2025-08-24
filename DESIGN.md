# Design Overview

## Core Concepts
- **Tool Call**: A single OpenAI model invocation with specified parameters.
- **Tool Flow**: An ordered set of tool calls where each step can consume:
  - Prior outputs
  - Prior issues (from audits)
- **Audit Function**: An abstract class that developers implement. An audit inspects tool outputs and produces `Issue` objects.

## Data Structures
- `ToolResult`
  - `toolName`
  - `input`
  - `output`
  - `issues: List<Issue>`
- `Issue`
  - `id`
  - `severity`
  - `description`
  - `context`
  - `suggestions`

## Extensibility
- **Audits**: Implement `AuditFunction` with `List<Issue> run(ToolResult result)`.
- **Schemas**: Issue schema is strict but can be extended with custom fields.
- **Config**: `OpenAIConfig` loads from `.env` or programmatically.

## State Handling
The `ToolFlow` orchestrator manages:
- Passing outputs from one step into the next
- Collecting issues from audits
- Providing structured results at the end