import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';

void main() {
  group('Round 16 Features', () {
    late MockOpenAiToolService mockService;

    setUp(() {
      mockService = MockOpenAiToolService();

      // Register test outputs for all tool names used in tests
      final toolNames = [
        'input_passthrough_test',
        'token_tracking_test',
        'index_based_test',
        'step_one',
        'step_two',
        'test_step',
        'token_test',
        'model_test',
        'usage_tracking_test',
        'response_test',
        'step1',
        'step2',
        'step3',
      ];

      for (final toolName in toolNames) {
        ToolOutputRegistry.register<ToolOutput>(
          toolName,
          (map, round) => ToolOutput.fromMap(map, round: round),
        );
      }
    });

    group('Optional InputBuilder with Smart Defaults', () {
      test(
        'should use previous step output when inputBuilder is not provided',
        () async {
          // Setup mock to return predictable output for first step
          mockService.addResponse(
            'step_one',
            ToolCallResponse(
              output: {'output': 'first_step_result', 'data': 'processed'},
              usage: {
                'prompt_tokens': 10,
                'completion_tokens': 20,
                'total_tokens': 30,
              },
            ),
          );

          // Second step should get first step's output automatically
          mockService.addResponse(
            'step_two',
            ToolCallResponse(
              output: {
                'output': 'second_step_result',
                'used_input': 'from_first',
              },
              usage: {
                'prompt_tokens': 10,
                'completion_tokens': 20,
                'total_tokens': 30,
              },
            ),
          );

          final flow = ToolFlow(
            config: OpenAIConfig(apiKey: 'test', baseUrl: 'http://localhost'),
            steps: [
              ToolCallStep(
                toolName: 'step_one',
                inputBuilder: (results) => {'process': 'initial_data'},
                outputSchema: OutputSchema(properties: []),
                stepConfig: StepConfig(),
              ),
              ToolCallStep(
                toolName: 'step_two',
                // No inputBuilder provided - should use previous step's output
                outputSchema: OutputSchema(properties: []),
                stepConfig: StepConfig(),
              ),
            ],
            openAiService: mockService,
          );

          final result = await flow.run(input: {'initial': 'data'});

          expect(result.results.length, equals(3)); // initial + 2 steps

          // Verify that the second step received the first step's output as input
          final secondStepInput = mockService.getCapturedInput('step_two');
          expect(secondStepInput, isNotNull);
          expect(
            secondStepInput!.toMap()['output'],
            equals('first_step_result'),
          );
          expect(secondStepInput.toMap()['data'], equals('processed'));
        },
      );

      test(
        'should prefer explicit inputBuilder over default behavior',
        () async {
          mockService.addResponse(
            'step_one',
            ToolCallResponse(
              output: {'output': 'first_step_result'},
              usage: {
                'prompt_tokens': 10,
                'completion_tokens': 20,
                'total_tokens': 30,
              },
            ),
          );

          mockService.addResponse(
            'step_two',
            ToolCallResponse(
              output: {'output': 'second_step_result'},
              usage: {
                'prompt_tokens': 10,
                'completion_tokens': 20,
                'total_tokens': 30,
              },
            ),
          );

          final flow = ToolFlow(
            config: OpenAIConfig(apiKey: 'test', baseUrl: 'http://localhost'),
            steps: [
              ToolCallStep(
                toolName: 'step_one',
                inputBuilder: (results) => {'process': 'initial_data'},
                outputSchema: OutputSchema(properties: []),
                stepConfig: StepConfig(),
              ),
              ToolCallStep(
                toolName: 'step_two',
                inputBuilder: (results) => {'custom': 'explicit_input'},
                outputSchema: OutputSchema(properties: []),
                stepConfig: StepConfig(),
              ),
            ],
            openAiService: mockService,
          );

          await flow.run(input: {'initial': 'data'});

          // Verify that the explicit inputBuilder was used
          final secondStepInput = mockService.getCapturedInput('step_two');
          expect(secondStepInput, isNotNull);
          expect(secondStepInput!.toMap()['custom'], equals('explicit_input'));
          expect(secondStepInput.toMap().containsKey('output'), isFalse);
        },
      );
    });

    group('Required Input Parameter', () {
      test(
        'should create initial TypedToolResult from input at index 0',
        () async {
          mockService.addResponse(
            'test_step',
            ToolCallResponse(
              output: {'output': 'step_result'},
              usage: {
                'prompt_tokens': 10,
                'completion_tokens': 20,
                'total_tokens': 30,
              },
            ),
          );

          final flow = ToolFlow(
            config: OpenAIConfig(apiKey: 'test', baseUrl: 'http://localhost'),
            steps: [
              ToolCallStep(
                toolName: 'test_step',
                inputBuilder: (results) => {
                  'initial_round': results[0].output.toMap()['_round'],
                  'initial_data': results[0].output.toMap()['test_input'],
                },
                outputSchema: OutputSchema(properties: []),
                stepConfig: StepConfig(),
              ),
            ],
            openAiService: mockService,
          );

          final result = await flow.run(input: {'test_input': 'initial_value'});

          // Verify initial result is at index 0
          expect(result.finalResults[0].toolName, equals('initial_input'));
          expect(
            result.finalResults[0].output.toMap()['test_input'],
            equals('initial_value'),
          );
          expect(result.finalResults[0].output.toMap()['_round'], equals(0));

          // Verify the step could access the initial input
          final stepInput = mockService.getCapturedInput('test_step');
          expect(stepInput!.toMap()['initial_round'], equals(0));
          expect(stepInput.toMap()['initial_data'], equals('initial_value'));
        },
      );
    });

    group('Index-Based Result References', () {
      test('should support integer-only includeResultsInToolcall', () async {
        mockService.addResponse(
          'step_one',
          ToolCallResponse(
            output: {'step1': 'result'},
            usage: {
              'prompt_tokens': 10,
              'completion_tokens': 20,
              'total_tokens': 30,
            },
          ),
        );

        mockService.addResponse(
          'step_two',
          ToolCallResponse(
            output: {'step2': 'result'},
            usage: {
              'prompt_tokens': 10,
              'completion_tokens': 20,
              'total_tokens': 30,
            },
          ),
        );

        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test', baseUrl: 'http://localhost'),
          steps: [
            ToolCallStep(
              toolName: 'step_one',
              inputBuilder: (results) => {'data': 'first'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
            ),
            ToolCallStep(
              toolName: 'step_two',
              inputBuilder: (results) => {'data': 'second'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
              includeResultsInToolcall: [
                0,
                1,
              ], // Include initial input and first step
            ),
          ],
          openAiService: mockService,
        );

        await flow.run(input: {'initial': 'test'});

        // Verify that the step configuration was captured correctly
        // (The actual inclusion depends on whether results have issues)
        final includedResults = mockService.getCapturedIncludedResults(
          'step_two',
        );
        expect(includedResults, isNotNull);
        // Since our test results don't have issues, nothing will be included
        expect(includedResults!.length, equals(0));

        // But verify that the includeResultsInToolcall was set correctly
        final capturedStep = mockService.getCapturedStep('step_two');
        expect(capturedStep!.includeResultsInToolcall, equals([0, 1]));
      });

      test('should handle empty includeResultsInToolcall', () async {
        mockService.addResponse(
          'test_step',
          ToolCallResponse(
            output: {'output': 'result'},
            usage: {
              'prompt_tokens': 10,
              'completion_tokens': 20,
              'total_tokens': 30,
            },
          ),
        );

        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test', baseUrl: 'http://localhost'),
          steps: [
            ToolCallStep(
              toolName: 'test_step',
              inputBuilder: (results) => {'data': 'test'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
              includeResultsInToolcall: [], // No results included
            ),
          ],
          openAiService: mockService,
        );

        await flow.run(input: {'initial': 'test'});

        final includedResults = mockService.getCapturedIncludedResults(
          'test_step',
        );
        expect(includedResults, isNotNull);
        expect(includedResults!.length, equals(0));
      });
    });

    group('Enhanced Token Management', () {
      test('should support per-step maxTokens in StepConfig', () async {
        mockService.addResponse(
          'token_test',
          ToolCallResponse(
            output: {'output': 'result'},
            usage: {
              'prompt_tokens': 10,
              'completion_tokens': 20,
              'total_tokens': 30,
            },
          ),
        );

        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test', baseUrl: 'http://localhost'),
          steps: [
            ToolCallStep(
              toolName: 'token_test',
              inputBuilder: (results) => {'data': 'test'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(maxTokens: 500),
            ),
          ],
          openAiService: mockService,
        );

        await flow.run(input: {'initial': 'test'});

        // Verify that maxTokens was captured by the service
        final capturedStep = mockService.getCapturedStep('token_test');
        expect(capturedStep, isNotNull);
        expect(capturedStep!.stepConfig.maxTokens, equals(500));
      });

      test('should support optional model field with fallback', () async {
        mockService.addResponse(
          'model_test',
          ToolCallResponse(
            output: {'output': 'result'},
            usage: {
              'prompt_tokens': 10,
              'completion_tokens': 20,
              'total_tokens': 30,
            },
          ),
        );

        final flow = ToolFlow(
          config: OpenAIConfig(
            apiKey: 'test',
            baseUrl: 'http://localhost',
            defaultModel: 'default-model',
          ),
          steps: [
            ToolCallStep(
              toolName: 'model_test',
              // No model specified - should use config default
              inputBuilder: (results) => {'data': 'test'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
            ),
          ],
          openAiService: mockService,
        );

        await flow.run(input: {'initial': 'test'});

        final capturedStep = mockService.getCapturedStep('model_test');
        expect(capturedStep, isNotNull);
        // The service should have used the default model from config
        expect(
          capturedStep!.model,
          isNull,
        ); // Step model is null, falls back to config
      });

      test('should track token usage in ToolFlow state', () async {
        mockService.addResponse(
          'usage_tracking_test',
          ToolCallResponse(
            output: {'output': 'result'},
            usage: {
              'prompt_tokens': 10,
              'completion_tokens': 20,
              'total_tokens': 30,
            },
          ),
        );

        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test', baseUrl: 'http://localhost'),
          steps: [
            ToolCallStep(
              toolName: 'usage_tracking_test',
              inputBuilder: (results) => {'data': 'test'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
            ),
          ],
          openAiService: mockService,
        );

        final result = await flow.run(input: {'initial': 'test'});

        // Verify token usage is tracked in final state
        expect(result.finalState.containsKey('token_usage'), isTrue);
        final tokenUsage = result.finalState['token_usage'];
        expect(tokenUsage, isNotNull);
        expect(tokenUsage['total_prompt_tokens'], equals(10));
        expect(tokenUsage['total_completion_tokens'], equals(20));
        expect(tokenUsage['total_tokens'], equals(30));
      });
    });

    group('Service Interface Enhancement', () {
      test('should return ToolCallResponse with usage information', () async {
        final expectedUsage = {
          'prompt_tokens': 10,
          'completion_tokens': 20,
          'total_tokens': 30,
        };
        mockService.addResponse(
          'response_test',
          ToolCallResponse(
            output: {'output': 'test_result'},
            usage: expectedUsage,
          ),
        );

        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test', baseUrl: 'http://localhost'),
          steps: [
            ToolCallStep(
              toolName: 'response_test',
              inputBuilder: (results) => {'data': 'test'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
            ),
          ],
          openAiService: mockService,
        );

        final result = await flow.run(input: {'initial': 'test'});

        // Verify the service was called and returned the expected response
        expect(result.results.length, equals(2));
        expect(
          result.finalResults[1].output.toMap()['output'],
          equals('test_result'),
        );

        // Verify usage tracking worked
        final finalUsage = result.finalState['token_usage'];
        expect(finalUsage['total_prompt_tokens'], equals(10));
        expect(finalUsage['total_completion_tokens'], equals(20));
        expect(finalUsage['total_tokens'], equals(30));
      });
    });

    group('All Previous Results Access', () {
      test('should pass all previous results to inputBuilder', () async {
        mockService.addResponse(
          'step1',
          ToolCallResponse(
            output: {'step1': 'output1'},
            usage: {
              'prompt_tokens': 10,
              'completion_tokens': 20,
              'total_tokens': 30,
            },
          ),
        );
        mockService.addResponse(
          'step2',
          ToolCallResponse(
            output: {'step2': 'output2'},
            usage: {
              'prompt_tokens': 10,
              'completion_tokens': 20,
              'total_tokens': 30,
            },
          ),
        );
        mockService.addResponse(
          'step3',
          ToolCallResponse(
            output: {'step3': 'output3'},
            usage: {
              'prompt_tokens': 10,
              'completion_tokens': 20,
              'total_tokens': 30,
            },
          ),
        );

        List<TypedToolResult>? capturedResults;

        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test', baseUrl: 'http://localhost'),
          steps: [
            ToolCallStep(
              toolName: 'step1',
              inputBuilder: (results) => {'data': 'first'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
            ),
            ToolCallStep(
              toolName: 'step2',
              inputBuilder: (results) => {'data': 'second'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
            ),
            ToolCallStep(
              toolName: 'step3',
              inputBuilder: (results) {
                capturedResults = List.from(results); // Capture all results
                return {'data': 'third'};
              },
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
            ),
          ],
          openAiService: mockService,
        );

        await flow.run(input: {'initial': 'test'});

        // Verify that step3 inputBuilder received all previous results
        expect(capturedResults, isNotNull);
        expect(capturedResults!.length, equals(3)); // initial + step1 + step2
        expect(capturedResults![0].toolName, equals('initial_input'));
        expect(capturedResults![1].toolName, equals('step1'));
        expect(capturedResults![2].toolName, equals('step2'));
      });
    });
  });
}

/// Mock service with enhanced capabilities for testing Round 16 features
class MockOpenAiToolService implements OpenAiToolService {
  final Map<String, ToolCallResponse> _responses = {};
  final Map<String, ToolInput> _capturedInputs = {};
  final Map<String, List<ToolResult>> _capturedIncludedResults = {};
  final Map<String, ToolCallStep> _capturedSteps = {};

  void addResponse(String toolName, ToolCallResponse response) {
    _responses[toolName] = response;
  }

  ToolInput? getCapturedInput(String toolName) => _capturedInputs[toolName];
  List<ToolResult>? getCapturedIncludedResults(String toolName) =>
      _capturedIncludedResults[toolName];
  ToolCallStep? getCapturedStep(String toolName) => _capturedSteps[toolName];

  @override
  Future<ToolCallResponse> executeToolCall(
    ToolCallStep step,
    ToolInput input, {
    List<ToolResult> includedResults = const [],
    List<ToolResult> currentStepRetries = const [],
  }) async {
    // Capture inputs and included results for verification
    _capturedInputs[step.toolName] = input;
    _capturedIncludedResults[step.toolName] = List.from(includedResults);
    _capturedSteps[step.toolName] = step;

    final response = _responses[step.toolName];
    if (response == null) {
      throw Exception('No mock response configured for tool: ${step.toolName}');
    }

    return response;
  }
}
