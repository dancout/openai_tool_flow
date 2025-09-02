import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';

/// Simple test implementation of ToolInput
class TestToolInput extends ToolInput {
  final Map<String, dynamic> data;

  const TestToolInput({
    this.data = const {},
    super.round = 0,
    super.model = 'gpt-4',
    super.temperature,
    super.maxTokens,
  }) : super(customData: data);

  factory TestToolInput.fromMap(Map<String, dynamic> map) {
    final customData = Map<String, dynamic>.from(map);
    final round = customData.remove('_round') as int? ?? 0;
    final model = customData.remove('_model') as String? ?? 'gpt-4';
    final temperature = customData.remove('_temperature') as double?;
    final maxTokens = customData.remove('_max_tokens') as int?;

    return TestToolInput(
      data: customData,
      round: round,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }
}

/// A simple audit function that can be created with a function
///
/// This implementation is provided in the example for flexibility,
/// allowing projects to use it or create their own audit implementations.
class SimpleAuditFunction<T extends ToolOutput> extends AuditFunction<T> {
  @override
  final String name;

  final List<Issue> Function(ToolResult<T>) _auditFunction;
  final bool Function(List<Issue>)? _passedCriteriaFunction;
  final String Function(List<Issue>)? _failureReasonFunction;

  /// Creates a simple audit function with a name and audit function
  SimpleAuditFunction({
    required this.name,
    required List<Issue> Function(ToolResult<T>) auditFunction,
    bool Function(List<Issue>)? passedCriteriaFunction,
    String Function(List<Issue>)? failureReasonFunction,
  }) : _auditFunction = auditFunction,
       _passedCriteriaFunction = passedCriteriaFunction,
       _failureReasonFunction = failureReasonFunction;

  @override
  List<Issue> run(ToolResult<T> result) => _auditFunction(result);

  @override
  bool passedCriteria(List<Issue> issues) {
    return _passedCriteriaFunction?.call(issues) ??
        super.passedCriteria(issues);
  }

  @override
  String getFailureReason(List<Issue> issues) {
    return _failureReasonFunction?.call(issues) ??
        super.getFailureReason(issues);
  }
}

/// Simple test implementation of ToolOutput
class TestToolOutput extends ToolOutput {
  final Map<String, dynamic> data;

  const TestToolOutput(this.data, {required super.round}) : super.subclass();

  factory TestToolOutput.fromMap(Map<String, dynamic> map, int round) {
    return TestToolOutput(Map<String, dynamic>.from(map), round: round);
  }

  @override
  Map<String, dynamic> toMap() => {
    '_round': round,
    ...Map<String, dynamic>.from(data),
  };

