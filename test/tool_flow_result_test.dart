/// Tests for ToolFlowResult class functionality
library;

import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';

class TestOutput extends ToolOutput {
  final String message;

  const TestOutput(this.message, {required super.round}) : super.subclass();

  factory TestOutput.fromMap(Map<String, dynamic> map, int round) {
    return TestOutput(map['message'] as String, round: round);
  }

  @override
  Map<String, dynamic> toMap() => {'_round': round, 'message': message};
}

/// Mock service for testing
class MockOpenAiToolService implements OpenAiToolService {
  final Map<String, Map<String, dynamic>> responses;

  MockOpenAiToolService({required this.responses});

  @override
  Future<ToolCallResponse> executeToolCall(
    ToolCallStep step,
    ToolInput input, {
    List<ToolResult> includedResults = const [],
  }) async {
    final response = responses[step.toolName];
    if (response == null) {
      throw Exception('No mock response for ${step.toolName}');
    }
    return ToolCallResponse(
      output: response,
      usage: {
        'prompt_tokens': 100,
        'completion_tokens': 50,
        'total_tokens': 150,
      },
    );
  }
}

void main() {
  group('ToolFlowResult', () {
    group('results getter', () {
      test('should return List<TypedToolResult>', () {
        // Register test output
        ToolOutputRegistry.register(
          'test_tool_results',
          (data, round) => TestOutput.fromMap(data, round),
        );

        final mockService = MockOpenAiToolService(
          responses: {
            'test_tool_results': {'message': 'response'},
          },
        );

        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test', baseUrl: 'http://localhost'),
          steps: [
            ToolCallStep(
              toolName: 'test_tool_results',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'input': 'test'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
            ),
          ],
          openAiService: mockService,
        );

        return flow.run(input: {'test': 'data'}).then((result) {
          expect(result.results, isA<List<TypedToolResult>>());
          expect(result.results.length, equals(2)); // initial input + 1 tool step
          expect(result.results[1], isA<TypedToolResult>()); // Second result is the tool step
          expect(result.results[1].toolName, equals('test_tool_results'));
        });
      });
    });

    group('typed result methods', () {
      test('should support getTypedResultByToolName', () {
        // Register test output
        ToolOutputRegistry.register(
          'typed_result_test',
          (data, round) => TestOutput.fromMap(data, round),
        );

        final mockService = MockOpenAiToolService(
          responses: {
            'typed_result_test': {'message': 'typed response'},
          },
        );

        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test', baseUrl: 'http://localhost'),
          steps: [
            ToolCallStep(
              toolName: 'typed_result_test',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'input': 'test'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
            ),
          ],
          openAiService: mockService,
        );

        return flow.run(input: {'test': 'data'}).then((result) {
          final typedResult = result.getTypedResultByToolName(
            'typed_result_test',
          );
          expect(typedResult, isNotNull);
          expect(typedResult!.toolName, equals('typed_result_test'));
          expect(typedResult.output, isA<TestOutput>());

          final testOutput = typedResult.output as TestOutput;
          expect(testOutput.message, equals('typed response'));
        });
      });

      test('should support getAllTypedResultsByToolName', () {
        // Register test output
        ToolOutputRegistry.register(
          'multiple_typed_test',
          (data, round) => TestOutput.fromMap(data, round),
        );

        final mockService = MockOpenAiToolService(
          responses: {
            'multiple_typed_test': {'message': 'response'},
          },
        );

        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test', baseUrl: 'http://localhost'),
          steps: [
            ToolCallStep(
              toolName: 'multiple_typed_test',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'input': 'test1'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
            ),
            ToolCallStep(
              toolName: 'multiple_typed_test', // Same tool name
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'input': 'test2'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
            ),
          ],
          openAiService: mockService,
        );

        return flow.run(input: {'test': 'data'}).then((result) {
          final allTypedResults = result.getAllTypedResultsByToolName(
            'multiple_typed_test',
          );
          expect(allTypedResults.length, equals(2));

          expect(allTypedResults[0].toolName, equals('multiple_typed_test'));
          expect(allTypedResults[1].toolName, equals('multiple_typed_test'));

          // Verify they are different step results
          expect(allTypedResults[0].input.toMap()['input'], equals('test1'));
          expect(allTypedResults[1].input.toMap()['input'], equals('test2'));
        });
      });
    });

    group('results compatibility', () {
      test('should maintain backward compatibility with existing methods', () {
        // Register test output
        ToolOutputRegistry.register(
          'compat_test',
          (data, round) => TestOutput.fromMap(data, round),
        );

        final mockService = MockOpenAiToolService(
          responses: {
            'compat_test': {'message': 'compat response'},
          },
        );

        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test', baseUrl: 'http://localhost'),
          steps: [
            ToolCallStep(
              toolName: 'compat_test',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'input': 'test'},
              outputSchema: OutputSchema(properties: []),
              stepConfig: StepConfig(),
            ),
          ],
          openAiService: mockService,
        );

        return flow.run(input: {'test': 'data'}).then((result) {
          // Test that existing methods still work
          final resultByName = result.getResultByToolName('compat_test');
          expect(resultByName, isNotNull);
          expect(resultByName!.toolName, equals('compat_test'));

          final allResults = result.getAllResultsByToolName('compat_test');
          expect(allResults.length, equals(1));
          expect(allResults.first.toolName, equals('compat_test'));

          final resultsByNames = result.getResultsByToolNames(['compat_test']);
          expect(resultsByNames.length, equals(1));
          expect(resultsByNames.first.toolName, equals('compat_test'));
        });
      });
    });
  });
}
