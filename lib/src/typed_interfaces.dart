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