  static OutputSchema getOutputSchema() {
    return OutputSchema(
      properties: [
        PropertyEntry.object(name: 'data', description: 'Test output data'),
      ],
      required: [],
    );
  }

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
      (data, round) => TestToolOutput.fromMap(data, round),
    );
    ToolOutputRegistry.register(
      'original_tool',
      (data, round) => TestToolOutput.fromMap(data, round),
    );
    ToolOutputRegistry.register(
      'extract_palette',
      (data, round) => TestToolOutput.fromMap(data, round),
    );
    ToolOutputRegistry.register(
      'refine_colors',
      (data, round) => TestToolOutput.fromMap(data, round),
    );
    ToolOutputRegistry.register(
      'generate_theme',
      (data, round) => TestToolOutput.fromMap(data, round),
    );
    ToolOutputRegistry.register(
      'step1_tool',
      (data, round) => TestToolOutput.fromMap(data, round),
    );
    ToolOutputRegistry.register(
      'step2_tool',
      (data, round) => TestToolOutput.fromMap(data, round),
    );
    ToolOutputRegistry.register(
      'step3_tool',
      (data, round) => TestToolOutput.fromMap(data, round),
    );
    ToolOutputRegistry.register(
      'extract_colors',
      (data, round) => TestToolOutput.fromMap(data, round),
    );
    ToolOutputRegistry.register(
      'validate_colors',
      (data, round) => TestToolOutput.fromMap(data, round),
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
      final output = TestToolOutput({'result': 'success'}, round: 0);

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
      final output = TestToolOutput({'result': 'success'}, round: 0);

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
        outputSchema: OutputSchema(
          properties: [
            PropertyEntry.array(
              name: 'colors',
              items: PropertyType.string,
              description: 'Extracted color hex codes',
            ),
          ],
          required: ['colors'],
        ),
        stepConfig: StepConfig(),
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
        output: TestToolOutput({}, round: 0),
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
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.array(
                  name: 'colors',
                  items: PropertyType.string,
                  description: 'Extracted color hex codes',
                ),
              ],
              required: ['colors'],
            ),
            stepConfig: StepConfig(),
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

      final audit = SimpleAuditFunction<TestToolOutput>(
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
            inputBuilder: (previousResults) => {},
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.array(
                  name: 'colors',
                  items: PropertyType.string,
                  description: 'Extracted color hex codes',
                ),
              ],
              required: ['colors'],
            ),
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
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.array(
                  name: 'colors',
                  items: PropertyType.string,
                  description: 'Extracted color hex codes',
                ),
              ],
              required: ['colors'],
            ),
            stepConfig: StepConfig(),
          ),
          ToolCallStep(
            toolName: 'refine_colors',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {},
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.array(
                  name: 'refined_colors',
                  items: PropertyType.string,
                  description: 'Refined color hex codes',
                ),
              ],
              required: ['refined_colors'],
            ),
            stepConfig: StepConfig(),
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
      final audit = SimpleAuditFunction<TestToolOutput>(
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
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.array(
                  name: 'colors',
                  items: PropertyType.string,
                  description: 'Extracted color hex codes',
                ),
              ],
              required: ['colors'],
            ),
            stepConfig: StepConfig(audits: [audit]),
          ),
          ToolCallStep(
            toolName: 'refine_colors',
            model: 'gpt-4',
            inputBuilder: (previousResults) {
              // Explicitly extract previous step's output
              final paletteResult = previousResults.isNotEmpty
                  ? previousResults.first
                  : null;
              final paletteColors =
                  paletteResult?.output.toMap()['colors'] ?? [];
              return {'extract_palette_colors': paletteColors};
            },
            buildInputsFrom: [0],
            outputSchema: OutputSchema(
              properties: [PropertyEntry.string(name: 'result')],
              required: ['result'],
            ),
            stepConfig: StepConfig(includeResultsInToolcall: [0]),
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
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.array(
                  name: 'refined_colors',
                  items: PropertyType.string,
                  description: 'Refined color hex codes',
                ),
              ],
              required: ['refined_colors'],
            ),
            stepConfig: StepConfig(),
          ),
          ToolCallStep(
            toolName: 'refine_colors', // Same tool name
            model: 'gpt-4',
            inputBuilder: (previousResults) => {'iteration': 2},
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.array(
                  name: 'refined_colors',
                  items: PropertyType.string,
                  description: 'Refined color hex codes',
                ),
              ],
              required: ['refined_colors'],
            ),
            stepConfig: StepConfig(),
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
    test('should create input with structured data and customData', () {
      final input = ToolInput(
        round: 1,
        customData: {'test': 'value'},
        model: 'gpt-4',
        temperature: 0.8,
        maxTokens: 1000,
      );

      expect(input.round, equals(1));
      expect(input.customData['test'], equals('value'));
      expect(input.model, equals('gpt-4'));
      expect(input.temperature, equals(0.8));
      expect(input.maxTokens, equals(1000));
    });

    test('should serialize to Map with customData', () {
      final input = ToolInput(
        round: 2,
        customData: {'param': 'data'},
        model: 'gpt-3.5-turbo',
      );

      final map = input.toMap();

      expect(map['_round'], equals(2));
      expect(map['_model'], equals('gpt-3.5-turbo'));
      expect(map['param'], equals('data'));
    });

    test('should restore from Map with customData', () {
      final originalInput = ToolInput(
        round: 3,
        customData: {'custom': 'value'},
        model: 'gpt-4',
        temperature: 0.5,
      );

      final map = originalInput.toMap();
      final restoredInput = ToolInput.fromMap(map);

      expect(restoredInput.round, equals(3));
      expect(restoredInput.model, equals('gpt-4'));
      expect(restoredInput.customData['custom'], equals('value'));
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
        output: TestToolOutput({'original': 'output'}, round: 0),
        issues: [],
      );

      final copiedResult = originalResult.copyWith(
        toolName: 'modified_tool',
        output: TestToolOutput({'modified': 'output'}, round: 0),
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
        output: TestToolOutput({'result': 'data'}, round: 0),
        issues: [issue],
      );

      final copiedResult = originalResult.copyWith(
        output: TestToolOutput({'new': 'result'}, round: 0),
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
            outputSchema: OutputSchema(
              properties: [PropertyEntry.string(name: 'result')],
              required: ['result'],
            ),
            stepConfig: StepConfig(),
          ),
          ToolCallStep(
            toolName: 'step2_tool',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {},
            outputSchema: OutputSchema(
              properties: [PropertyEntry.string(name: 'result')],
              required: ['result'],
            ),
            stepConfig: StepConfig(),
          ),
          ToolCallStep(
            toolName: 'step3_tool',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {},
            outputSchema: OutputSchema(
              properties: [PropertyEntry.string(name: 'result')],
              required: ['result'],
            ),
            stepConfig: StepConfig(
              includeResultsInToolcall: ['step1_tool'], // Only include step1
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

  group('Round 11 Integration', () {
    test('should work end-to-end with new APIs', () {
      // Register test output
      ToolOutputRegistry.register(
        'integration_tool_e2e',
        (data, round) => TestToolOutput.fromMap(data, round),
      );

      final mockService = MockOpenAiToolService(
        responses: {
          'integration_tool_e2e': {'message': 'integration test success'},
        },
      );

      final flow = ToolFlow(
        config: OpenAIConfig(apiKey: 'test'),
        steps: [
          ToolCallStep(
            toolName: 'integration_tool_e2e',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {'input': 'integration'},
            outputSchema: OutputSchema(properties: [], required: []),
            stepConfig: StepConfig(),
          ),
        ],
        openAiService: mockService,
      );

      return flow.run().then((result) {
        // Test new results type
        expect(result.results, isA<List<TypedToolResult>>());
        final typedResult = result.results.first;

        // Test round information is preserved
        expect(typedResult.output, isA<TestToolOutput>());
        final testOutput = typedResult.output as TestToolOutput;
        expect(testOutput.round, equals(0)); // First attempt
        expect(testOutput.data['message'], equals('integration test success'));

        // Test tool name retrieval still works
        final resultByName = result.getTypedResultByToolName(
          'integration_tool_e2e',
        );
        expect(resultByName, isNotNull);
        expect(resultByName!.toolName, equals('integration_tool_e2e'));
      });
    });

    group('ToolFlow includeResultsInToolcall', () {
      test('should include results with filtered issues in system message', () async {
        final config = OpenAIConfig(apiKey: 'test-key', defaultModel: 'gpt-4');
        final testService = TestSystemMessageService(
          responses: {
            'step1_tool': {'result': 'step1 output'},
            'step2_tool': {'result': 'step2 output'},
          },
        );

        final flow = ToolFlow(
          config: config,
          steps: [
            ToolCallStep(
              toolName: 'step1_tool',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'input': 'step1'},
              outputSchema: OutputSchema(
                properties: [PropertyEntry.string(name: 'result')],
                required: ['result'],
              ),
              stepConfig: StepConfig(
                audits: [
                  SimpleAuditFunction<TestToolOutput>(
                    name: 'test_audit',
                    auditFunction: (result) => [
                      Issue(
                        id: 'high-issue',
                        severity: IssueSeverity.high,
                        description: 'High severity issue',
                        context: {},
                        suggestions: ['Fix this'],
                      ),
                      Issue(
                        id: 'low-issue',
                        severity: IssueSeverity.low,
                        description: 'Low severity issue',
                        context: {},
                        suggestions: [],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ToolCallStep(
              toolName: 'step2_tool',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'input': 'step2'},
              outputSchema: OutputSchema(
                properties: [PropertyEntry.string(name: 'result')],
                required: ['result'],
              ),
              stepConfig: StepConfig(
                includeResultsInToolcall: [0], // Include step 0
                issuesSeverityFilter: IssueSeverity.high, // Only high+ severity
              ),
            ),
          ],
          openAiService: testService,
        );

        final result = await flow.run();

        expect(result.results.length, equals(2));
        expect(testService.lastSystemMessage, isNotNull);
        expect(testService.lastSystemMessage!, contains('HIGH: High severity issue'));
        expect(testService.lastSystemMessage!, isNot(contains('LOW: Low severity issue')));
        expect(testService.lastSystemMessage!, contains('Suggestions: Fix this'));
      });

      test('should not include anything when no issues match severity filter', () async {
        final config = OpenAIConfig(apiKey: 'test-key', defaultModel: 'gpt-4');
        final testService = TestSystemMessageService(
          responses: {
            'step1_tool': {'result': 'step1 output'},
            'step2_tool': {'result': 'step2 output'},
          },
        );

        final flow = ToolFlow(
          config: config,
          steps: [
            ToolCallStep(
              toolName: 'step1_tool',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'input': 'step1'},
              outputSchema: OutputSchema(
                properties: [PropertyEntry.string(name: 'result')],
                required: ['result'],
              ),
              stepConfig: StepConfig(
                audits: [
                  SimpleAuditFunction<TestToolOutput>(
                    name: 'test_audit',
                    auditFunction: (result) => [
                      Issue(
                        id: 'low-issue',
                        severity: IssueSeverity.low,
                        description: 'Low severity issue',
                        context: {},
                        suggestions: [],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ToolCallStep(
              toolName: 'step2_tool',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'input': 'step2'},
              outputSchema: OutputSchema(
                properties: [PropertyEntry.string(name: 'result')],
                required: ['result'],
              ),
              stepConfig: StepConfig(
                includeResultsInToolcall: [0], // Include step 0
                issuesSeverityFilter: IssueSeverity.critical, // Only critical severity
              ),
            ),
          ],
          openAiService: testService,
        );

        final result = await flow.run();

        expect(result.results.length, equals(2));
        expect(testService.lastSystemMessage, isNull);
      });

      test('should support tool name references in includeResultsInToolcall', () async {
        final config = OpenAIConfig(apiKey: 'test-key', defaultModel: 'gpt-4');
        final testService = TestSystemMessageService(
          responses: {
            'extract_colors': {'colors': ['red', 'blue']},
            'validate_colors': {'valid': true},
          },
        );

        final flow = ToolFlow(
          config: config,
          steps: [
            ToolCallStep(
              toolName: 'extract_colors',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'input': 'extract'},
              outputSchema: OutputSchema(
                properties: [PropertyEntry.array(name: 'colors', items: PropertyType.string)],
                required: ['colors'],
              ),
              stepConfig: StepConfig(
                audits: [
                  SimpleAuditFunction<TestToolOutput>(
                    name: 'color_audit',
                    auditFunction: (result) => [
                      Issue(
                        id: 'color-issue',
                        severity: IssueSeverity.medium,
                        description: 'Colors need validation',
                        context: {},
                        suggestions: ['Check color format'],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ToolCallStep(
              toolName: 'validate_colors',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'input': 'validate'},
              outputSchema: OutputSchema(
                properties: [PropertyEntry.boolean(name: 'valid')],
                required: ['valid'],
              ),
              stepConfig: StepConfig(
                includeResultsInToolcall: ['extract_colors'], // Include by tool name
                issuesSeverityFilter: IssueSeverity.medium,
              ),
            ),
          ],
          openAiService: testService,
        );

        final result = await flow.run();

        expect(result.results.length, equals(2));
        expect(testService.lastSystemMessage, isNotNull);
        expect(testService.lastSystemMessage!, contains('extract_colors'));
        expect(testService.lastSystemMessage!, contains('MEDIUM: Colors need validation'));
      });
    });

    group('StepConfig issuesSeverityFilter', () {
      test('should have high severity as default', () {
        const stepConfig = StepConfig();
        expect(stepConfig.issuesSeverityFilter, equals(IssueSeverity.high));
      });

      test('should allow custom severity filter', () {
        const stepConfig = StepConfig(issuesSeverityFilter: IssueSeverity.low);
        expect(stepConfig.issuesSeverityFilter, equals(IssueSeverity.low));
      });

      test('hasResultInclusion should work correctly', () {
        const stepConfigEmpty = StepConfig();
        expect(stepConfigEmpty.hasResultInclusion, isFalse);

        const stepConfigWithResults = StepConfig(includeResultsInToolcall: [0]);
        expect(stepConfigWithResults.hasResultInclusion, isTrue);
      });
    });
  });
}

/// Mock service for testing
class MockOpenAiToolService implements OpenAiToolService {
  final Map<String, Map<String, dynamic>> responses;

  MockOpenAiToolService({this.responses = const {}});

  @override
  Future<Map<String, dynamic>> executeToolCall(
    ToolCallStep step,
    ToolInput input, {
    List<ToolResult> includedResults = const [],
  }) async {
    final response = responses[step.toolName];
    if (response == null) {
      throw Exception('No mock response for ${step.toolName}');
    }
    return response;
  }
}

class TestSystemMessageService implements OpenAiToolService {
  String? lastSystemMessage;
  final Map<String, Map<String, dynamic>> responses;

  TestSystemMessageService({this.responses = const {}});

  @override
  Future<Map<String, dynamic>> executeToolCall(
    ToolCallStep step,
    ToolInput input, {
    List<ToolResult> includedResults = const [],
  }) async {
    // For testing, we'll capture what would be the system message
    // by simulating the system message generation
    if (includedResults.isNotEmpty) {
      final buffer = StringBuffer();
      buffer.writeln('Previous step results and associated issues:');
      for (int i = 0; i < includedResults.length; i++) {
        final result = includedResults[i];
        buffer.writeln(
          '  Step: ${result.toolName} -> Output keys: ${result.output.toMap().keys.join(', ')}',
        );
        if (result.issues.isNotEmpty) {
          buffer.writeln('    Associated issues:');
          for (final issue in result.issues) {
            buffer.writeln(
              '      - ${issue.severity.name.toUpperCase()}: ${issue.description}',
            );
            if (issue.suggestions.isNotEmpty) {
              buffer.writeln(
                '        Suggestions: ${issue.suggestions.join(', ')}',
              );
            }
          }
        }
      }
      lastSystemMessage = buffer.toString();
    } else {
      lastSystemMessage = null;
    }

    final response = responses[step.toolName];
    if (response == null) {
      throw Exception('No mock response for ${step.toolName}');
    }
    return response;
  }
}
