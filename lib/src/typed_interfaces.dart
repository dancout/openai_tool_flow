import 'package:meta/meta.dart';

import 'output_schema.dart';

/// Base class for strongly-typed tool inputs.
///
/// Provides type safety and validation for tool call parameters
/// while maintaining backward compatibility with Map-based interface.
/// Can be extended for custom tool inputs or used directly for simple cases.
class ToolInput {
  /// Current retry round (0 for first attempt)
  final int round;

  /// Custom input data specific to this tool
  // TODO: This houses forwarded data for steps other than the initial (I think? Maybe also the initial). Does it make sense to make this be a forwarded data object instead of just unstructured custom data?
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
    this.customData = const {},
    this.model = 'gpt-4',
    this.temperature,
    this.maxTokens,
  });

  /// Converts this input to a Map for tool call processing
  Map<String, dynamic> toMap() {
    return {
      '_round': round,
      '_model': model,
      if (temperature != null) '_temperature': temperature,
      if (maxTokens != null) '_max_tokens': maxTokens,
      ...customData,
    };
  }

  /// Gets a cleaned version of the tool input with sensitive data removed
  Map<String, dynamic> getCleanToolInput() {
    final cleanInput = Map<String, dynamic>.from(toMap());

    // Remove internal fields that shouldn't be passed to the model
    cleanInput.removeWhere((key, value) => key.startsWith('_'));

    return cleanInput;
  }

  /// Creates a ToolInput from a Map
  factory ToolInput.fromMap(Map<String, dynamic> map) {
    final customData = Map<String, dynamic>.from(map);

    // Remove known fields from custom data
    final round = customData.remove('_round') as int? ?? 0;
    final model = customData.remove('_model') as String? ?? 'gpt-4';
    final temperature = customData.remove('_temperature') as double?;
    final maxTokens = customData.remove('_max_tokens') as int?;

    return ToolInput(
      round: round,
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

/// Base class for strongly-typed tool outputs.
///
/// Provides type safety for tool results while maintaining
/// backward compatibility with Map-based interface.
/// Can be extended for custom tool outputs or used directly for simple cases.
// TODO: (SKIP) Consider making ToolOutput abstract and then you can have the other classes be typed, and force them to implement things like toMap and fromMap.
class ToolOutput {
  /// Current retry round (0 for first attempt)
  final int round;

  /// The output data (only used when ToolOutput is used directly)
  final Map<String, dynamic>? _data;

  /// Creates a ToolOutput with the given data and round (for direct usage)
  const ToolOutput(this._data, {required this.round});

  /// Creates a ToolOutput for subclasses
  /// (they provide their own toMap implementation)
  const ToolOutput.subclass({required this.round}) : _data = null;

  /// Creates a ToolOutput from a Map
  factory ToolOutput.fromMap(Map<String, dynamic> map, {required int round}) {
    return ToolOutput(Map<String, dynamic>.from(map), round: round);
  }

  /// Converts this output to a Map for serialization
  Map<String, dynamic> toMap() {
    if (_data != null) {
      // TODO: Do we need to include _round in this toMap?
      // TODO: Or, should we consider something like a "getCleanOutputMap" that doesn't include it?
      return {'_round': round, ...Map<String, dynamic>.from(_data)};
    }
    throw UnimplementedError(
      'Subclasses must override toMap() when using ToolOutput.subclass()',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolOutput &&
        other.round == round &&
        other.toMap().toString() == toMap().toString();
  }

  @override
  int get hashCode => Object.hash(round, toMap().toString().hashCode);
}

/// Interface for defining tool step metadata and functionality
///
/// Encapsulates step name, output schema, and factory method to eliminate
/// error-prone string usage and enable automatic registration.
abstract class StepDefinition<T extends ToolOutput> {
  /// The unique name identifier for this tool step
  String get stepName;

  /// The output schema definition for this step
  OutputSchema get outputSchema;

  /// Factory method to create typed output from map data
  T fromMap(Map<String, dynamic> data, int round);

  /// The output type for this step
  Type get outputType => T;
}

/// Registry for creating typed outputs from tool results
class ToolOutputRegistry {
  /// Clears all registered creators and output types (for test isolation)
  @visibleForTesting
  static void clearRegistry() {
    _creators.clear();
    _outputTypes.clear();
  }

  static final Map<String, ToolOutput Function(Map<String, dynamic>, int)>
  _creators = {};

  /// Maps tool names to their expected output types for type-safe operations
  static final Map<String, Type> _outputTypes = {};

  /// Registers a creator function for a specific tool with type information
  static void register<T extends ToolOutput>(
    String toolName,
    T Function(Map<String, dynamic>, int) creator,
  ) {
    _creators[toolName] = creator;
    _outputTypes[toolName] = T;
  }

  /// Automatically registers a step definition
  static void registerStepDefinition<T extends ToolOutput>(
    StepDefinition<T> stepDefinition,
  ) {
    register<T>(stepDefinition.stepName, stepDefinition.fromMap);
  }

  /// Creates a typed output for the given tool name, data, and round
  /// Throws an exception if no creator is registered for the tool name
  static ToolOutput create({
    required String toolName,
    required Map<String, dynamic> data,
    required int round,
  }) {
    final creator = _creators[toolName];
    if (creator == null) {
      throw Exception('No typed output creator registered for tool: $toolName');
    }
    return creator(data, round);
  }

  /// Checks if a tool has a registered typed output
  static bool hasTypedOutput(String toolName) {
    return _creators.containsKey(toolName);
  }

  /// Gets the expected output type for a tool
  /// Throws an exception if no output type is registered for the tool name
  static Type getOutputType(String toolName) {
    final outputType = _outputTypes[toolName];
    if (outputType == null) {
      throw Exception('No output type registered for tool: $toolName');
    }
    return outputType;
  }

  /// Checks if a tool's output type matches the expected type
  static bool hasOutputType<T extends ToolOutput>(String toolName) {
    return _outputTypes[toolName] == T;
  }

  /// Gets all registered tool names
  static List<String> get registeredTools => _creators.keys.toList();

  /// Gets all registered output types
  static Map<String, Type> get registeredOutputTypes =>
      Map.unmodifiable(_outputTypes);
}
