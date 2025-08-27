import 'issue.dart';
import 'typed_interfaces.dart';

/// Structured output of a tool call step.
///
/// This class follows a strict but extensible schema:
/// - Strict: certain fields are required
/// - Extensible: projects may extend the class with new fields
/// - The pipeline never strips fields — it always forwards the full object by serializing with `toJson()`
class ToolResult<T extends ToolOutput> {
  /// Name of the tool that was executed
  final String toolName;

  /// Strongly-typed input that was passed to the tool
  final ToolInput input;

  /// Strongly-typed output data returned by the tool
  final T output;

  /// Issues identified during tool execution or subsequent audits
  final List<Issue> issues;

  /// Creates a ToolResult with required fields
  const ToolResult({
    required this.toolName,
    required this.input,
    required this.output,
    this.issues = const [],
  });

  /// Creates a ToolResult from a JSON map
  factory ToolResult.fromJson(Map<String, dynamic> json) {
    final toolName = json['toolName'] as String;
    final inputMap = Map<String, dynamic>.from(json['input'] as Map);
    final outputMap = Map<String, dynamic>.from(json['output'] as Map);

    // Create typed input from map data
    final typedInput = ToolInput.fromMap(inputMap);

    if (!ToolOutputRegistry.hasTypedOutput(toolName)) {
      throw Exception('No typed output registered for tool "$toolName".');
    }

    // Try to create typed output if registry has a creator for this tool
    final typedOutput = ToolOutputRegistry.create(
      toolName: toolName,
      data: outputMap,
    );

    if (typedOutput == null) {
      throw Exception(
        'Failed to create typed output for tool "$toolName". '
        'This should not happen as ToolOutput should always work.',
      );
    }

    return ToolResult<ToolOutput>(
      toolName: toolName,
      input: typedInput,
      output: typedOutput,
      issues:
          (json['issues'] as List?)
              ?.map(
                (issueJson) =>
                    Issue.fromJson(issueJson as Map<String, dynamic>),
              )
              .toList() ??
          [],
    ) as ToolResult<T>;
  }

  /// Converts this ToolResult to a JSON map
  ///
  /// Subclasses should override this method to include their additional fields
  /// while calling super.toJson() to preserve the base fields.
  Map<String, dynamic> toJson() {
    return {
      'toolName': toolName,
      'input': input.toMap(),
      'output': output.toMap(),
      'issues': issues.map((issue) => issue.toJson()).toList(),
    };
  }

  /// Creates a copy of this ToolResult with additional issues
  ToolResult<T> withAdditionalIssues(List<Issue> newIssues) {
    return ToolResult<T>(
      toolName: toolName,
      input: input,
      output: output,
      issues: [...issues, ...newIssues],
    );
  }

  /// Creates a copy of this ToolResult with optional field overrides
  ToolResult<T> copyWith({
    String? toolName,
    ToolInput? input,
    T? output,
    List<Issue>? issues,
  }) {
    return ToolResult<T>(
      toolName: toolName ?? this.toolName,
      input: input ?? this.input,
      output: output ?? this.output,
      issues: issues ?? this.issues,
    );
  }

  /// Returns true if this ToolResult has any issues
  bool get hasIssues => issues.isNotEmpty;

  /// Returns issues filtered by severity
  List<Issue> issuesWithSeverity(IssueSeverity severity) {
    return issues.where((issue) => issue.severity == severity).toList();
  }

  @override
  String toString() {
    return 'ToolResult(toolName: $toolName, issues: ${issues.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolResult<T> &&
        other.toolName == toolName &&
        other.input.toMap().toString() == input.toMap().toString() &&
        other.output.toMap().toString() == output.toMap().toString();
  }

  @override
  int get hashCode => Object.hash(toolName, input.toMap(), output.toMap());
}
