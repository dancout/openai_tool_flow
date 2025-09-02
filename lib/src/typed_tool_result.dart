import 'issue.dart';
import 'tool_result.dart';
import 'typed_interfaces.dart';

/// A type-safe wrapper for ToolResult that preserves specific output types
/// while allowing heterogeneous storage and common interface access.
///
/// This enables the ToolFlow orchestration system to store results with
/// different output types (e.g., `ToolResult<PaletteOutput>`, `ToolResult<ThemeOutput>`)
/// in the same collection while maintaining type safety for audit execution.
class TypedToolResult {
  /// The wrapped tool result with its specific type
  final ToolResult<ToolOutput> _result;

  /// The runtime type of the output for type-safe operations
  final Type _outputType;

  /// Creates a TypedToolResult wrapper for the given result
  TypedToolResult._(this._result, this._outputType);

  /// Creates a TypedToolResult from a ToolResult with specific output type
  static TypedToolResult from<T extends ToolOutput>(ToolResult<T> result) {
    return TypedToolResult._(result as ToolResult<ToolOutput>, T);
  }

  /// Creates a TypedToolResult from a ToolResult with runtime type information
  static TypedToolResult fromWithType(
    ToolResult<ToolOutput> result,
    Type outputType,
  ) {
    return TypedToolResult._(result, outputType);
  }

  /// Gets the tool name from the wrapped result
  String get toolName => _result.toolName;

  /// Gets the input from the wrapped result
  ToolInput get input => _result.input;

  /// Gets the output from the wrapped result (type-erased)
  ToolOutput get output => _result.output;

  /// Gets the issues from the wrapped result
  List<Issue> get issues => _result.issues;

  /// Returns true if this result has any issues
  bool get hasIssues => _result.hasIssues;

  /// Returns issues filtered by severity
  List<Issue> issuesWithSeverity(IssueSeverity severity) {
    return _result.issuesWithSeverity(severity);
  }

  /// Gets the runtime output type
  Type get outputType => _outputType;

  /// Gets the underlying ToolResult for internal use
  ///
  /// This is used internally by ToolFlow for backward compatibility
  /// and should not be used by external code
  /// // TODO: Does this need to be generic T?
  /// // TODO: Does there need to be a getter here for the private result, or can we just expose _result directly?
  /// also, why are we still worrying about backwards compatibility?
  ToolResult<ToolOutput> get underlyingResult => _result;

  /// Checks if the wrapped result has the expected output type
  bool hasOutputType<T extends ToolOutput>() {
    return _outputType == T;
  }

  /// Safely creates a new properly-typed result for the given type
  ///
  /// Returns null if the output type doesn't match, otherwise returns a new
  /// `ToolResult<T>` with the correct type parameter. This enables type-safe audit execution.
  ToolResult<T>? asTyped<T extends ToolOutput>() {
    if (hasOutputType<T>()) {
      // Create a new properly typed result instead of casting
      // This works around Dart's non-covariant generics
      return ToolResult<T>(
        toolName: _result.toolName,
        input: _result.input,
        output: _result.output as T,
        issues: _result.issues,
      );
    }
    return null;
  }

  /// Creates a copy of this TypedToolResult with optional updated fields
  TypedToolResult copyWith({ToolResult<ToolOutput>? result, Type? outputType}) {
    return TypedToolResult._(result ?? _result, outputType ?? _outputType);
  }

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() => _result.toJson();

  @override
  String toString() {
    return 'TypedToolResult(toolName: $toolName, outputType: $_outputType, issues: ${issues.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TypedToolResult &&
        other._result == _result &&
        other._outputType == _outputType;
  }

  @override
  int get hashCode => Object.hash(_result, _outputType);
}
