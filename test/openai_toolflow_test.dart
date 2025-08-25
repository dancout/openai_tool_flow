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
    test('should execute simple flow with mock service', () async {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      // Create mock service with predefined responses
      final mockService = MockOpenAiToolService(
        responses: {
          'extract_palette': {
            'colors': ['#FF5733', '#33FF57', '#3357FF'],
            'confidence': 0.85,
          },
        },
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
        openAiService: mockService,
      );

      final result = await flow.run(input: {'imagePath': 'test.jpg'});

      expect(result.results.length, equals(1));
      expect(result.results.first.toolName, equals('extract_palette'));
      expect(result.finalOutput, isNotNull);
      expect(result.finalOutput!['colors'], isNotNull);
      expect(result.getResultByToolName('extract_palette'), isNotNull);
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

      final mockService = MockOpenAiToolService();

      final flow = ToolFlow(
        config: config,
        steps: [
          ToolCallStep(
            toolName: 'extract_palette',
            model: 'gpt-4',
            stepConfig: StepConfig(audits: [audit]),
          ),
        ],
        openAiService: mockService,
      );

      final result = await flow.run();

      expect(result.hasIssues, isTrue);
      expect(result.allIssues.length, equals(1));
      expect(result.allIssues.first.description, equals('Test audit issue'));
    });

    test('should support tool name-based result retrieval', () async {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      final mockService = MockOpenAiToolService(
        responses: {
          'extract_palette': {'colors': ['#FF0000', '#00FF00']},
          'refine_colors': {'refined_colors': ['#FF5733', '#33FF57']},
        },
      );

      final flow = ToolFlow(
        config: config,
        steps: [
          ToolCallStep(
            toolName: 'extract_palette',
            model: 'gpt-4',
          ),
          ToolCallStep(
            toolName: 'refine_colors',
            model: 'gpt-4',
          ),
        ],
        openAiService: mockService,
      );

      final result = await flow.run();

      expect(result.results.length, equals(2));
      
      // Test tool name-based retrieval
      final paletteResult = result.getResultByToolName('extract_palette');
      expect(paletteResult, isNotNull);
      expect(paletteResult!.toolName, equals('extract_palette'));
      
      final refineResult = result.getResultByToolName('refine_colors');
      expect(refineResult, isNotNull);
      expect(refineResult!.toolName, equals('refine_colors'));
      
      // Test non-existent tool
      expect(result.getResultByToolName('nonexistent'), isNull);
      
      // Test multiple tool retrieval
      final multipleResults = result.getResultsByToolNames(['extract_palette', 'refine_colors']);
      expect(multipleResults.length, equals(2));
    });

    test('should support issue forwarding between steps', () async {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      // Create an audit that generates issues
      final audit = SimpleAuditFunction(
        name: 'color_audit',
        auditFunction: (result) => [
          Issue(
            id: 'color-issue',
            severity: IssueSeverity.low,
            description: 'Color needs adjustment',
            context: {'color': result.output['colors']?.first ?? 'unknown'},
            suggestions: ['Increase saturation'],
          )
        ],
      );

      final mockService = MockOpenAiToolService(
        responses: {
          'extract_palette': {'colors': ['#FF0000']},
          'refine_colors': {'refined_colors': ['#FF5733']},
        },
      );

      final flow = ToolFlow(
        config: config,
        steps: [
          ToolCallStep(
            toolName: 'extract_palette',
            model: 'gpt-4',
            stepConfig: StepConfig(audits: [audit]),
          ),
          ToolCallStep(
            toolName: 'refine_colors',
            model: 'gpt-4',
            stepConfig: StepConfig(
              forwardingConfigs: [
                ForwardingConfig.issuesOnly(0), // Forward issues from step 0
              ],
            ),
          ),
        ],
        openAiService: mockService,
      );

      final result = await flow.run();

      expect(result.results.length, equals(2));
      expect(result.allIssues.length, equals(1)); // One issue from first step
      
      // Check that second step received forwarded issues
      final secondStepResult = result.results[1];
      expect(secondStepResult.input.containsKey('_forwarded_issues_extract_palette'), isTrue);
    });
  });
}
