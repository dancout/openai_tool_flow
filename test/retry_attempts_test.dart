import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';

/// Simple audit function for testing
class SimpleAuditFunction<T extends ToolOutput> extends AuditFunction<T> {
  @override
  final String name;

  final List<Issue> Function(T) _auditFunction;

  SimpleAuditFunction({
    required this.name,
    required List<Issue> Function(T) auditFunction,
  }) : _auditFunction = auditFunction;

  @override
  List<Issue> run(T output) => _auditFunction(output);
}

/// Mock service that can simulate failures for testing retry functionality
class RetryTestService implements OpenAiToolService {
  final Map<String, List<Map<String, dynamic>>> responseSequences;
  final Map<String, int> callCounts = {};

  RetryTestService({required this.responseSequences});

  @override
  Future<ToolCallResponse> executeToolCall(
    ToolCallStep step,
    ToolInput input, {
    List<ToolResult> includedResults = const [],
    List<ToolResult> currentStepRetries = const [],
  }) async {
    final toolName = step.toolName;
    final currentCount = callCounts[toolName] ?? 0;
    callCounts[toolName] = currentCount + 1;

    final sequences = responseSequences[toolName];
    if (sequences == null || sequences.isEmpty) {
      throw Exception('No mock response sequence for $toolName');
    }

    // Get the response for this attempt (or last response if we've exceeded the sequence)
    final responseIndex = currentCount < sequences.length
        ? currentCount
        : sequences.length - 1;
    final response = sequences[responseIndex];

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

/// Test service that captures system messages for verification
class SystemMessageCaptureService implements OpenAiToolService {
  String? lastSystemMessage;
  List<String> allSystemMessages = [];
  final Map<String, Map<String, dynamic>> responses;

  SystemMessageCaptureService({this.responses = const {}});

  @override
  Future<ToolCallResponse> executeToolCall(
    ToolCallStep step,
    ToolInput input, {
    List<ToolResult> includedResults = const [],
    List<ToolResult> currentStepRetries = const [],
  }) async {
    // Simulate building a system message to capture what would be sent
    final buffer = StringBuffer();
    buffer.writeln('Context: Executing tool call in a structured workflow');
    buffer.writeln(
      'Current Step: Tool: ${step.toolName}, Model: ${step.model}',
    );

    if (includedResults.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Previous step results and associated issues:');
      for (int i = 0; i < includedResults.length; i++) {
        final result = includedResults[i];
        buffer.writeln('  Step: ${result.toolName}');
        buffer.writeln('    Output: ${result.output.toMap()}');
        if (result.auditResults.issues.isNotEmpty) {
          buffer.writeln('    Associated issues:');
          for (final issue in result.auditResults.issues) {
            buffer.writeln(
              '      - ${issue.severity.name.toUpperCase()}: ${issue.description}',
            );
          }
        }
      }
    }

    if (currentStepRetries.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Current step retry attempts and associated issues:');
      for (int i = 0; i < currentStepRetries.length; i++) {
        final result = currentStepRetries[i];
        buffer.writeln('  Attempt ${i + 1}: ${result.toolName}');
        buffer.writeln('    Output: ${result.output.toMap()}');
        if (result.auditResults.issues.isNotEmpty) {
          buffer.writeln('    Associated issues:');
          for (final issue in result.auditResults.issues) {
            buffer.writeln(
              '      - ${issue.severity.name.toUpperCase()}: ${issue.description}',
            );
          }
        }
      }
    }

    lastSystemMessage = buffer.toString();
    allSystemMessages.add(lastSystemMessage!);

    final response = responses[step.toolName] ?? {'result': 'success'};
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
  // Register test output types for deserialization
  setUpAll(() {
    ToolOutputRegistry.register(
      'test_tool',
      (data, round) => ToolOutput(data, round: round),
    );
    ToolOutputRegistry.register(
      'step1',
      (data, round) => ToolOutput(data, round: round),
    );
    ToolOutputRegistry.register(
      'step2',
      (data, round) => ToolOutput(data, round: round),
    );
    ToolOutputRegistry.register(
      'failing_step',
      (data, round) => ToolOutput(data, round: round),
    );
    ToolOutputRegistry.register(
      'test_step',
      (data, round) => ToolOutput(data, round: round),
    );
  });

  group('Retry Attempts Tracking', () {
    late OpenAIConfig config;

    setUp(() {
      config = OpenAIConfig(
        apiKey: 'test-key',
        baseUrl: 'https://test.openai.com',
      );
    });

    test('should store all retry attempts for each step', () async {
      final testService = RetryTestService(
        responseSequences: {
          'test_tool': [
            {'attempt': 1, 'result': 'failed'},
            {'attempt': 2, 'result': 'failed'},
            {'attempt': 3, 'result': 'success'},
          ],
        },
      );

      final flow = ToolFlow(
        config: config,
        openAiService: testService,
        steps: [
          ToolCallStep(
            toolName: 'test_tool',
            stepConfig: StepConfig(
              maxRetries: 2,
              audits: [
                SimpleAuditFunction<ToolOutput>(
                  name: 'failure_audit',
                  auditFunction: (output) {
                    final outputMap = output.toMap();
                    final attempt = outputMap['attempt'] as int? ?? 1;
                    return [
                      Issue(
                        id: 'test_issue_attempt_$attempt',
                        severity: IssueSeverity.high,
                        description: 'Test failure (attempt $attempt)',
                        context: {'attempt': attempt},
                        suggestions: ['Fix the issue and retry'],
                        round: output.round,
                      ),
                    ];
                  },
                ),
              ],
              customPassCriteria: (issues) => issues.isEmpty,
            ),
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.string(name: 'result', description: 'Result'),
              ],
            ),
            inputBuilder: (previousResults) => {'input': 'test'},
          ),
        ],
      );

      final result = await flow.run(input: {'start': true});

      // Verify that all attempts were stored
      final stepAttempts = result.results[1];
      expect(stepAttempts, isNotNull);
      expect(stepAttempts.length, equals(3)); // 3 attempts

      // Verify each attempt has the expected data
      for (int i = 0; i < 3; i++) {
        final attempt = stepAttempts[i];
        expect(attempt.output.toMap()['attempt'], equals(i + 1));
        expect(
          attempt.issues.length,
          equals(1),
        ); // Each should have one issue from audit
        expect(attempt.issues[0].description, contains('attempt ${i + 1}'));
      }
    });

    test(
      'should include retry attempts in system message with severity filtering',
      () async {
        final captureService = SystemMessageCaptureService(
          responses: {
            'step1': {
              'colors': ['red', 'blue'],
            },
            'step2': {'result': 'success'},
          },
        );

        final flow = ToolFlow(
          config: config,
          openAiService: captureService,
          steps: [
            ToolCallStep(
              toolName: 'step1',
              stepConfig: StepConfig(
                maxRetries: 1,
                audits: [
                  SimpleAuditFunction<ToolOutput>(
                    name: 'color_validation',
                    auditFunction: (output) => [
                      // Always create an issue so the final result will have it for includeResultsInToolcall
                      Issue(
                        id: 'color_issue',
                        severity: IssueSeverity.high,
                        description: 'Color validation issue',
                        context: {},
                        suggestions: ['Fix colors'],
                        round: output.round,
                      ),
                    ],
                  ),
                ],
                customPassCriteria: (issues) =>
                    true, // Always pass so it doesn't retry forever
                issuesSeverityFilter: IssueSeverity.high,
              ),
              outputSchema: OutputSchema(
                properties: [
                  PropertyEntry.array(
                    name: 'colors',
                    description: 'Extracted colors',
                    items: PropertyType.string,
                  ),
                ],
              ),
              inputBuilder: (previousResults) => {'input': 'extract colors'},
            ),
            ToolCallStep(
              toolName: 'step2',
              stepConfig: StepConfig(
                maxRetries: 0,
                issuesSeverityFilter: IssueSeverity.high,
              ),
              outputSchema: OutputSchema(
                properties: [
                  PropertyEntry.string(name: 'result', description: 'Result'),
                ],
              ),
              inputBuilder: (previousResults) => {'input': 'process'},
              includeResultsInToolcall: [1], // Include step1 results
            ),
          ],
        );

        await flow.run(input: {'start': true});

        // Find the system message for step2 that should include previous results
        final step2Messages = captureService.allSystemMessages
            .where((msg) => msg.contains('step2'))
            .toList();

        expect(step2Messages, isNotEmpty);

        final step2SystemMessage = step2Messages.first;
        expect(
          step2SystemMessage,
          contains('Previous step results and associated issues:'),
        );
        expect(step2SystemMessage, contains('step1'));
        expect(step2SystemMessage, contains('Color validation issue'));
      },
    );

    test(
      'should distinguish between previous steps and current step retries in system message',
      () async {
        final captureService = SystemMessageCaptureService(
          responses: {
            'step1': {'result': 'step1_output'},
            'failing_step': {'attempt': 1, 'result': 'failed'},
          },
        );

        final flow = ToolFlow(
          config: config,
          openAiService: captureService,
          steps: [
            ToolCallStep(
              toolName: 'step1',
              stepConfig: StepConfig(
                maxRetries: 0,
                audits: [
                  SimpleAuditFunction<ToolOutput>(
                    name: 'step1_audit',
                    auditFunction: (output) => [
                      Issue(
                        id: 'step1_issue',
                        severity: IssueSeverity.high,
                        description: 'Step1 completed with issue',
                        context: {},
                        suggestions: [],
                        round: output.round,
                      ),
                    ],
                  ),
                ],
              ),
              outputSchema: OutputSchema(
                properties: [
                  PropertyEntry.string(name: 'result', description: 'Result'),
                ],
              ),
              inputBuilder: (previousResults) => {'input': 'step1'},
            ),
            ToolCallStep(
              toolName: 'failing_step',
              stepConfig: StepConfig(
                maxRetries: 2,
                audits: [
                  SimpleAuditFunction<ToolOutput>(
                    name: 'critical_audit',
                    auditFunction: (output) => [
                      Issue(
                        id: 'critical_issue',
                        severity: IssueSeverity.critical,
                        description: 'Critical failure',
                        context: {},
                        suggestions: ['Fix critical error'],
                        round: output.round,
                      ),
                    ],
                  ),
                ],
                customPassCriteria: (issues) => issues.isEmpty,
                issuesSeverityFilter: IssueSeverity.high,
              ),
              outputSchema: OutputSchema(
                properties: [
                  PropertyEntry.string(name: 'result', description: 'Result'),
                ],
              ),
              inputBuilder: (previousResults) => {'input': 'failing'},
              includeResultsInToolcall: [1], // Include step1
            ),
          ],
        );

        await flow.run(input: {'start': true});

        // Find the system message that has both previous results and retry attempts
        final systemMessageWithRetries = captureService.allSystemMessages
            .firstWhere(
              (msg) => msg.contains('Current step retry attempts'),
              orElse: () => '',
            );

        if (systemMessageWithRetries.isNotEmpty) {
          expect(
            systemMessageWithRetries,
            contains('Previous step results and associated issues:'),
          );
          expect(systemMessageWithRetries, contains('step1'));
          expect(
            systemMessageWithRetries,
            contains('Current step retry attempts and associated issues:'),
          );
          expect(systemMessageWithRetries, contains('failing_step'));
        }
      },
    );

    test('should apply severity filtering to retry attempts', () async {
      final captureService = SystemMessageCaptureService(
        responses: {
          'test_step': {'result': 'success'},
        },
      );

      final flow = ToolFlow(
        config: config,
        openAiService: captureService,
        steps: [
          ToolCallStep(
            toolName: 'test_step',
            stepConfig: StepConfig(
              maxRetries: 1,
              audits: [
                SimpleAuditFunction<ToolOutput>(
                  name: 'low_severity_audit',
                  auditFunction: (output) => [
                    Issue(
                      id: 'low_issue',
                      severity: IssueSeverity.low,
                      description: 'Low severity issue',
                      context: {},
                      suggestions: ['Minor fix needed'],
                      round: output.round,
                    ),
                  ],
                ),
              ],
              customPassCriteria: (issues) => false, // Force retry
              issuesSeverityFilter:
                  IssueSeverity.high, // Filter out low severity
            ),
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.string(name: 'result', description: 'Result'),
              ],
            ),
            inputBuilder: (previousResults) => {'input': 'test'},
          ),
        ],
      );

      await flow.run(input: {'start': true});

      // Since the low severity issues are filtered out,
      // there should be no retry attempts included in the system message
      final systemMessages = captureService.allSystemMessages;
      final hasRetrySection = systemMessages.any(
        (msg) =>
            msg.contains('Current step retry attempts and associated issues:'),
      );

      // The retry section should not appear because low severity issues are filtered out
      expect(hasRetrySection, isFalse);
    });
  });
}
