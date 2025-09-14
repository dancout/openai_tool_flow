/// A Dart package for orchestrating OpenAI tool calls with audits.
///
/// This package enables developers to define a pipeline of tool calls where:
/// - Each tool call can pass structured outputs or issues to later steps
/// - Audit functions can generate issues that feed back into the pipeline
/// - Model parameters can be customized per call
/// - State is managed internally across tool calls
/// - All data structures are strict but extensible via subclassing
/// - Strongly-typed interfaces available alongside generic maps
library;

export 'src/audit_function.dart';
export 'src/image_generation_interfaces.dart';
export 'src/issue.dart';
export 'src/openai_config.dart';
export 'src/openai_service.dart';
export 'src/openai_service_impl.dart';
export 'src/output_schema.dart';
export 'src/step_config.dart';
export 'src/token_usage.dart';
export 'src/tool_call_step.dart';
export 'src/tool_flow.dart';
export 'src/tool_result.dart';
export 'src/typed_interfaces.dart';
export 'src/typed_tool_result.dart';
