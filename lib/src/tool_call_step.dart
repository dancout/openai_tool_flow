/// Defines a single tool call step in a ToolFlow.
/// 
/// Contains the tool name, OpenAI model to use, and parameters for the call.
class ToolCallStep {
  /// Name of the tool to call
  final String toolName;
  
  /// OpenAI model to use for this step (e.g., 'gpt-4.1', 'gpt-5')
  final String model;
  
  /// Parameters to pass to the model/tool
  final Map<String, dynamic> params;

  /// Creates a ToolCallStep
  const ToolCallStep({
    required this.toolName,
    required this.model,
    this.params = const {},
  });

  /// Creates a ToolCallStep from a JSON map
  factory ToolCallStep.fromJson(Map<String, dynamic> json) {
    return ToolCallStep(
      toolName: json['toolName'] as String,
      model: json['model'] as String,
      params: Map<String, dynamic>.from(json['params'] as Map? ?? {}),
    );
  }

  /// Converts this ToolCallStep to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'toolName': toolName,
      'model': model,
      'params': params,
    };
  }

  /// Creates a copy of this ToolCallStep with updated parameters
  ToolCallStep copyWith({
    String? toolName,
    String? model,
    Map<String, dynamic>? params,
  }) {
    return ToolCallStep(
      toolName: toolName ?? this.toolName,
      model: model ?? this.model,
      params: params ?? this.params,
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
        other.params.toString() == params.toString();
  }

  @override
  int get hashCode => Object.hash(toolName, model, params);
}