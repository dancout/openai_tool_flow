import 'issue.dart';
import 'step_config.dart';

/// Defines a single tool call step in a ToolFlow.
/// 
/// Contains the tool name, OpenAI model to use, parameters for the call,
/// and configuration for issues and retries.
class ToolCallStep {
  /// Name of the tool to call
  final String toolName;
  
  /// OpenAI model to use for this step (e.g., 'gpt-4.1', 'gpt-5')
  final String model;
  
  /// Parameters to pass to the model/tool
  final Map<String, dynamic> params;

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
    this.params = const {},
    this.issues = const [],
    this.maxRetries = 3,
    this.stepConfig = const StepConfig(),
  });

  /// Creates a ToolCallStep from a JSON map
  factory ToolCallStep.fromJson(Map<String, dynamic> json) {
    return ToolCallStep(
      toolName: json['toolName'] as String,
      model: json['model'] as String,
      params: Map<String, dynamic>.from(json['params'] as Map? ?? {}),
      issues: (json['issues'] as List?)
          ?.map((issueJson) => Issue.fromJson(issueJson as Map<String, dynamic>))
          .toList() ?? [],
      maxRetries: json['maxRetries'] as int? ?? 3,
      stepConfig: json['stepConfig'] != null 
          ? StepConfig.fromJson(json['stepConfig'] as Map<String, dynamic>)
          : const StepConfig(),
    );
  }

  /// Converts this ToolCallStep to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'toolName': toolName,
      'model': model,
      'params': params,
      'issues': issues.map((issue) => issue.toJson()).toList(),
      'maxRetries': maxRetries,
      'stepConfig': stepConfig.toJson(),
    };
  }

  /// Creates a copy of this ToolCallStep with updated parameters
  ToolCallStep copyWith({
    String? toolName,
    String? model,
    Map<String, dynamic>? params,
    List<Issue>? issues,
    int? maxRetries,
    StepConfig? stepConfig,
  }) {
    return ToolCallStep(
      toolName: toolName ?? this.toolName,
      model: model ?? this.model,
      params: params ?? this.params,
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
        other.params.toString() == params.toString() &&
        other.maxRetries == maxRetries;
  }

  @override
  int get hashCode => Object.hash(toolName, model, params, maxRetries);
}