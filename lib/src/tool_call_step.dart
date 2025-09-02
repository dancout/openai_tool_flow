import 'audit_function.dart';
import 'issue.dart';
import 'step_config.dart';
import 'tool_result.dart';
import 'typed_interfaces.dart';

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
    // TODO: I wonder if we should have a convenience function that can convert the issues from previous results to be easily used in the future. The context here is that if we are doing a tool call that is adjusting the values of a TypedOutput then we may be interested in the previous issues as to not regress and recreate them.
    /// So, it might be nice to be able to simply say "include the previous results and issues from these steps" and the user doesn't have to parse everything themselves. Either through like an overridable method, or a getter, or even just passing in a list to a parameter that says "include these bad boys".
    /// The removed code from the _buildSystemMessage was:
    /// if (input.previousResults.isNotEmpty) {
    //   buffer.writeln();
    //   buffer.writeln('Previous step results and associated issues:');
    //   for (int i = 0; i < input.previousResults.length; i++) {
    //     final result = input.previousResults[i];
    //     buffer.writeln(
    //       '  Step ${i + 1}: ${result.toolName} -> Output keys: ${result.output.toMap().keys.join(', ')}',
    //     );

    //     // Include issues associated with this specific result
    //     if (result.issues.isNotEmpty) {
    //       buffer.writeln('    Associated issues:');
    //       for (final issue in result.issues) {
    //         buffer.writeln(
    //           '      - ${issue.severity.name.toUpperCase()}: ${issue.description}',
    //         );
    //         if (issue.suggestions.isNotEmpty) {
    //           buffer.writeln(
    //             '        Suggestions: ${issue.suggestions.join(', ')}',
    //           );
    //         }
    //       }
    //     }
    //   }
    // }
    // TODO: Related to above, it might be nice to even split out the ToolInput class so that there is a base class with just the data necessary for this input, and then we can have a separate extended class that includes the previous results & issues if the user wants it, and we can parse all that out under the hood so the user doesn't have to.
    required this.inputBuilder,
    this.buildInputsFrom = const [],
    this.issues = const [],
    this.maxRetries = 3,
    required this.stepConfig,
    // TODO: Consider moving outputSchema to the ToolCallStep instead of the stepConfig. I'm not sure which is better.
  });

  /// Creates a ToolCallStep from a StepDefinition
  /// 
  /// This automatically registers the step definition in the ToolOutputRegistry
  /// and creates a StepConfig with the appropriate output schema.
  factory ToolCallStep.fromStepDefinition<T extends ToolOutput>(
    StepDefinition<T> stepDefinition, {
    required String model,
    required Map<String, dynamic> Function(List<ToolResult>) inputBuilder,
    List<Object> buildInputsFrom = const [],
    List<Issue> issues = const [],
    int maxRetries = 3,
    List<AuditFunction> audits = const [],
    int? stepMaxRetries,
    bool Function(List<Issue>)? customPassCriteria,
    String Function(List<Issue>)? customFailureReason,
    bool stopOnFailure = true,
    List<dynamic> includeOutputsFrom = const [],
    Map<String, dynamic> Function(Map<String, dynamic>)? inputSanitizer,
    Map<String, dynamic> Function(Map<String, dynamic>)? outputSanitizer,
  }) {
    // Auto-register the step definition
    ToolOutputRegistry.registerStepDefinition(stepDefinition);

    return ToolCallStep(
      toolName: stepDefinition.stepName,
      model: model,
      inputBuilder: inputBuilder,
      buildInputsFrom: buildInputsFrom,
      issues: issues,
      maxRetries: maxRetries,
      stepConfig: StepConfig(
        audits: audits,
        maxRetries: stepMaxRetries,
        customPassCriteria: customPassCriteria,
        customFailureReason: customFailureReason,
        stopOnFailure: stopOnFailure,
        includeOutputsFrom: includeOutputsFrom,
        inputSanitizer: inputSanitizer,
        outputSanitizer: outputSanitizer,
        outputSchema: stepDefinition.outputSchema,
      ),
    );
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
