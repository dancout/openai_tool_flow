import 'issue.dart';
import 'tool_result.dart';

/// Abstract base class for audit functions.
/// 
/// Developers implement this class to provide domain-specific audit logic.
/// An audit inspects tool outputs and produces Issue objects.
abstract class AuditFunction {
  /// Name of this audit function
  String get name;

  /// Executes the audit on a tool result and returns any issues found
  /// 
  /// This method should be implemented by subclasses to provide
  /// domain-specific audit logic.
  List<Issue> run(ToolResult result);
}

/// A simple audit function that can be created with a function
class SimpleAuditFunction extends AuditFunction {
  @override
  final String name;
  
  final List<Issue> Function(ToolResult) _auditFunction;

  /// Creates a simple audit function with a name and audit function
  SimpleAuditFunction({
    required this.name,
    required List<Issue> Function(ToolResult) auditFunction,
  }) : _auditFunction = auditFunction;

  @override
  List<Issue> run(ToolResult result) => _auditFunction(result);
}