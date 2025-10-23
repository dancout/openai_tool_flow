# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2025-10-22

### Added
- Initial release of OpenAI ToolFlow package
- Sequential tool execution with OpenAI function calling
- Strong typing for all step inputs and outputs with schema validation
- Configurable retry logic with linear backoff per step
- Comprehensive audit system with custom validation functions
- Token usage tracking and aggregation across all steps and retries
- Flexible input building from previous step outputs
- Data sanitization with input/output sanitizers
- Issue management with severity levels (low, medium, high, critical)
- Professional color theme generator example workflow
- Detailed documentation and API reference

### Features
- `ToolFlow` - Main orchestrator for sequential tool execution
- `ToolCallStep` - Individual step definitions with configuration
- `StepConfig` - Per-step configuration including retries and audits
- `AuditFunction` - Custom validation with issue reporting
- `ToolOutput` - Strongly-typed output interfaces
- `StepDefinition` - Abstract base for defining step behavior
- `OpenAIConfig` - Configuration management with .env support
- `TokenUsage` - Comprehensive token tracking and reporting
- `Issue` - Rich issue reporting with severity and suggestions

[0.0.1]: https://github.com/dancout/openai_tool_flow/releases/tag/v0.0.1