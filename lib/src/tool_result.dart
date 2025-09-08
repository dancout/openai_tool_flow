import 'issue.dart';
import 'typed_interfaces.dart';

// Forward declaration for AuditResults
class AuditResults {
  /// List of issues found during audit execution
  final List<Issue> issues;

  /// Whether all audits passed their criteria
  final bool passesCriteria;

  const AuditResults({required this.issues, required this.passesCriteria});

  /// Converts this AuditResults to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'issues': issues.map((issue) => issue.toJson()).toList(),
      'passesCriteria': passesCriteria,
    };
  }
}

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

  /// Results from audit execution, if any audits were performed
  final AuditResults auditResults;

  /// Creates a ToolResult with required fields
  const ToolResult({
    required this.toolName,
    required this.input,
    required this.output,
    required this.auditResults,
  });

  /// Converts this ToolResult to a JSON map
  ///
  /// Subclasses should override this method to include their additional fields
  /// while calling super.toJson() to preserve the base fields.
  Map<String, dynamic> toJson() {
    return {
      'toolName': toolName,
      'input': input.toMap(),
      'output': output.toMap(),
      'auditResults': auditResults.toJson(),
    };
  }

  /// Creates a copy of this ToolResult with optional field overrides
  ToolResult<T> copyWith({
    String? toolName,
    ToolInput? input,
    T? output,
    List<Issue>? issues,
    AuditResults? auditResults,
  }) {
    return ToolResult<T>(
      toolName: toolName ?? this.toolName,
      input: input ?? this.input,
      output: output ?? this.output,
      auditResults: auditResults ?? this.auditResults,
    );
  }

  @override
  String toString() {
    return 'ToolResult(toolName: $toolName, issues: ${auditResults.issues.length}, passesCriteria: ${auditResults.passesCriteria})';
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
