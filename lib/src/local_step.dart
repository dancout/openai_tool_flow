import 'package:meta/meta.dart';
import 'package:openai_toolflow/openai_toolflow.dart';

/// Defines a single local computation step in a ToolFlow.
///
/// Unlike [ToolCallStep], this step executes a local computation function
/// without making LLM API calls. This is useful for:
/// - Mathematical transformations (e.g., color adjustments)
/// - Data processing and formatting
/// - Deterministic operations where LLM calls are unnecessary
///
/// LocalStep maintains the same interface as ToolCallStep, supporting:
/// - Output schema definition
/// - Audits and validation
/// - Retries on audit failures
/// - Input builders for composing inputs from previous steps
/// - Zero token tracking
class LocalStep {
  /// Name of the local computation step
  final String toolName;

  /// Description of what this step does
  final String? toolDescription;

  /// Function to build step input from previous results at execution time
  ///
  /// Takes a list of all previous TypedToolResult objects and returns the input data for this step.
  /// If not provided, the previous step's TypedToolResult will be passed forward using its toMap() method.
  final Map<String, dynamic> Function(List<TypedToolResult>)? inputBuilder;

  /// List of step result indices to include in the computation context.
  /// This mirrors ToolCallStep's includeResultsInToolcall for consistency,
  /// though local steps don't send data to LLMs.
  final List<int> includeResultsInToolcall;

  /// Issues that have been identified in previous attempts
  final List<Issue> issues;

  /// Configuration for this step including audits, forwarding, and sanitization
  final StepConfig stepConfig;

  /// Schema definition for the expected output.
  /// This defines the structure that the local computation should produce.
  final OutputSchema outputSchema;

  /// The local computation function to execute.
  /// Takes the input map and returns the computed output map.
  /// Should be async to maintain consistency with the overall async flow.
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> input)
      computeFunction;

  /// Creates a LocalStep
  @visibleForTesting
  const LocalStep({
    required this.toolName,
    this.toolDescription,
    this.inputBuilder,
    this.includeResultsInToolcall = const [],
    this.issues = const [],
    required this.stepConfig,
    required this.outputSchema,
    required this.computeFunction,
  });

  /// Creates a LocalStep from a LocalStepDefinition
  ///
  /// This automatically registers the step definition in the ToolOutputRegistry
  /// and creates a StepConfig with the appropriate output schema.
  static LocalStep fromStepDefinition<T extends ToolOutput>(
    LocalStepDefinition<T> stepDefinition, {
    Map<String, dynamic> Function(List<TypedToolResult>)? inputBuilder,
    List<Issue> issues = const [],
    StepConfig? stepConfig,
    List<int> includeResultsInToolcall = const [],
    String? toolDescription,
  }) {
    // Auto-register the step definition
    ToolOutputRegistry.registerStepDefinition(stepDefinition);

    return LocalStep(
      toolName: stepDefinition.stepName,
      toolDescription: toolDescription,
      inputBuilder: inputBuilder,
      issues: issues,
      outputSchema: stepDefinition.outputSchema,
      stepConfig: stepConfig ?? StepConfig(),
      includeResultsInToolcall: includeResultsInToolcall,
      computeFunction: stepDefinition.computeFunction,
    );
  }

  /// Creates a copy of this LocalStep with updated parameters
  LocalStep copyWith({
    String? toolName,
    String? toolDescription,
    Map<String, dynamic> Function(List<TypedToolResult>)? inputBuilder,
    List<int>? includeResultsInToolcall,
    List<Issue>? issues,
    StepConfig? stepConfig,
    OutputSchema? outputSchema,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
        computeFunction,
  }) {
    return LocalStep(
      toolName: toolName ?? this.toolName,
      toolDescription: toolDescription ?? this.toolDescription,
      inputBuilder: inputBuilder ?? this.inputBuilder,
      includeResultsInToolcall:
          includeResultsInToolcall ?? this.includeResultsInToolcall,
      issues: issues ?? this.issues,
      stepConfig: stepConfig ?? this.stepConfig,
      outputSchema: outputSchema ?? this.outputSchema,
      computeFunction: computeFunction ?? this.computeFunction,
    );
  }

  @override
  String toString() {
    return 'LocalStep(toolName: $toolName, local: true)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LocalStep) return false;
    
    // Compare tool name
    if (other.toolName != toolName) return false;
    
    // Compare includeResultsInToolcall lists
    if (other.includeResultsInToolcall.length != includeResultsInToolcall.length) {
      return false;
    }
    for (int i = 0; i < includeResultsInToolcall.length; i++) {
      if (other.includeResultsInToolcall[i] != includeResultsInToolcall[i]) {
        return false;
      }
    }
    
    return true;
    // Note: computeFunction and inputBuilder functions cannot be compared
  }

  @override
  int get hashCode {
    int hash = toolName.hashCode;
    for (final item in includeResultsInToolcall) {
      hash = hash ^ item.hashCode;
    }
    return hash;
  }
}
