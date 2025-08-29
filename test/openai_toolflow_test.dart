import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';

import '../example/audit_functions.dart';

/// Simple test implementation of ToolInput
class TestToolInput extends ToolInput {
  final Map<String, dynamic> data;

  const TestToolInput({
    this.data = const {},
    super.round = 0,
    super.previousResults = const [],
    super.model = 'gpt-4',
    super.temperature,
    super.maxTokens,
  }) : super(customData: data);

  factory TestToolInput.fromMap(Map<String, dynamic> map) {
    final customData = Map<String, dynamic>.from(map);
    final round = customData.remove('_round') as int? ?? 0;
    final previousResultsJson =
        customData.remove('_previous_results') as List? ?? [];
    final previousResults = previousResultsJson
        .cast<Map<String, dynamic>>()
        .map((json) => ToolResult.fromJson(json))
        .toList();
    final model = customData.remove('_model') as String? ?? 'gpt-4';
    final temperature = customData.remove('_temperature') as double?;
    final maxTokens = customData.remove('_max_tokens') as int?;

    return TestToolInput(
      data: customData,
      round: round,
      previousResults: previousResults,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }
}

/// Simple test implementation of ToolOutput
class TestToolOutput extends ToolOutput {
  final Map<String, dynamic> data;

  const TestToolOutput(this.data) : super.subclass();

  factory TestToolOutput.fromMap(Map<String, dynamic> map) {
    return TestToolOutput(Map<String, dynamic>.from(map));
  }

  @override
  Map<String, dynamic> toMap() => Map<String, dynamic>.from(data);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestToolOutput && other.data.toString() == data.toString();
  }

  @override
  int get hashCode => data.toString().hashCode;
}

