import 'issue.dart';
import 'step_config.dart';
import 'tool_result.dart';

/// Defines a single tool call step in a ToolFlow.
///
/// Contains the tool name, OpenAI model to use, dynamic input builder function,
/// and configuration for issues and retries.
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
  final Map<String, dynamic> Function(List<ToolResult>) inputBuilder;

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

  /// Issues that have been identified in previous attempts
  /// Helps provide context for retry attempts
  final List<Issue> issues;

  /// Maximum number of retry attempts for this step
  /// Defaults to 3 attempts
  final int maxRetries;

  /// Configuration for this step including audits, forwarding, and sanitization
  final StepConfig stepConfig;

  /// Creates a ToolCallStep
  const ToolCallStep({
    required this.toolName,
    required this.model,
    required this.inputBuilder,
    this.buildInputsFrom = const [],
    this.issues = const [],
    this.maxRetries = 3,
    required this.stepConfig,
  });

  // TODO: Does it make sense to simply not include this method, instead of declaring it and assigning an unsupported error, then writing a test that checks it throws an error, and that's the only ever usage?
  /// // This is an example to give where we shouldn't declare something just to declare it.
  /// // Only create things you are actively going using.

  /// Creates a ToolCallStep from a JSON map
  ///
  /// NOTE: inputBuilder functions cannot be serialized, so this method
  /// is not supported for ToolCallStep with dynamic input builders.
  factory ToolCallStep.fromJson(Map<String, dynamic> json) {
    throw UnsupportedError(
      'ToolCallStep.fromJson is not supported because inputBuilder functions cannot be serialized. '
      'Create ToolCallStep instances directly with the required inputBuilder function.',
    );
  }

  /// Converts this ToolCallStep to a JSON map
  ///
  /// NOTE: inputBuilder functions cannot be serialized, so this method
  /// only includes basic metadata about the step.
  Map<String, dynamic> toJson() {
    return {
      'toolName': toolName,
      'model': model,
      'buildInputsFrom': buildInputsFrom,
      'issues': issues.map((issue) => issue.toJson()).toList(),
      'maxRetries': maxRetries,
      'stepConfig': stepConfig.toJson(),
      '_note': 'inputBuilder function not serialized',
    };
  }

  /// Creates a copy of this ToolCallStep with updated parameters
  ToolCallStep copyWith({
    String? toolName,
    String? model,
    Map<String, dynamic> Function(List<ToolResult>)? inputBuilder,
    List<Object>? buildInputsFrom,
    List<Issue>? issues,
    int? maxRetries,
    StepConfig? stepConfig,
  }) {
    return ToolCallStep(
      toolName: toolName ?? this.toolName,
      model: model ?? this.model,
      inputBuilder: inputBuilder ?? this.inputBuilder,
      buildInputsFrom: buildInputsFrom ?? this.buildInputsFrom,
      issues: issues ?? this.issues,
      maxRetries: maxRetries ?? this.maxRetries,
      stepConfig: stepConfig ?? this.stepConfig,
    );
  }

  @override
  String toString() {
    return 'ToolCallStep(toolName: $toolName, model: $model, maxRetries: $maxRetries)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolCallStep &&
        other.toolName == toolName &&
        other.model == model &&
        other.buildInputsFrom.toString() == buildInputsFrom.toString() &&
        other.maxRetries == maxRetries;
    // Note: inputBuilder functions cannot be compared
  }

  @override
  int get hashCode => Object.hash(toolName, model, buildInputsFrom, maxRetries);
}
