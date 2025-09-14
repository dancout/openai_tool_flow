import 'package:meta/meta.dart';
import 'package:openai_toolflow/openai_toolflow.dart';

/// Enum to specify the type of operation for a ToolCallStep
enum ToolCallStepOperation {
  /// Standard chat completion operation using OpenAI's chat models
  chatCompletion,
  /// Image generation operation using OpenAI's image generation API
  imageGeneration,
  /// Image editing operation using OpenAI's image editing API
  imageEditing,
}

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

  /// Description of what this tool does (used for OpenAI tool function description)
  final String? toolDescription;

  /// OpenAI model to use for this step (e.g., 'gpt-4.1', 'gpt-5')
  /// If null, falls back to the model specified in OpenAIConfig
  final String? model;

  /// Function to build step input from previous results at execution time
  ///
  /// Takes a list of all previous TypedToolResult objects and returns the input data for this step.
  /// If not provided, the previous step's TypedToolResult will be passed forward using its toMap() method.
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
  final Map<String, dynamic> Function(List<TypedToolResult>)? inputBuilder;

  /// List of step result indices to include ToolOutputs and their associated issues from in the OpenAI tool call.
  /// Only accepts integers representing step indices.
  ///
  /// **Usage Examples:**
  /// ```dart
  /// // Include results from step 0 (initial input) and step 1 (first tool step)
  /// includeResultsInToolcall: [0, 1]
  ///
  /// // Include results from steps 1 and 2
  /// includeResultsInToolcall: [1, 2]
  /// ```
  ///
  /// **How it works:**
  /// - Index 0: Initial input passed to ToolFlow.run()
  /// - Index 1: First ToolCallStep result
  /// - Index 2: Second ToolCallStep result, etc.
  /// - Results and their associated issues (filtered by severity) are included in the system message
  /// - Provides context like "here's what you did previously and why it was wrong"
  final List<int> includeResultsInToolcall;

  /// Issues that have been identified in previous attempts
  /// Helps provide context for retry attempts
  final List<Issue> issues;

  /// Configuration for this step including audits, forwarding, and sanitization
  final StepConfig stepConfig;

  /// Schema definition for the expected tool output.
  /// This defines the structure that OpenAI tool calls should conform to.
  final OutputSchema outputSchema;

  /// The type of operation this step performs (chatCompletion, imageGeneration, imageEditing)
  final ToolCallStepOperation operation;

  /// Creates a ToolCallStep
  @visibleForTesting
  const ToolCallStep({
    required this.toolName,
    this.toolDescription,
    this.model,
    this.inputBuilder,
    this.includeResultsInToolcall = const [],
    this.issues = const [],
    required this.stepConfig,
    required this.outputSchema,
    this.operation = ToolCallStepOperation.chatCompletion,
  });

  /// Creates a ToolCallStep from a StepDefinition
  ///
  /// This automatically registers the step definition in the ToolOutputRegistry
  /// and creates a StepConfig with the appropriate output schema.
  static ToolCallStep fromStepDefinition<T extends ToolOutput>(
    StepDefinition<T> stepDefinition, {
    String? model,
    Map<String, dynamic> Function(List<TypedToolResult>)? inputBuilder,
    List<Issue> issues = const [],
    StepConfig? stepConfig,
    List<int> includeResultsInToolcall = const [],
    String? toolDescription,
    ToolCallStepOperation operation = ToolCallStepOperation.chatCompletion,
  }) {
    // Auto-register the step definition
    ToolOutputRegistry.registerStepDefinition(stepDefinition);

    return ToolCallStep(
      toolName: stepDefinition.stepName,
      toolDescription: toolDescription,
      model: model,
      inputBuilder: inputBuilder,
      issues: issues,
      outputSchema: stepDefinition.outputSchema,
      stepConfig: stepConfig ?? StepConfig(),
      includeResultsInToolcall: includeResultsInToolcall,
      operation: operation,
    );
  }

  /// Factory method for creating image generation steps
  /// This provides type safety and ensures correct configuration for image generation
  static ToolCallStep forImageGeneration({
    String model = 'dall-e-3',
    Map<String, dynamic> Function(List<TypedToolResult>)? inputBuilder,
    List<Issue> issues = const [],
    StepConfig? stepConfig,
    List<int> includeResultsInToolcall = const [],
    String? toolDescription,
    ImageGenerationStepDefinition? stepDefinition,
  }) {
    final definition = stepDefinition ?? ImageGenerationStepDefinition();
    ToolOutputRegistry.registerStepDefinition(definition);

    return ToolCallStep(
      toolName: definition.stepName,
      toolDescription: toolDescription ?? 'Generate images based on text prompts using OpenAI\'s image generation API',
      model: model,
      inputBuilder: inputBuilder,
      issues: issues,
      outputSchema: definition.outputSchema,
      stepConfig: stepConfig ?? StepConfig(),
      includeResultsInToolcall: includeResultsInToolcall,
      operation: ToolCallStepOperation.imageGeneration,
    );
  }

  /// Factory method for creating image editing steps
  /// This provides type safety and ensures correct configuration for image editing
  static ToolCallStep forImageEditing({
    String model = 'dall-e-2',
    Map<String, dynamic> Function(List<TypedToolResult>)? inputBuilder,
    List<Issue> issues = const [],
    StepConfig? stepConfig,
    List<int> includeResultsInToolcall = const [],
    String? toolDescription,
    ImageEditStepDefinition? stepDefinition,
  }) {
    final definition = stepDefinition ?? ImageEditStepDefinition();
    ToolOutputRegistry.registerStepDefinition(definition);

    return ToolCallStep(
      toolName: definition.stepName,
      toolDescription: toolDescription ?? 'Edit existing images based on text prompts using OpenAI\'s image editing API',
      model: model,
      inputBuilder: inputBuilder,
      issues: issues,
      outputSchema: definition.outputSchema,
      stepConfig: stepConfig ?? StepConfig(),
      includeResultsInToolcall: includeResultsInToolcall,
      operation: ToolCallStepOperation.imageEditing,
    );
  }

  /// Factory method for creating chat completion steps
  /// This provides type safety and ensures correct configuration for chat completions
  static ToolCallStep forChatCompletion<T extends ToolOutput>(
    StepDefinition<T> stepDefinition, {
    String model = 'gpt-4',
    Map<String, dynamic> Function(List<TypedToolResult>)? inputBuilder,
    List<Issue> issues = const [],
    StepConfig? stepConfig,
    List<int> includeResultsInToolcall = const [],
    String? toolDescription,
  }) {
    // Auto-register the step definition
    ToolOutputRegistry.registerStepDefinition(stepDefinition);

    return ToolCallStep(
      toolName: stepDefinition.stepName,
      toolDescription: toolDescription,
      model: model,
      inputBuilder: inputBuilder,
      issues: issues,
      outputSchema: stepDefinition.outputSchema,
      stepConfig: stepConfig ?? StepConfig(),
      includeResultsInToolcall: includeResultsInToolcall,
      operation: ToolCallStepOperation.chatCompletion,
    );
  }

  /// Creates a copy of this ToolCallStep with updated parameters
  ToolCallStep copyWith({
    String? toolName,
    String? toolDescription,
    String? model,
    Map<String, dynamic> Function(List<TypedToolResult>)? inputBuilder,
    List<int>? includeResultsInToolcall,
    List<Issue>? issues,
    int? maxRetries,
    StepConfig? stepConfig,
    OutputSchema? outputSchema,
    ToolCallStepOperation? operation,
  }) {
    return ToolCallStep(
      toolName: toolName ?? this.toolName,
      toolDescription: toolDescription ?? this.toolDescription,
      model: model ?? this.model,
      inputBuilder: inputBuilder ?? this.inputBuilder,
      includeResultsInToolcall: includeResultsInToolcall ?? this.includeResultsInToolcall,
      issues: issues ?? this.issues,
      stepConfig: stepConfig ?? this.stepConfig,
      outputSchema: outputSchema ?? this.outputSchema,
      operation: operation ?? this.operation,
    );
  }

  @override
  String toString() {
    return 'ToolCallStep(toolName: $toolName, model: $model, operation: $operation)';
  }

  /// Converts this ToolCallStep to a Map for serialization
  Map<String, dynamic> toMap() {
    return {
      'toolName': toolName,
      if (toolDescription != null) 'toolDescription': toolDescription,
      if (model != null) 'model': model,
      'includeResultsInToolcall': includeResultsInToolcall,
      'issues': issues.map((issue) => issue.toString()).toList(),
      'operation': operation.toString().split('.').last,
      // Note: inputBuilder function cannot be serialized
      // Note: stepConfig and outputSchema are complex objects not serialized here
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolCallStep &&
        other.toolName == toolName &&
        other.model == model &&
        other.includeResultsInToolcall.toString() == includeResultsInToolcall.toString();
    // Note: inputBuilder functions cannot be compared
  }

  @override
  int get hashCode => Object.hash(toolName, model, includeResultsInToolcall);
}
