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

    test('should support output inclusion between steps', () async {
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
              includeOutputsFrom: [0], // Include outputs from step 0
            ),
          ),
        ],
        openAiService: mockService,
      );

      final result = await flow.run();

      expect(result.results.length, equals(2));
      expect(result.allIssues.length, equals(1)); // One issue from first step
      
      // Check that second step received outputs from first step
      final secondStepResult = result.results[1];
      expect(secondStepResult.input.containsKey('extract_palette_colors'), isTrue);
      expect(secondStepResult.input['extract_palette_colors'], equals(['#FF0000']));
    });

    test('should handle duplicate tool names correctly', () async {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      final mockService = MockOpenAiToolService(
        responses: {
          'refine_colors': {
            'refined_colors': ['#FF5733', '#33FF57'], // First call
          },
        },
      );

      final flow = ToolFlow(
        config: config,
        steps: [
          ToolCallStep(
            toolName: 'refine_colors',
            model: 'gpt-4',
            params: {'iteration': 1},
          ),
          ToolCallStep(
            toolName: 'refine_colors', // Same tool name
            model: 'gpt-4',
            params: {'iteration': 2},
          ),
        ],
        openAiService: mockService,
      );

      final result = await flow.run();

      expect(result.results.length, equals(2));
      
      // Check that resultsByToolName contains the most recent result
      final latestResult = result.getResultByToolName('refine_colors');
      expect(latestResult, isNotNull);
      expect(latestResult!.input['iteration'], equals(2));
      
      // Check that getAllResultsByToolName returns both results
      final allResults = result.getAllResultsByToolName('refine_colors');
      expect(allResults.length, equals(2));
      expect(allResults[0].input['iteration'], equals(1));
      expect(allResults[1].input['iteration'], equals(2));
    });
  });

  group('ToolInput', () {
    test('should create input with structured data and ToolResult objects', () {
      final issue = Issue(
        id: 'test-issue',
        severity: IssueSeverity.low,
        description: 'Test description',
        context: {},
        suggestions: [],
      );

      final previousResult = ToolResult(
        toolName: 'previous_tool',
        input: {'input': 'data'},
        output: {'output': 'data'},
        issues: [issue],
      );

      final input = ToolInput(
        round: 1,
        previousResults: [previousResult],
        customData: {'test': 'value'},
        model: 'gpt-4',
        temperature: 0.8,
        maxTokens: 1000,
      );

      expect(input.round, equals(1));
      expect(input.previousResults.length, equals(1));
      expect(input.previousResults.first.toolName, equals('previous_tool'));
      expect(input.previousResults.first.issues.first.id, equals('test-issue'));
      expect(input.customData['test'], equals('value'));
      expect(input.model, equals('gpt-4'));
      expect(input.temperature, equals(0.8));
      expect(input.maxTokens, equals(1000));
    });

    test('should serialize to Map with structured previousResults', () {
      final issue = Issue(
        id: 'test-issue',
        severity: IssueSeverity.medium,
        description: 'Test issue',
        context: {'key': 'value'},
        suggestions: ['suggestion'],
      );

      final previousResult = ToolResult(
        toolName: 'test_tool',
        input: {'input': 'data'},
        output: {'result': 'output'},
        issues: [issue],
      );

      final input = ToolInput(
        round: 2,
        previousResults: [previousResult],
        customData: {'param': 'data'},
        model: 'gpt-3.5-turbo',
      );

      final map = input.toMap();

      expect(map['_round'], equals(2));
      expect(map['_model'], equals('gpt-3.5-turbo'));
      expect(map['param'], equals('data'));
      expect(map['_previous_results'], isA<List>());
      
      final resultJson = map['_previous_results'][0] as Map<String, dynamic>;
      expect(resultJson['toolName'], equals('test_tool'));
      expect(resultJson['issues'], isA<List>());
      expect(resultJson['issues'][0]['id'], equals('test-issue'));
      expect(resultJson['issues'][0]['severity'], equals('medium'));
    });

    test('should restore from Map with structured previousResults', () {
      final originalIssue = Issue(
        id: 'original-issue',
        severity: IssueSeverity.high,
        description: 'Original description',
        context: {'original': true},
        suggestions: ['fix it'],
      );

      final originalResult = ToolResult(
        toolName: 'original_tool',
        input: {'test': 'input'},
        output: {'test': 'output'},
        issues: [originalIssue],
      );

      final originalInput = ToolInput(
        round: 3,
        previousResults: [originalResult],
        customData: {'custom': 'value'},
        model: 'gpt-4',
        temperature: 0.5,
      );

      final map = originalInput.toMap();
      final restoredInput = ToolInput.fromMap(map);

      expect(restoredInput.round, equals(3));
      expect(restoredInput.model, equals('gpt-4'));
      expect(restoredInput.customData['custom'], equals('value'));
      expect(restoredInput.previousResults.length, equals(1));
      
      final restoredResult = restoredInput.previousResults.first;
      expect(restoredResult.toolName, equals('original_tool'));
      expect(restoredResult.issues.length, equals(1));
      
      final restoredIssue = restoredResult.issues.first;
      expect(restoredIssue.id, equals('original-issue'));
      expect(restoredIssue.severity, equals(IssueSeverity.high));
      expect(restoredIssue.description, equals('Original description'));
    });

    test('ToolInput should work without StepInput alias', () {
      final toolInput = ToolInput(customData: {'test': 'value'});
      expect(toolInput, isA<ToolInput>());
      expect(toolInput.customData['test'], equals('value'));
    });
  });

  group('ToolResult copyWith', () {
    test('should create copy with modified fields', () {
      final originalResult = ToolResult(
        toolName: 'original_tool',
        input: {'original': 'input'},
        output: {'original': 'output'},
        issues: [],
      );

      final copiedResult = originalResult.copyWith(
        toolName: 'modified_tool',
        output: {'modified': 'output'},
      );

      expect(copiedResult.toolName, equals('modified_tool'));
      expect(copiedResult.input['original'], equals('input')); // Unchanged
      expect(copiedResult.output['modified'], equals('output')); // Changed
      expect(copiedResult.output.containsKey('original'), isFalse); // Old value replaced
      expect(copiedResult.issues, isEmpty);
    });

    test('should preserve unchanged fields', () {
      final issue = Issue(
        id: 'test-issue',
        severity: IssueSeverity.low,
        description: 'Test',
        context: {},
        suggestions: [],
      );

      final originalResult = ToolResult(
        toolName: 'tool',
        input: {'key': 'value'},
        output: {'result': 'data'},
        issues: [issue],
      );

      final copiedResult = originalResult.copyWith(
        output: {'new': 'result'},
      );

      expect(copiedResult.toolName, equals('tool')); // Preserved
      expect(copiedResult.input['key'], equals('value')); // Preserved
      expect(copiedResult.output['new'], equals('result')); // Changed
      expect(copiedResult.issues.length, equals(1)); // Preserved
      expect(copiedResult.issues.first.id, equals('test-issue'));
    });
  });

  group('ToolFlow with filtered previousIssues', () {
    test('should only include issues from included output steps', () async {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      final mockService = MockOpenAiToolService(
        responses: {
          'step1_tool': {'result': 'step1'},
          'step2_tool': {'result': 'step2'},
          'step3_tool': {'result': 'step3'},
        },
      );

      final flow = ToolFlow(
        config: config,
        steps: [
          ToolCallStep(
            toolName: 'step1_tool',
            model: 'gpt-4',
            params: {},
          ),
          ToolCallStep(
            toolName: 'step2_tool',
            model: 'gpt-4',
            params: {},
          ),
          ToolCallStep(
            toolName: 'step3_tool',
            model: 'gpt-4',
            params: {},
            stepConfig: StepConfig(
              includeOutputsFrom: ['step1_tool'], // Only include step1
            ),
          ),
        ],
        openAiService: mockService,
      );

      final result = await flow.run();
      expect(result.results.length, equals(3));
      
      // Verify that the flow completed successfully
      expect(result.results[0].toolName, equals('step1_tool'));
      expect(result.results[1].toolName, equals('step2_tool'));
      expect(result.results[2].toolName, equals('step3_tool'));
    });
  });
}
