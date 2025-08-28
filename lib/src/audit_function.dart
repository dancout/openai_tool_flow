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
    final criticalIssues = issues.where((issue) => issue.severity == IssueSeverity.critical).toList();
    
    if (criticalIssues.isNotEmpty) {
      final descriptions = criticalIssues.map((issue) => issue.description).join(', ');
      return 'Critical issues found: $descriptions';
    }
    
    return 'Custom criteria not met';
  }
}