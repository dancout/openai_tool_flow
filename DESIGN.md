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

## Design Principles

- **Strict Schemas, Extensible by Subclassing**: All core classes (`ToolResult`, `Issue`) enforce required fields but allow super projects to add custom fields via subclassing. The pipeline forwards all fields using `toJson()`, ensuring no data loss.
- **Separation of Concerns**: Auditing logic is not implemented in this package. Instead, developers subclass `AuditFunction` and provide their own audit logic.
- **Configurable and Secure**: API keys and model defaults are loaded from environment variables or `.env` files using `OpenAIConfig`.
- **Model Flexibility**: Each tool call step can specify its own model and parameters, supporting future OpenAI model changes.
- **Structured Outputs**: Every step returns a `ToolResult` with a predictable schema, never raw OpenAI responses.
- **Pipeline Chaining**: The package enables chaining tool calls and audits, passing structured issues between steps.
- Passing outputs from one step into the next
- Collecting issues from audits
- Providing structured results at the end