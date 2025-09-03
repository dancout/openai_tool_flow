import 'package:meta/meta.dart';
import 'package:openai_toolflow/openai_toolflow.dart';

/// Defines a single tool call step in a ToolFlow.
///
/// Contains the tool name, OpenAI model to use, dynamic input builder function,
/// and configuration for issues and retries.
// TODO: Read ALT-003 and ALT-004 from adr-0002-typedtoolresult-wrapper-implementation.md
/// It goes over how we totally could have made everything type safe. It still thinks
/// we need to prevent breaking changes...
class ToolCallStep {
  /// Name of the tool to call
  final String toolName;

  /// OpenAI model to use for this step (e.g., 'gpt-4.1', 'gpt-5')
  final String model;

  /// Function to build step input from previous results at execution time
  ///
  /// Takes a list of ToolResult objects from steps specified in buildInputsFrom
  /// and returns the input data for this step.
  ///
  /// **Example:**
  /// ```dart
  /// inputBuilder: (previousResults) {
  ///   if (previousResults.isEmpty) {
  ///     return {'static': 'data'};
  ///   }
  ///   final paletteResult = previousResults.first;
  ///   return {
  ///     'colors': paletteResult.output.toMap()['colors'],
  ///     'enhance_contrast': true,
  ///   };
  /// }
  /// ```
  final Map<String, dynamic> Function(List<TypedToolResult>) inputBuilder;

  /// Specifies which previous step results to pass to inputBuilder
  ///
  /// Similar to includeOutputsFrom in StepConfig:
  /// - int values: References step by index (0-based)
  /// - String values: References step by tool name (most recent if duplicates)
  /// - Empty list: inputBuilder receives empty list (for static input steps)
  // TODO: Would it be possible for us to extrapolate the types of the entities as the input to inputBuilder, instead of List<ToolResult>, could we have them strongly typed to the exact types that are found when you look for the outputs you're pulling forward?
  /// We'd have to update how the buildInputsFrom works, because instead of just specifying string, it'd have to specify types
  /// Or, we'd need like a Lookup tool to get the Type of expected TypedOutput for that step, and assign it that way
  final List<Object> buildInputsFrom;

  /// List of steps results to include ToolOutputs and their associated issues from in the OpenAI tool call.
  /// Can be int (step index) or String (tool name).
  ///
  /// **Usage Examples:**
  /// ```dart
  /// // Include results from step 0 and any step with tool name 'extract_palette'
  /// includeResultsInToolcall: [0, 'extract_palette']
  ///
  /// // Include results from steps 1 and 2
  /// includeResultsInToolcall: [1, 2]
  ///
  /// // Include results from 'refine_colors' tool (most recent if duplicates)
  /// includeResultsInToolcall: ['refine_colors']
  /// ```
  ///
  /// **How it works:**
  /// - int values: References step by index (0-based)
  /// - String values: References step by tool name (most recent if duplicates)
  /// - Results and their associated issues (filtered by severity) are included in the system message
  /// - Provides context like "here's what you did previously and why it was wrong"
  final List<dynamic> includeResultsInToolcall;

  /// Issues that have been identified in previous attempts
  /// Helps provide context for retry attempts
  final List<Issue> issues;

  /// Configuration for this step including audits, forwarding, and sanitization
  final StepConfig stepConfig;

  /// Schema definition for the expected tool output.
  /// This defines the structure that OpenAI tool calls should conform to.
  final OutputSchema outputSchema;

  /// Creates a ToolCallStep
  @visibleForTesting
  const ToolCallStep({
    required this.toolName,
    required this.model,
    required this.inputBuilder,
    this.includeResultsInToolcall = const [],
    this.buildInputsFrom = const [],
    this.issues = const [],
    required this.stepConfig,
    required this.outputSchema,
  });

  /// Creates a ToolCallStep from a StepDefinition
  ///
  /// This automatically registers the step definition in the ToolOutputRegistry
  /// and creates a StepConfig with the appropriate output schema.
  static ToolCallStep fromStepDefinition<T extends ToolOutput>(
    StepDefinition<T> stepDefinition, {
    required String model,
    required Map<String, dynamic> Function(List<TypedToolResult>) inputBuilder,
    List<Object> buildInputsFrom = const [],
    List<Issue> issues = const [],
    StepConfig? stepConfig,
    List<String> includeResultsInToolcall = const [],
  }) {
    // Auto-register the step definition
    ToolOutputRegistry.registerStepDefinition(stepDefinition);

    return ToolCallStep(
      toolName: stepDefinition.stepName,
      model: model,
      inputBuilder: inputBuilder,
      buildInputsFrom: buildInputsFrom,
      issues: issues,
      outputSchema: stepDefinition.outputSchema,
      stepConfig: stepConfig ?? StepConfig(),
      includeResultsInToolcall: includeResultsInToolcall,
    );
  }

  /// Creates a copy of this ToolCallStep with updated parameters
  ToolCallStep copyWith({
    String? toolName,
    String? model,
    Map<String, dynamic> Function(List<TypedToolResult>)? inputBuilder,
    List<Object>? buildInputsFrom,
    List<Issue>? issues,
    int? maxRetries,
    StepConfig? stepConfig,
    OutputSchema? outputSchema,
  }) {
    return ToolCallStep(
      toolName: toolName ?? this.toolName,
      model: model ?? this.model,
      inputBuilder: inputBuilder ?? this.inputBuilder,
      buildInputsFrom: buildInputsFrom ?? this.buildInputsFrom,
      issues: issues ?? this.issues,
      stepConfig: stepConfig ?? this.stepConfig,
      outputSchema: outputSchema ?? this.outputSchema,
    );
  }

  @override
  String toString() {
    return 'ToolCallStep(toolName: $toolName, model: $model)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolCallStep &&
        other.toolName == toolName &&
        other.model == model &&
        other.buildInputsFrom.toString() == buildInputsFrom.toString();
    // Note: inputBuilder functions cannot be compared
  }

  @override
  int get hashCode => Object.hash(toolName, model, buildInputsFrom);
}
