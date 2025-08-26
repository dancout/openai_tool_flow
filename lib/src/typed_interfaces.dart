/// Abstract base class for strongly-typed tool inputs.
///
/// Provides type safety and validation for tool call parameters
/// while maintaining backward compatibility with Map-based interface.
abstract class ToolInput {
  /// Allows const constructors in subclasses
  const ToolInput();

  /// Converts this input to a Map for tool call processing
  Map<String, dynamic> toMap();

  /// Creates a ToolInput from a Map
  ///
  /// Subclasses should implement this factory constructor
  /// to enable deserialization from generic maps.
  static ToolInput fromMap(Map<String, dynamic> map) {
    throw UnimplementedError('Subclasses must implement fromMap');
  }

  /// Validates the input parameters
  ///
  /// Returns a list of validation issues, empty if valid
  List<String> validate() => [];
}

/// Structured input for a tool execution step.
///
/// This class provides consistent structure for all tool calls while
/// allowing custom data through the `customData` field.
///
/// **Structured Fields (always present):**
/// - `round`: Current retry round (0 for first attempt)
/// - `previousIssues`: Issues from previous steps for context
/// - `model`, `temperature`, `maxTokens`: Model configuration
///
/// **Custom Data:**
/// - All step-specific parameters and forwarded outputs from previous steps
///
/// **Example usage:**
/// ```dart
/// final stepInput = StepInput(
///   round: 0,
///   previousIssues: [],
///   customData: {
///     'colors': ['#FF0000', '#00FF00'],
///     'enhance_contrast': true,
///     'extract_palette_confidence': 0.85, // From previous step
///   },
///   model: 'gpt-4',
/// );
///
/// // Convert to map for service call
/// final inputMap = stepInput.toMap();
/// // Results in: {
/// //   '_round': 0,
/// //   '_previous_issues': [],
/// //   '_model': 'gpt-4',
/// //   'colors': ['#FF0000', '#00FF00'],
/// //   'enhance_contrast': true,
/// //   'extract_palette_confidence': 0.85,
/// // }
/// ```
class StepInput
        // TODO: Why do we have StepInput extending ToolInput here at the base level?
        // Should the usage.dart example file be extending StepInput instead?
        // OR - Should we remove StepInput entirely in favor of using ToolInput, and that not be abstract?
        extends
        ToolInput {
  /// Current retry round (0 for first attempt)
  final int round;

  /// Issues from previous steps that may be relevant
  final List<Map<String, dynamic>> previousIssues;

  /// Custom input data specific to this tool
  final Map<String, dynamic> customData;

  /// Model configuration for this step
  final String model;

  /// Temperature setting for this step
  final double? temperature;

  /// Max tokens for this step
  final int? maxTokens;

  const StepInput({
    required this.round,
    required this.previousIssues,
    required this.customData,
    required this.model,
    this.temperature,
    this.maxTokens,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      '_round': round,
      '_previous_issues': previousIssues,
      '_model': model,
      if (temperature != null) '_temperature': temperature,
      if (maxTokens != null) '_max_tokens': maxTokens,
      ...customData,
    };
  }

  /// Creates a StepInput from a Map
  factory StepInput.fromMap(Map<String, dynamic> map) {
    final customData = Map<String, dynamic>.from(map);

    // Remove known fields from custom data
    final round = customData.remove('_round') as int? ?? 0;
    final previousIssues =
        (customData.remove('_previous_issues') as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final model = customData.remove('_model') as String? ?? 'gpt-4';
    final temperature = customData.remove('_temperature') as double?;
    final maxTokens = customData.remove('_max_tokens') as int?;

    return StepInput(
      round: round,
      previousIssues: previousIssues,
      customData: customData,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  @override
  List<String> validate() {
    final issues = <String>[];

    if (round < 0) {
      issues.add('Round must be non-negative');
    }

    if (model.isEmpty) {
      issues.add('Model cannot be empty');
    }

    if (temperature != null && (temperature! < 0 || temperature! > 2)) {
      issues.add('Temperature must be between 0 and 2');
    }

    if (maxTokens != null && maxTokens! <= 0) {
      issues.add('Max tokens must be positive');
    }

    return issues;
  }
}

/// Abstract base class for strongly-typed tool outputs.
///
/// Provides type safety for tool results while maintaining
/// backward compatibility with Map-based interface.
abstract class ToolOutput {
  /// Allows const constructors in subclasses
  const ToolOutput();

  /// Converts this output to a Map for serialization
  Map<String, dynamic> toMap();

  /// Creates a ToolOutput from a Map
  ///
  /// Subclasses should implement this factory constructor
  /// to enable deserialization from generic maps.
  static ToolOutput fromMap(Map<String, dynamic> map) {
    throw UnimplementedError('Subclasses must implement fromMap');
  }
}

/// Registry for creating typed outputs from tool results
class ToolOutputRegistry {
  static final Map<String, ToolOutput Function(Map<String, dynamic>)>
  _creators = {};

  /// Registers a creator function for a specific tool
  static void register<T extends ToolOutput>(
    String toolName,
    T Function(Map<String, dynamic>) creator,
  ) {
    _creators[toolName] = creator;
  }

  /// Creates a typed output for the given tool name and data
  static ToolOutput? create(String toolName, Map<String, dynamic> data) {
    final creator = _creators[toolName];
    return creator?.call(data);
  }

  /// Checks if a tool has a registered typed output
  static bool hasTypedOutput(String toolName) {
    return _creators.containsKey(toolName);
  }

  /// Gets all registered tool names
  static List<String> get registeredTools => _creators.keys.toList();
}