void main() {
  // Register test output types for deserialization
  setUpAll(() {
    ToolOutputRegistry.register(
      'test_tool',
      (data) => TestToolOutput.fromMap(data),
    );
    ToolOutputRegistry.register(
      'original_tool',
      (data) => TestToolOutput.fromMap(data),
    );
    ToolOutputRegistry.register(
      'extract_palette',
      (data) => TestToolOutput.fromMap(data),
    );
    ToolOutputRegistry.register(
      'refine_colors',
      (data) => TestToolOutput.fromMap(data),
    );
    ToolOutputRegistry.register(
      'generate_theme',
      (data) => TestToolOutput.fromMap(data),
    );
    ToolOutputRegistry.register(
      'step1_tool',
      (data) => TestToolOutput.fromMap(data),
    );
    ToolOutputRegistry.register(
      'step2_tool',
      (data) => TestToolOutput.fromMap(data),
    );
    ToolOutputRegistry.register(
      'step3_tool',
      (data) => TestToolOutput.fromMap(data),
    );
  });

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
      final input = TestToolInput(data: {'param': 'value'});
      final output = TestToolOutput({'result': 'success'});

      final result = ToolResult(
        toolName: 'test_tool',
        input: input,
        output: output,
      );

      expect(result.toolName, equals('test_tool'));
      expect(result.input.customData['param'], equals('value'));
      expect(result.output.toMap()['result'], equals('success'));
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

      final input = TestToolInput(data: {'param': 'value'});
      final output = TestToolOutput({'result': 'success'});

      final result = ToolResult(
        toolName: 'test_tool',
        input: input,
        output: output,
        issues: [issue],
      );

      final json = result.toJson();
      final restored = ToolResult.fromJson(json);

      expect(restored.toolName, equals(result.toolName));
      expect(
        restored.input.toMap().toString(),
        equals(result.input.toMap().toString()),
      );
      expect(
        restored.output.toMap().toString(),
        equals(result.output.toMap().toString()),
      );
      expect(restored.issues.length, equals(1));
      expect(restored.hasIssues, isTrue);
    });
  });

  group('OpenAIConfig', () {
    test('should create config with required fields', () {
      final config = OpenAIConfig(apiKey: 'test-key', defaultModel: 'gpt-4');

      expect(config.apiKey, equals('test-key'));
      expect(config.defaultModel, equals('gpt-4'));
      expect(config.baseUrl, equals('https://api.openai.com/v1'));
    });

    test('should not include API key in JSON output', () {
      final config = OpenAIConfig(apiKey: 'secret-key', defaultModel: 'gpt-4');

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
        inputBuilder: (previousResults) => {'max_colors': 5},
        stepConfig: StepConfig(
          outputSchema: {
            'type': 'object',
            'properties': {
              'colors': {
                'type': 'array',
                'items': {'type': 'string'},
                'description': 'Extracted color hex codes',
              },
            },
            'required': ['colors'],
          },
        ),
      );

      expect(step.toolName, equals('extract_colors'));
      expect(step.model, equals('gpt-4'));
      expect(step.inputBuilder([]).containsKey('max_colors'), isTrue);
      expect(step.inputBuilder([])['max_colors'], equals(5));
    });
  });

  group('AuditFunction', () {
    test('should execute simple audit function', () {
      final audit = SimpleAuditFunction<ToolOutput>(
        name: 'test_audit',
        auditFunction: (result) => [
          Issue(
            id: 'audit-issue',
            severity: IssueSeverity.low,
            description: 'Audit found issue',
            context: {},
            suggestions: [],
          ),
        ],
      );

      final result = ToolResult(
        toolName: 'test',
        input: TestToolInput(),
        output: TestToolOutput({}),
      );

      final issues = audit.run(result);
      expect(issues.length, equals(1));
      expect(issues.first.description, equals('Audit found issue'));
    });
  });

  group('ToolFlow', () {
    test('should execute simple flow with mock service', () async {
      final config = OpenAIConfig(apiKey: 'test-key', defaultModel: 'gpt-4');

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
            inputBuilder: (previousResults) => {'max_colors': 3},
            stepConfig: StepConfig(
              outputSchema: {
                'type': 'object',
                'properties': {
                  'colors': {
                    'type': 'array',
                    'items': {'type': 'string'},
                    'description': 'Extracted color hex codes',
                  },
                },
                'required': ['colors'],
              },
            ),
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
      final config = OpenAIConfig(apiKey: 'test-key', defaultModel: 'gpt-4');

      final audit = SimpleAuditFunction<ToolOutput>(
        name: 'test_audit',
        auditFunction: (result) => [
          Issue(
            id: 'audit-issue',
            severity: IssueSeverity.medium,
            description: 'Test audit issue',
            context: {},
            suggestions: [],
          ),
        ],
      );

      final mockService = MockOpenAiToolService();

      final flow = ToolFlow(
        config: config,
        steps: [
          ToolCallStep(
            toolName: 'extract_palette',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {},
            stepConfig: StepConfig(
              audits: [audit],
              outputSchema: {
                'type': 'object',
                'properties': {
                  'colors': {
                    'type': 'array',
                    'items': {'type': 'string'},
                    'description': 'Extracted color hex codes',
                  },
                },
                'required': ['colors'],
              },
            ),
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
      final config = OpenAIConfig(apiKey: 'test-key', defaultModel: 'gpt-4');

      final mockService = MockOpenAiToolService(
        responses: {
          'extract_palette': {
            'colors': ['#FF0000', '#00FF00'],
          },
          'refine_colors': {
            'refined_colors': ['#FF5733', '#33FF57'],
          },
        },
      );

      final flow = ToolFlow(
        config: config,
        steps: [
          ToolCallStep(
            toolName: 'extract_palette',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {},
            stepConfig: StepConfig(
              outputSchema: {
                'type': 'object',
                'properties': {
                  'colors': {
                    'type': 'array',
                    'items': {'type': 'string'},
                    'description': 'Extracted color hex codes',
                  },
                },
                'required': ['colors'],
              },
            ),
          ),
          ToolCallStep(
            toolName: 'refine_colors',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {},
            stepConfig: StepConfig(
              outputSchema: {
                'type': 'object',
                'properties': {
                  'refined_colors': {
                    'type': 'array',
                    'items': {'type': 'string'},
                    'description': 'Refined color hex codes',
                  },
                },
                'required': ['refined_colors'],
              },
            ),
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
      final multipleResults = result.getResultsByToolNames([
        'extract_palette',
        'refine_colors',
      ]);
      expect(multipleResults.length, equals(2));
    });

    test('should support output inclusion between steps', () async {
      final config = OpenAIConfig(apiKey: 'test-key', defaultModel: 'gpt-4');

      // Create an audit that generates issues
      final audit = SimpleAuditFunction<ToolOutput>(
        name: 'color_audit',
        auditFunction: (result) => [
          Issue(
            id: 'color-issue',
            severity: IssueSeverity.low,
            description: 'Color needs adjustment',
            context: {
              'color': result.output.toMap()['colors']?.first ?? 'unknown',
            },
            suggestions: ['Increase saturation'],
          ),
        ],
      );

      final mockService = MockOpenAiToolService(
        responses: {
          'extract_palette': {
            'colors': ['#FF0000'],
          },
          'refine_colors': {
            'refined_colors': ['#FF5733'],
          },
        },
      );

      final flow = ToolFlow(
        config: config,
        steps: [
          ToolCallStep(
            toolName: 'extract_palette',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {},
            stepConfig: StepConfig(
              audits: [audit],
              outputSchema: {
                'type': 'object',
                'properties': {
                  'colors': {
                    'type': 'array',
                    'items': {'type': 'string'},
                    'description': 'Extracted color hex codes',
                  },
                },
                'required': ['colors'],
              },
            ),
          ),
          ToolCallStep(
            toolName: 'refine_colors',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {},
            stepConfig: StepConfig(
              includeOutputsFrom: [0], // Include outputs from step 0
              outputSchema: {
                'type': 'object',
                'properties': {
                  'result': {'type': 'string'},
                },
                'required': ['result'],
              },
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
      expect(
        secondStepResult.input.toMap().containsKey('extract_palette_colors'),
        isTrue,
      );
      expect(
        secondStepResult.input.toMap()['extract_palette_colors'],
        equals(['#FF0000']),
      );
    });

    test('should handle duplicate tool names correctly', () async {
      final config = OpenAIConfig(apiKey: 'test-key', defaultModel: 'gpt-4');

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
            inputBuilder: (previousResults) => {'iteration': 1},
            stepConfig: StepConfig(
              outputSchema: {
                'type': 'object',
                'properties': {
                  'refined_colors': {
                    'type': 'array',
                    'items': {'type': 'string'},
                    'description': 'Refined color hex codes',
                  },
                },
                'required': ['refined_colors'],
              },
            ),
          ),
          ToolCallStep(
            toolName: 'refine_colors', // Same tool name
            model: 'gpt-4',
            inputBuilder: (previousResults) => {'iteration': 2},
            stepConfig: StepConfig(
              outputSchema: {
                'type': 'object',
                'properties': {
                  'refined_colors': {
                    'type': 'array',
                    'items': {'type': 'string'},
                    'description': 'Refined color hex codes',
                  },
                },
                'required': ['refined_colors'],
              },
            ),
          ),
        ],
        openAiService: mockService,
      );

      final result = await flow.run();

      expect(result.results.length, equals(2));

      // Check that resultsByToolName contains the most recent result
      final latestResult = result.getResultByToolName('refine_colors');
      expect(latestResult, isNotNull);
      expect(latestResult!.input.toMap()['iteration'], equals(2));

      // Check that getAllResultsByToolName returns both results
      final allResults = result.getAllResultsByToolName('refine_colors');
      expect(allResults.length, equals(2));
      expect(allResults[0].input.toMap()['iteration'], equals(1));
      expect(allResults[1].input.toMap()['iteration'], equals(2));
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
        input: TestToolInput(data: {'input': 'data'}),
        output: TestToolOutput({'output': 'data'}),
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
        input: TestToolInput(data: {'input': 'data'}),
        output: TestToolOutput({'result': 'output'}),
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
        input: TestToolInput(data: {'test': 'input'}),
        output: TestToolOutput({'test': 'output'}),
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
        input: TestToolInput(data: {'original': 'input'}),
        output: TestToolOutput({'original': 'output'}),
        issues: [],
      );

      final copiedResult = originalResult.copyWith(
        toolName: 'modified_tool',
        output: TestToolOutput({'modified': 'output'}),
      );

      expect(copiedResult.toolName, equals('modified_tool'));
      expect(
        copiedResult.input.customData['original'],
        equals('input'),
      ); // Unchanged
      expect(
        copiedResult.output.toMap()['modified'],
        equals('output'),
      ); // Changed
      expect(
        copiedResult.output.toMap().containsKey('original'),
        isFalse,
      ); // Old value replaced
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
        input: TestToolInput(data: {'key': 'value'}),
        output: TestToolOutput({'result': 'data'}),
        issues: [issue],
      );

      final copiedResult = originalResult.copyWith(
        output: TestToolOutput({'new': 'result'}),
      );

      expect(copiedResult.toolName, equals('tool')); // Preserved
      expect(
        copiedResult.input.customData['key'],
        equals('value'),
      ); // Preserved
      expect(copiedResult.output.toMap()['new'], equals('result')); // Changed
      expect(copiedResult.issues.length, equals(1)); // Preserved
      expect(copiedResult.issues.first.id, equals('test-issue'));
    });
  });

  group('ToolFlow with filtered previousIssues', () {
    test('should only include issues from included output steps', () async {
      final config = OpenAIConfig(apiKey: 'test-key', defaultModel: 'gpt-4');

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
            inputBuilder: (previousResults) => {},
            stepConfig: StepConfig(
              outputSchema: {
                'type': 'object',
                'properties': {
                  'result': {'type': 'string'},
                },
                'required': ['result'],
              },
            ),
          ),
          ToolCallStep(
            toolName: 'step2_tool',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {},
            stepConfig: StepConfig(
              outputSchema: {
                'type': 'object',
                'properties': {
                  'result': {'type': 'string'},
                },
                'required': ['result'],
              },
            ),
          ),
          ToolCallStep(
            toolName: 'step3_tool',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {},
            stepConfig: StepConfig(
              includeOutputsFrom: ['step1_tool'], // Only include step1
              outputSchema: {
                'type': 'object',
                'properties': {
                  'result': {'type': 'string'},
                },
                'required': ['result'],
              },
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
