# ADR Appendix

| ADR Title                                               | Round | Key Words                | Quick Summary                                                      |
|--------------------------------------------------------|-------|--------------------------|--------------------------------------------------------------------|
| ADR-0001: Dart Version Compatibility (3.8.1 vs 3.9.1)  | 2     | dart, compatibility      | Sets minimum Dart SDK to 3.8.1 for broader compatibility; no 3.9.1+ features used. |
| ADR-0002: Strongly-Typed Tool Interfaces and Backward Compatibility | 2 | typing, interfaces, ToolInput, ToolOutput, registry | Introduces opt-in strongly-typed tool interfaces with abstract base classes and registry, maintaining backward compatibility. |
| ADR-0003: Per-Step Audit System and Configurable Retry Logic | 2 | audits, StepConfig, retry, issue tracking, weighted scoring | Adds per-step audit configuration, custom retry logic, and round-based issue tracking for flexible validation and debugging. |
| ADR-0001: OpenAI Service Extraction and Dependency Injection | 3 | OpenAI, service, dependency injection, ToolFlow, request typing | Extracts OpenAI API logic into a dedicated service with dependency injection for testability, type safety, and maintainability. |
| ADR-0002: Issue Forwarding and Step Configuration Enhancement | 3 | issue forwarding, StepConfig, ToolCallStep, output sanitization, tool name keying | Enables selective issue/output forwarding, direct StepConfig integration, and flexible multi-step input composition for efficient, context-aware orchestration. |
| ADR-0003: Round 3 Implementation Summary and Architectural Evolution | 3 | architecture, service injection, StepConfig, tool name access, migration | Summarizes round 3 refactor: service injection, direct step config, selective forwarding, tool name-based access, and migration path for maintainability and extensibility. |
