import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';

void main() {
  group('Round 18 Features', () {
    group('Token Usage Tracking', () {
      test('should create TokenUsage with required fields', () {
        final tokenUsage = TokenUsage(
          promptTokens: 100,
          completionTokens: 50,
          totalTokens: 150,
        );

        expect(tokenUsage.promptTokens, equals(100));
        expect(tokenUsage.completionTokens, equals(50));
        expect(tokenUsage.totalTokens, equals(150));
      });

      test('should create zero TokenUsage for initial input', () {
        final tokenUsage = TokenUsage.zero();

        expect(tokenUsage.promptTokens, equals(0));
        expect(tokenUsage.completionTokens, equals(0));
        expect(tokenUsage.totalTokens, equals(0));
      });

      test('should create TokenUsage from map', () {
        final map = {
          'prompt_tokens': 75,
          'completion_tokens': 25,
          'total_tokens': 100,
        };

        final tokenUsage = TokenUsage.fromMap(map);

        expect(tokenUsage.promptTokens, equals(75));
        expect(tokenUsage.completionTokens, equals(25));
        expect(tokenUsage.totalTokens, equals(100));
      });

      test('should handle missing fields in fromMap with defaults', () {
        final map = {
          'prompt_tokens': 50,
          // missing completion_tokens and total_tokens
        };

        final tokenUsage = TokenUsage.fromMap(map);

        expect(tokenUsage.promptTokens, equals(50));
        expect(tokenUsage.completionTokens, equals(0));
        expect(tokenUsage.totalTokens, equals(50)); // calculated
      });
    });

    group('TypedToolResult with Token Usage', () {
      test('should include token usage in TypedToolResult', () {
        final tokenUsage = TokenUsage(
          promptTokens: 100,
          completionTokens: 50,
          totalTokens: 150,
        );

        final result = ToolResult<ToolOutput>(
          toolName: 'test_tool',
          input: ToolInput(
            round: 0,
            customData: {},
            model: 'gpt-4',
            temperature: 0.7,
            maxTokens: 1000,
          ),
          output: ToolOutput({}, round: 0),
          auditResults: const AuditResults(issues: [], passesCriteria: true),
        );

        final typedResult = TypedToolResult.fromWithType(
          result: result,
          outputType: ToolOutput,
          tokenUsage: tokenUsage,
        );

        expect(typedResult.tokenUsage, equals(tokenUsage));
        expect(typedResult.tokenUsage.promptTokens, equals(100));
        expect(typedResult.tokenUsage.completionTokens, equals(50));
        expect(typedResult.tokenUsage.totalTokens, equals(150));
      });

      test('should use zero token usage when not provided', () {
        final result = ToolResult<ToolOutput>(
          toolName: 'test_tool',
          input: ToolInput(
            round: 0,
            customData: {},
            model: 'gpt-4',
            temperature: 0.7,
            maxTokens: 1000,
          ),
          output: ToolOutput({}, round: 0),
          auditResults: const AuditResults(issues: [], passesCriteria: true),
        );

        final typedResult = TypedToolResult.fromWithType(
          result: result,
          outputType: ToolOutput,
        );

        expect(typedResult.tokenUsage.promptTokens, equals(0));
        expect(typedResult.tokenUsage.completionTokens, equals(0));
        expect(typedResult.tokenUsage.totalTokens, equals(0));
      });
    });

    group('ToolFlowResult Structure', () {
      test('should return nested List<List<TypedToolResult>> structure', () {
        // Create a simple mock result structure
        final typedResults = [
          [
            TypedToolResult.fromWithType(
              result: ToolResult<ToolOutput>(
                toolName: 'initial_input',
                input: ToolInput(
                  round: 0,
                  customData: {'initial': 'data'},
                  model: 'gpt-4',
                  temperature: 0.7,
                  maxTokens: 1000,
                ),
                output: ToolOutput({'initial': 'data'}, round: 0),
                auditResults: const AuditResults(
                  issues: [],
                  passesCriteria: true,
                ),
              ),
              outputType: ToolOutput,
            ),
          ],
          [
            TypedToolResult.fromWithType(
              result: ToolResult<ToolOutput>(
                toolName: 'test_tool',
                input: ToolInput(
                  round: 0,
                  customData: {'input': 'test'},
                  model: 'gpt-4',
                  temperature: 0.7,
                  maxTokens: 1000,
                ),
                output: ToolOutput({'result': 'success'}, round: 0),

                auditResults: const AuditResults(
                  issues: [],
                  passesCriteria: true,
                ),
              ),
              outputType: ToolOutput,
            ),
          ],
        ];

        final result = ToolFlowResult.fromTypedResults(
          typedResults: typedResults,
          finalState: {},
        );

        expect(result.results, isA<List<List<TypedToolResult>>>());
        expect(result.results.length, equals(2)); // Initial input + 1 step
        expect(
          result.results[0].length,
          equals(1),
        ); // Initial input (single attempt)
        expect(result.results[1].length, equals(1)); // Step 1 (single attempt)
      });

      test('should compute allIssues from results', () {
        final typedResults = [
          [
            TypedToolResult.fromWithType(
              result: ToolResult<ToolOutput>(
                toolName: 'initial_input',
                input: ToolInput(
                  round: 0,
                  customData: {},
                  model: 'gpt-4',
                  temperature: 0.7,
                  maxTokens: 1000,
                ),
                output: ToolOutput({}, round: 0),
                auditResults: const AuditResults(
                  issues: [],
                  passesCriteria: true,
                ),
              ),
              outputType: ToolOutput,
            ),
          ],
          [
            TypedToolResult.fromWithType(
              result: ToolResult<ToolOutput>(
                toolName: 'test_tool',
                input: ToolInput(
                  round: 0,
                  customData: {},
                  model: 'gpt-4',
                  temperature: 0.7,
                  maxTokens: 1000,
                ),
                output: ToolOutput({}, round: 0),
                auditResults: AuditResults(
                  issues: [
                    Issue(
                      id: 'test-issue',
                      severity: IssueSeverity.medium,
                      description: 'Test issue',
                      context: {},
                      suggestions: [],
                    ),
                  ],

                  passesCriteria: false,
                ),
              ),
              outputType: ToolOutput,
            ),
          ],
        ];

        final result = ToolFlowResult.fromTypedResults(
          typedResults: typedResults,
          finalState: {},
        );

        expect(result.allIssues.length, equals(1));
        expect(result.allIssues.first.description, equals('Test issue'));
      });

      test('should provide finalResults convenience getter', () {
        final typedResults = [
          [
            TypedToolResult.fromWithType(
              result: ToolResult<ToolOutput>(
                toolName: 'initial_input',
                input: ToolInput(
                  round: 0,
                  customData: {},
                  model: 'gpt-4',
                  temperature: 0.7,
                  maxTokens: 1000,
                ),
                output: ToolOutput({}, round: 0),
                auditResults: const AuditResults(
                  issues: [],
                  passesCriteria: true,
                ),
              ),
              outputType: ToolOutput,
            ),
          ],
          [
            TypedToolResult.fromWithType(
              result: ToolResult<ToolOutput>(
                toolName: 'step_1_attempt_1',
                input: ToolInput(
                  round: 0,
                  customData: {},
                  model: 'gpt-4',
                  temperature: 0.7,
                  maxTokens: 1000,
                ),
                output: ToolOutput({}, round: 0),
                auditResults: const AuditResults(
                  issues: [],
                  passesCriteria: true,
                ),
              ),
              outputType: ToolOutput,
            ),
            TypedToolResult.fromWithType(
              result: ToolResult<ToolOutput>(
                toolName: 'step_1_attempt_2',
                input: ToolInput(
                  round: 1,
                  customData: {},
                  model: 'gpt-4',
                  temperature: 0.7,
                  maxTokens: 1000,
                ),
                output: ToolOutput({}, round: 1),
                auditResults: const AuditResults(
                  issues: [],
                  passesCriteria: true,
                ),
              ),
              outputType: ToolOutput,
            ),
          ],
        ];

        final result = ToolFlowResult.fromTypedResults(
          typedResults: typedResults,
          finalState: {},
        );

        expect(result.finalResults.length, equals(2));
        expect(result.finalResults[0].toolName, equals('initial_input'));
        expect(
          result.finalResults[1].toolName,
          equals('step_1_attempt_2'),
        ); // Final attempt
      });
    });
  });
}
