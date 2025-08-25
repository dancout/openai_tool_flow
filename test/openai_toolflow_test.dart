import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';
import '../example/audit_functions.dart';

void main() {
  group('Issue', () {
    test('should create an issue with required fields', () {
      final issue = Issue(
        id: 'test-issue-1',
        severity: IssueSeverity.medium,
        description: 'Test issue description',
        context: {'test': true},
        suggestions: ['Fix the test'],
      );

      expect(issue.id, equals('test-issue-1'));
      expect(issue.severity, equals(IssueSeverity.medium));
      expect(issue.description, equals('Test issue description'));
      expect(issue.context['test'], isTrue);
      expect(issue.suggestions, contains('Fix the test'));
    });

    test('should serialize to and from JSON', () {
      final issue = Issue(
        id: 'test-issue-1',
        severity: IssueSeverity.high,
        description: 'Test issue description',
        context: {'test': true},
        suggestions: ['Fix the test'],
      );

      final json = issue.toJson();
      final restored = Issue.fromJson(json);

      expect(restored.id, equals(issue.id));
      expect(restored.severity, equals(issue.severity));
      expect(restored.description, equals(issue.description));
      expect(restored.context.toString(), equals(issue.context.toString()));
      expect(restored.suggestions, equals(issue.suggestions));
    });
  });

  group('ToolResult', () {
    test('should create a tool result with required fields', () {
      final result = ToolResult(
        toolName: 'test_tool',
        input: {'param': 'value'},
        output: {'result': 'success'},
      );

      expect(result.toolName, equals('test_tool'));
      expect(result.input['param'], equals('value'));
      expect(result.output['result'], equals('success'));
      expect(result.issues, isEmpty);
      expect(result.hasIssues, isFalse);
    });

    test('should serialize to and from JSON', () {
      final issue = Issue(
        id: 'test-issue',
        severity: IssueSeverity.low,
        description: 'Test description',
        context: {},
        suggestions: [],
      );

      final result = ToolResult(
        toolName: 'test_tool',
        input: {'param': 'value'},
        output: {'result': 'success'},
        issues: [issue],
      );

      final json = result.toJson();
      final restored = ToolResult.fromJson(json);

      expect(restored.toolName, equals(result.toolName));
      expect(restored.input.toString(), equals(result.input.toString()));
      expect(restored.output.toString(), equals(result.output.toString()));
      expect(restored.issues.length, equals(1));
      expect(restored.hasIssues, isTrue);
    });
  });

  group('OpenAIConfig', () {
    test('should create config with required fields', () {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      expect(config.apiKey, equals('test-key'));
      expect(config.defaultModel, equals('gpt-4'));
      expect(config.baseUrl, equals('https://api.openai.com/v1'));
    });

    test('should not include API key in JSON output', () {
      final config = OpenAIConfig(
        apiKey: 'secret-key',
        defaultModel: 'gpt-4',
      );

      final json = config.toJson();
      expect(json, isNot(contains('secret-key')));
      expect(json['defaultModel'], equals('gpt-4'));
    });
  });

  group('ToolCallStep', () {
    test('should create step with required fields', () {
      final step = ToolCallStep(
        toolName: 'extract_colors',
        model: 'gpt-4',
        params: {'max_colors': 5},
      );

      expect(step.toolName, equals('extract_colors'));
      expect(step.model, equals('gpt-4'));
      expect(step.params['max_colors'], equals(5));
    });

    test('should serialize to and from JSON', () {
      final step = ToolCallStep(
        toolName: 'extract_colors',
        model: 'gpt-4',
        params: {'max_colors': 5},
      );

      final json = step.toJson();
      final restored = ToolCallStep.fromJson(json);

      expect(restored.toolName, equals(step.toolName));
      expect(restored.model, equals(step.model));
      expect(restored.params.toString(), equals(step.params.toString()));
    });
  });

  group('AuditFunction', () {
    test('should execute simple audit function', () {
      final audit = SimpleAuditFunction(
        name: 'test_audit',
        auditFunction: (result) => [
          Issue(
            id: 'audit-issue',
            severity: IssueSeverity.low,
            description: 'Audit found issue',
            context: {},
            suggestions: [],
          )
        ],
      );

      final result = ToolResult(
        toolName: 'test',
        input: {},
        output: {},
      );

      final issues = audit.run(result);
      expect(issues.length, equals(1));
      expect(issues.first.description, equals('Audit found issue'));
    });
  });

  group('ToolFlow', () {
    test('should execute simple flow', () async {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      final flow = ToolFlow(
        config: config,
        steps: [
          ToolCallStep(
            toolName: 'extract_palette',
            model: 'gpt-4',
            params: {'max_colors': 3},
          ),
        ],
        useMockResponses: true, // Enable mock mode for testing
      );

      final result = await flow.run(input: {'imagePath': 'test.jpg'});

      expect(result.results.length, equals(1));
      expect(result.results.first.toolName, equals('extract_palette'));
      expect(result.finalOutput, isNotNull);
    });

    test('should collect issues from audits', () async {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      final audit = SimpleAuditFunction(
        name: 'test_audit',
        auditFunction: (result) => [
          Issue(
            id: 'audit-issue',
            severity: IssueSeverity.medium,
            description: 'Test audit issue',
            context: {},
            suggestions: [],
          )
        ],
      );

      final flow = ToolFlow(
        config: config,
        steps: [
          ToolCallStep(
            toolName: 'extract_palette',
            model: 'gpt-4',
          ),
        ],
        audits: [audit],
        useMockResponses: true, // Enable mock mode for testing
      );

      final result = await flow.run();

      expect(result.hasIssues, isTrue);
      expect(result.allIssues.length, equals(1));
      expect(result.allIssues.first.description, equals('Test audit issue'));
    });
  });
}
