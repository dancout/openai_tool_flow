import 'issue.dart';

/// Structured output of a tool call step.
/// 
/// This class follows a strict but extensible schema:
/// - Strict: certain fields are required
/// - Extensible: projects may extend the class with new fields
/// - The pipeline never strips fields — it always forwards the full object by serializing with `toJson()`
class ToolResult {
  /// Name of the tool that was executed
  final String toolName;
  
  /// Input parameters that were passed to the tool
  final Map<String, dynamic> input;
  
  /// Output data returned by the tool
  final Map<String, dynamic> output;
  
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
    return ToolResult(
      toolName: json['toolName'] as String,
      input: Map<String, dynamic>.from(json['input'] as Map),
      output: Map<String, dynamic>.from(json['output'] as Map),
      issues: (json['issues'] as List?)
          ?.map((issueJson) => Issue.fromJson(issueJson as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  /// Converts this ToolResult to a JSON map
  /// 
  /// Subclasses should override this method to include their additional fields
  /// while calling super.toJson() to preserve the base fields.
  Map<String, dynamic> toJson() {
    return {
      'toolName': toolName,
      'input': input,
      'output': output,
      'issues': issues.map((issue) => issue.toJson()).toList(),
    };
  }

  /// Creates a copy of this ToolResult with additional issues
  ToolResult withAdditionalIssues(List<Issue> newIssues) {
    return ToolResult(
      toolName: toolName,
      input: input,
      output: output,
      issues: [...issues, ...newIssues],
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
    return other is ToolResult &&
        other.toolName == toolName &&
        other.input.toString() == input.toString() &&
        other.output.toString() == output.toString();
  }

  @override
  int get hashCode => Object.hash(toolName, input, output);
}