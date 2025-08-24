You are GitHub’s coding agent. Scaffold a Dart package called `openai_toolflow` with the following requirements:

## Project Usage Context

This project is intended to be published as a package on [pub.dev](https://pub.dev/) and imported by other Dart/Flutter projects.

**Note:** Audit function definitions and similar responsibilities are delegated to the super (importing) project, not this package.

- **Purpose**: Orchestrate OpenAI tool calls in a flow, with audits generating structured issues that feed into later calls.
- **Core Classes**:
  - `ToolFlow` (manages ordered execution of steps, internal state)
  - `ToolCallStep` (defines one tool call: toolName, model, params)
  - `ToolResult` (structured output of a step, with required fields but extensible by subclassing)
  - `Issue` (strict schema with required fields, extensible by subclassing)
  - `AuditFunction` (abstract class: developers implement `List<Issue> run(ToolResult)`)

- **Extensibility**:
  - Both `ToolResult` and `Issue` must have a **strict but extensible class design**.
  - Core fields are required, but super projects can extend them (by subclassing).
  - The pipeline **always forwards all fields** by calling `toJson()`. It should never discard unknown fields.

- **Config**: Provide `OpenAIConfig` that can load API key + defaults from `.env` or environment variables.
- **Outputs**: All steps must return structured `ToolResult`, not raw OpenAI responses.
- **Models**: Support specifying different OpenAI models (`gpt-4.1`, `gpt-5`, etc.) and their unique params (e.g., `temperature`, `max_tokens` vs `max_completion_tokens`).
- **Example**: Provide `example/usage.dart` showing how to chain tool calls (like extracting a color palette from an image and running audits).

## Design Principles

Refer to the following files for further context and examples:
- `COLOR_THEME_EXAMPLE.md`
- `CONTEXTUAL_COLOR_THEME_EXAMPLE.md`
- `DESIGN.md`
- `ISSUE_SCHEMA.md`
- `README.md`
##

Also create the following files:
- `example/usage.dart` (sample pipeline)