import 'issue.dart';
import 'tool_result.dart';
import 'typed_interfaces.dart';

/// Abstract base class for audit functions.
///
/// Developers implement this class to provide domain-specific audit logic.
/// An audit inspects tool outputs and produces Issue objects.
abstract class AuditFunction<T extends ToolOutput> {
  /// Name of this audit function
  String get name;

  /// Executes the audit on a tool result and returns any issues found
  ///
  /// This method should be implemented by subclasses to provide
  /// domain-specific audit logic.
  List<Issue> run(ToolResult<T> result);

  /// Executes the audit on a generic ToolResult with runtime type checking
  ///
  /// This method enables type-safe audit execution by attempting to cast
  /// the generic `ToolResult&lt;ToolOutput&gt;` to the expected type `T`.
  /// If the cast succeeds, the audit runs normally. If it fails,
  /// an appropriate error is returned.
  List<Issue> runWithTypeChecking(ToolResult<ToolOutput> result) {
    try {
      // Attempt to create a properly typed result
      if (result.output.runtimeType.toString() == T.toString()) {
        final typedResult = ToolResult<T>(
          toolName: result.toolName,
          input: result.input,
          output: result.output as T,
          issues: result.issues,
        );
        return run(typedResult);
      } else {
        // Type mismatch - create an informative error
        return [
          Issue(
            id: 'audit_type_mismatch_$name',
            severity: IssueSeverity.critical,
            description:
                'Audit $name expects output type $T, but received ${result.output.runtimeType}',
            context: {
              'audit_name': name,
              'expected_type': T.toString(),
              'actual_type': result.output.runtimeType.toString(),
              'tool_name': result.toolName,
            },
            suggestions: [
              'Ensure the tool produces output of type $T',
              'Register the correct output type for tool ${result.toolName}',
              'Change audit to expect ToolOutput if it should work with any output type',
            ],
          ),
        ];
      }
    } catch (e) {
      // Handle any other errors during type checking
      return [
        Issue(
          id: 'audit_execution_error_$name',
          severity: IssueSeverity.critical,
          description: 'Failed to execute audit $name with type checking: $e',
          context: {
            'audit_name': name,
            'expected_type': T.toString(),
            'actual_type': result.output.runtimeType.toString(),
            'tool_name': result.toolName,
            'error': e.toString(),
          },
          suggestions: [
            'Check audit implementation for type-related issues',
            'Verify tool output structure matches audit expectations',
          ],
        ),
      ];
    }
  }

  /// Determines if the audit criteria are met for the given issues
  ///
  /// This method can be overridden by subclasses to provide custom
  /// pass/fail logic. By default, it passes if there are no critical issues.
  ///
  /// Returns true if criteria are met (audit passes), false otherwise.
  bool passedCriteria(List<Issue> issues) {
    // Default implementation: pass if no critical issues
    return !issues.any((issue) => issue.severity == IssueSeverity.critical);
  }

  /// Gets the reason for failure if criteria are not met
  ///
  /// This method can be overridden to provide detailed failure reasons.
  /// Only called when passedCriteria returns false.
  String getFailureReason(List<Issue> issues) {
    final criticalIssues = issues
        .where((issue) => issue.severity == IssueSeverity.critical)
        .toList();

    if (criticalIssues.isNotEmpty) {
      final descriptions = criticalIssues
          .map((issue) => issue.description)
          .join(', ');
      return 'Critical issues found: $descriptions';
    }

    return 'Custom criteria not met';
  }
}
