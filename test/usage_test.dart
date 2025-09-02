/// Tests for utility functions in usage.dart
library;

import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';

/// Helper function from usage.dart for filtering issues by severity
List<Issue> issuesWithSeverity(
  List<Issue> allIssues,
  IssueSeverity severity,
) {
  return allIssues.where((issue) => issue.severity == severity).toList();
}

void main() {
  group('issuesWithSeverity helper function', () {
    test('should filter issues by severity correctly', () {
      final issues = [
        Issue(
          id: 'critical-1',
          severity: IssueSeverity.critical,
          description: 'Critical issue',
          context: {},
          suggestions: [],
        ),
        Issue(
          id: 'high-1',
          severity: IssueSeverity.high,
          description: 'High issue',
          context: {},
          suggestions: [],
        ),
        Issue(
          id: 'critical-2',
          severity: IssueSeverity.critical,
          description: 'Another critical issue',
          context: {},
          suggestions: [],
        ),
      ];

      final criticalIssues = issuesWithSeverity(
        issues,
        IssueSeverity.critical,
      );
      final highIssues = issuesWithSeverity(issues, IssueSeverity.high);
      final lowIssues = issuesWithSeverity(issues, IssueSeverity.low);

      expect(criticalIssues.length, equals(2));
      expect(highIssues.length, equals(1));
      expect(lowIssues.length, equals(0));

      expect(criticalIssues.first.id, equals('critical-1'));
      expect(criticalIssues.last.id, equals('critical-2'));
      expect(highIssues.first.id, equals('high-1'));
    });

    test('should return empty list when no issues match severity', () {
      final issues = [
        Issue(
          id: 'medium-1',
          severity: IssueSeverity.medium,
          description: 'Medium issue',
          context: {},
          suggestions: [],
        ),
      ];

      final criticalIssues = issuesWithSeverity(
        issues,
        IssueSeverity.critical,
      );
      
      expect(criticalIssues, isEmpty);
    });

    test('should handle empty issue list', () {
      final issues = <Issue>[];

      final criticalIssues = issuesWithSeverity(
        issues,
        IssueSeverity.critical,
      );
      
      expect(criticalIssues, isEmpty);
    });

    test('should filter all severity levels correctly', () {
      final issues = [
        Issue(
          id: 'critical-1',
          severity: IssueSeverity.critical,
          description: 'Critical issue',
          context: {},
          suggestions: [],
        ),
        Issue(
          id: 'high-1',
          severity: IssueSeverity.high,
          description: 'High issue',
          context: {},
          suggestions: [],
        ),
        Issue(
          id: 'medium-1',
          severity: IssueSeverity.medium,
          description: 'Medium issue',
          context: {},
          suggestions: [],
        ),
        Issue(
          id: 'low-1',
          severity: IssueSeverity.low,
          description: 'Low issue',
          context: {},
          suggestions: [],
        ),
      ];

      expect(
        issuesWithSeverity(issues, IssueSeverity.critical).length,
        equals(1),
      );
      expect(
        issuesWithSeverity(issues, IssueSeverity.high).length,
        equals(1),
      );
      expect(
        issuesWithSeverity(issues, IssueSeverity.medium).length,
        equals(1),
      );
      expect(
        issuesWithSeverity(issues, IssueSeverity.low).length,
        equals(1),
      );
    });
  });
}