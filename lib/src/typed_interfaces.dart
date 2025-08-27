import 'tool_result.dart';

/// Base class for strongly-typed tool inputs.
///
/// Provides type safety and validation for tool call parameters
/// while maintaining backward compatibility with Map-based interface.
/// Can be extended for custom tool inputs or used directly for simple cases.
class ToolInput {
  /// Current retry round (0 for first attempt)
  final int round;

  /// Results from previous steps that may be relevant
  final List<ToolResult> previousResults;

  /// Custom input data specific to this tool
  final Map<String, dynamic> customData;

  /// Model configuration for this step
  final String model;

  /// Temperature setting for this step
  final double? temperature;

  /// Max tokens for this step
  final int? maxTokens;

  /// Creates a ToolInput with structured fields and custom data
  const ToolInput({
    this.round = 0,
    this.previousResults = const [],
    this.customData = const {},
    this.model = 'gpt-4',
    this.temperature,
    this.maxTokens,
  });

  /// Converts this input to a Map for tool call processing
  Map<String, dynamic> toMap() {
    return {
      '_round': round,
      '_previous_results': previousResults
          .map((result) => result.toJson())
          .toList(),
      '_model': model,
      if (temperature != null) '_temperature': temperature,
      if (maxTokens != null) '_max_tokens': maxTokens,
      ...customData,
    };
  }

  /// Creates a ToolInput from a Map
  factory ToolInput.fromMap(Map<String, dynamic> map) {
    final customData = Map<String, dynamic>.from(map);

    // Remove known fields from custom data
    final round = customData.remove('_round') as int? ?? 0;
    final previousResultsJson =
        customData.remove('_previous_results') as List? ?? [];
    final previousResults = previousResultsJson
        .cast<Map<String, dynamic>>()
        .map((json) => ToolResult.fromJson(json))
        .toList();
    final model = customData.remove('_model') as String? ?? 'gpt-4';
    final temperature = customData.remove('_temperature') as double?;
    final maxTokens = customData.remove('_max_tokens') as int?;

    return ToolInput(
      round: round,
      previousResults: previousResults,
      customData: customData,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  /// Validates the input parameters
  ///
  /// Returns a list of validation issues, empty if valid
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
  static ToolOutput? create({
    required String toolName,
    required Map<String, dynamic> data,
  }) {
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
