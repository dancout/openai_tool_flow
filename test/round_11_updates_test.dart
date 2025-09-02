/// Tests for Round 11 updates: non-optional ToolOutputRegistry, round param, TypedToolResult results
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

// TODO: These tests should exist closer to their actual test files. Round 11 updates test is weird...
void main() {
  group('Round 11 Updates', () {
    tearDown(() {
      // Note: Cannot clear registry as fields are private
      // Tests will register unique tool names to avoid conflicts
    });

    group('ToolOutputRegistry.create', () {
      test('should throw when no creator is registered', () {
        expect(
          () => ToolOutputRegistry.create(
            toolName: 'unregistered_tool',
            data: {'test': 'data'},
            round: 0,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                'No typed output creator registered for tool: unregistered_tool',
              ),
            ),
          ),
        );
      });

      test('should return ToolOutput when creator is registered', () {
        ToolOutputRegistry.register(
          'test_tool_create',
          (data, round) => TestOutput.fromMap(data, round),
        );

        final result = ToolOutputRegistry.create(
          toolName: 'test_tool_create',
          data: {'message': 'hello'},
          round: 2,
        );

        expect(result, isA<TestOutput>());
        expect((result as TestOutput).message, equals('hello'));
        expect(result.round, equals(2));
      });
    });

    group('ToolOutputRegistry.getOutputType', () {
      test('should throw when no output type is registered', () {
        expect(
          () => ToolOutputRegistry.getOutputType('unregistered_tool'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('No output type registered for tool: unregistered_tool'),
            ),
          ),
        );
      });

      test('should return Type when output type is registered', () {
        ToolOutputRegistry.register(
          'test_tool_type',
          (data, round) => TestOutput.fromMap(data, round),
        );

        final result = ToolOutputRegistry.getOutputType('test_tool_type');
        expect(result, equals(TestOutput));
      });
    });

    group('ToolOutput round parameter', () {
      test('should require round parameter in constructor', () {
        const output = TestOutput('test message', round: 5);
        expect(output.round, equals(5));
        expect(output.message, equals('test message'));
      });

      test('should include round in toMap output', () {
        const output = TestOutput('test message', round: 3);
        final map = output.toMap();

        expect(map['_round'], equals(3));
        expect(map['message'], equals('test message'));
      });

      test('should handle round in fromMap factory', () {
        final output = TestOutput.fromMap({'message': 'from map'}, 7);

        expect(output.round, equals(7));
        expect(output.message, equals('from map'));
      });
    });

    group('ToolFlowResult.results getter', () {
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
          config: OpenAIConfig(apiKey: 'test'),
          steps: [
            ToolCallStep(
              toolName: 'test_tool_results',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'input': 'test'},
              stepConfig: StepConfig(
                outputSchema: OutputSchema(properties: [], required: []),
              ),
            ),
          ],
          openAiService: mockService,
        );

        return flow.run().then((result) {
          expect(result.results, isA<List<TypedToolResult>>());
          expect(result.results.length, equals(1));
          expect(result.results.first, isA<TypedToolResult>());
          expect(result.results.first.toolName, equals('test_tool_results'));
        });
      });
    });

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

        // Helper function (same as in usage.dart)
        List<Issue> issuesWithSeverity(
          List<Issue> allIssues,
          IssueSeverity severity,
        ) {
          return allIssues
              .where((issue) => issue.severity == severity)
              .toList();
        }

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
    });

    group('Integration tests', () {
      test('should work end-to-end with new APIs', () {
        // Register test output
        ToolOutputRegistry.register(
          'integration_tool_e2e',
          (data, round) => TestOutput.fromMap(data, round),
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
              stepConfig: StepConfig(
                outputSchema: OutputSchema(properties: [], required: []),
              ),
            ),
          ],
          openAiService: mockService,
        );

        return flow.run().then((result) {
          // Test new results type
          expect(result.results, isA<List<TypedToolResult>>());
          final typedResult = result.results.first;

          // Test round information is preserved
          expect(typedResult.output, isA<TestOutput>());
          final testOutput = typedResult.output as TestOutput;
          expect(testOutput.round, equals(0)); // First attempt
          expect(testOutput.message, equals('integration test success'));

          // Test tool name retrieval still works
          final resultByName = result.getTypedResultByToolName(
            'integration_tool_e2e',
          );
          expect(resultByName, isNotNull);
          expect(resultByName!.toolName, equals('integration_tool_e2e'));
        });
      });
    });
  });
}

/// Mock service for testing
class MockOpenAiToolService implements OpenAiToolService {
  final Map<String, Map<String, dynamic>> responses;

  MockOpenAiToolService({required this.responses});

  @override
  Future<Map<String, dynamic>> executeToolCall(
    ToolCallStep step,
    ToolInput input,
  ) async {
    final response = responses[step.toolName];
    if (response == null) {
      throw Exception('No mock response for ${step.toolName}');
    }
    return response;
  }
}
