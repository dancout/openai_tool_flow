import 'package:meta/meta.dart';

import 'issue.dart';
import 'openai_config.dart';
import 'openai_service.dart';
import 'openai_service_impl.dart';
import 'step_config.dart';
import 'tool_call_step.dart';
import 'tool_result.dart';
import 'typed_interfaces.dart';

/// Manages ordered execution of tool call steps with internal state management.
///
/// The ToolFlow orchestrator:
/// - Executes steps in order
/// - Manages internal state across steps
/// - Collects issues from audits
/// - Supports per-step audit configuration
/// - Implements retry logic with configurable attempts
/// - Provides structured results at the end
/// - Supports dependency injection for OpenAI service (for testing)
class ToolFlow {
  /// Configuration for OpenAI API access
  final OpenAIConfig config;

  /// Ordered list of tool call steps to execute
  final List<ToolCallStep> steps;

  /// OpenAI service for making tool calls (can be injected for testing)
  final OpenAiToolService openAiService;

  /// Internal state accumulated across steps
  final Map<String, dynamic> _state = {};

  /// Results from completed steps (ordered list)
  final List<ToolResult> _results = [];

  /// Results keyed by tool name for easy retrieval
  final Map<String, ToolResult> _resultsByToolName = {};

  /// Creates a ToolFlow with configuration and steps
  ToolFlow({
    required this.config,
    required this.steps,
    OpenAiToolService? openAiService,
  }) : openAiService = openAiService ?? DefaultOpenAiToolService(config: config);

  /// Executes the tool flow with the given input
  ///
  /// Returns a ToolFlowResult containing all step results and final state
  Future<ToolFlowResult> run({Map<String, dynamic> input = const {}}) async {
    _state.clear();
    _results.clear();
    _resultsByToolName.clear();
    _state.addAll(input);

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final stepConfig = step.stepConfig;

      ToolResult? stepResult;
      bool stepPassed = false;
      int attemptCount = 0;
      final maxRetries = stepConfig.getEffectiveMaxRetries(step.maxRetries);

      // Retry loop for this step
      while (attemptCount <= maxRetries && !stepPassed) {
        attemptCount++;

        try {
          // Execute the step
          stepResult = await _executeStep(step, i, attemptCount - 1);

          // Run audits if configured for this step
          if (stepConfig.hasAudits) {
            final shouldRunAudits =
                !stepConfig.auditOnlyFinalAttempt ||
                attemptCount > maxRetries ||
                attemptCount == 1; // Always run on first attempt

            if (shouldRunAudits) {
              stepResult = await _runAuditsForStep(stepResult, stepConfig, i);
            }
          }

          // Check if step passed criteria
          final allIssues = stepResult.issues;
          stepPassed = stepConfig.passedCriteria(allIssues);

          if (!stepPassed && attemptCount <= maxRetries) {
            // Log retry attempt
            print(
              'Step $i attempt $attemptCount failed. ${stepConfig.getFailureReason(allIssues)}. Retrying...',
            );
          }
        } catch (e) {
          // Create an error result
          stepResult = ToolResult(
            toolName: step.toolName,
            input: _buildStepInput(step, i),
            output: {'error': e.toString()},
            issues: [
              Issue(
                id: 'error_${step.toolName}_${i}_attempt_$attemptCount',
                severity: IssueSeverity.critical,
                description: 'Tool execution failed: $e',
                context: {
                  'step': i,
                  'attempt': attemptCount,
                  'toolName': step.toolName,
                  'model': step.model,
                },
                suggestions: ['Check tool configuration and input parameters'],
                round: attemptCount - 1,
              ),
            ],
          );
          stepPassed = false;
        }
      }

      // Add the final result
      if (stepResult != null) {
        _results.add(stepResult);
        _resultsByToolName[stepResult.toolName] = stepResult;

        // Update state with step results
        _state['step_${i}_result'] = stepResult.toJson();
        _state.addAll(stepResult.output);
      }

      // Check if we should stop on failure
      if (!stepPassed && stepConfig.stopOnFailure) {
        print(
          'Step $i failed after $maxRetries retries. Stopping flow execution.',
        );
        break;
      }
    }

    return ToolFlowResult(
      results: List.unmodifiable(_results),
      finalState: Map.unmodifiable(_state),
      allIssues: _getAllIssues(),
      resultsByToolName: Map.unmodifiable(_resultsByToolName),
    );
  }

  /// Executes a single step
  Future<ToolResult> _executeStep(
    ToolCallStep step,
    int stepIndex,
    int round,
  ) async {
    final stepInput = _buildStepInput(step, stepIndex);

    // Add round information to input
    stepInput['_round'] = round;
    stepInput['_previous_issues'] = step.issues
        .map((issue) => issue.toJson())
        .toList();

    // Execute using the injected OpenAI service
    final response = await openAiService.executeToolCall(step, stepInput);

    // Try to create typed interfaces if available
    ToolInput? typedInput;
    ToolOutput? typedOutput;

    try {
      // Attempt to create typed output if registry has a creator
      typedOutput = ToolOutputRegistry.create(step.toolName, response);
    } catch (e) {
      // If typed creation fails, continue with untyped result
    }

    // Create initial result without issues (audits will add them)
    final result = ToolResult(
      toolName: step.toolName,
      input: stepInput,
      output: response,
      issues: [],
      typedInput: typedInput,
      typedOutput: typedOutput,
    );

    return result;
  }

  /// Runs audits for a specific step
  /// Runs audits for a step and returns the result with any issues found
  Future<ToolResult> _runAuditsForStep(
    ToolResult result,
    StepConfig stepConfig,
    int stepIndex,
  ) async {
    var auditedResult = result;

    // Run step-specific audits only (global audits are deprecated)
    for (final audit in stepConfig.audits) {
      final auditIssues = audit.run(auditedResult);
      // Add round information to audit issues
      final roundedIssues = auditIssues
          .map(
            (issue) => Issue(
              id: issue.id,
              severity: issue.severity,
              description: issue.description,
              context: issue.context,
              suggestions: issue.suggestions,
              round:
                  int.tryParse(result.input['_round']?.toString() ?? '0') ?? 0,
              relatedData: {
                'step_index': stepIndex,
                'audit_name': audit.name,
                'tool_output': result.output,
              },
            ),
          )
          .toList();

      auditedResult = auditedResult.withAdditionalIssues(roundedIssues);
    }

    return auditedResult;
  }

  /// Builds input for a step based on current state and step parameters
  Map<String, dynamic> _buildStepInput(ToolCallStep step, int stepIndex) {
    final input = <String, dynamic>{};

    // Add current state
    input.addAll(_state);

    // Add step-specific parameters
    input.addAll(step.params);

    // Add forwarded data from previous steps
    if (step.stepConfig.hasForwarding) {
      final forwardedInput = step.stepConfig.buildForwardedInput(
        _results,
        _resultsByToolName,
      );
      input.addAll(forwardedInput);
    }

    // Apply output sanitization if configured
    if (step.stepConfig.hasOutputSanitizer) {
      final sanitizedInput = step.stepConfig.sanitizeInput(input, _results);
      input.clear();
      input.addAll(sanitizedInput);
    }

    // Add model configuration
    input['_model'] = step.model;
    input['_temperature'] = config.defaultTemperature;
    input['_max_tokens'] = config.defaultMaxTokens;

    return input;
  }

  /// Gets all issues from all completed steps
  List<Issue> _getAllIssues() {
    final allIssues = <Issue>[];
    for (final result in _results) {
      allIssues.addAll(result.issues);
    }
    return allIssues;
  }

  /// Gets the current state (for testing/debugging)
  @visibleForTesting
  Map<String, dynamic> get currentState => Map.unmodifiable(_state);

  /// Gets the current results (for testing/debugging)
  @visibleForTesting
  List<ToolResult> get currentResults => List.unmodifiable(_results);

  /// Gets the current results by tool name (for testing/debugging)
  @visibleForTesting
  Map<String, ToolResult> get currentResultsByToolName => Map.unmodifiable(_resultsByToolName);
}

/// Result of executing a ToolFlow
class ToolFlowResult {
  /// Results from all executed steps
  final List<ToolResult> results;

  /// Final state after all steps completed
  final Map<String, dynamic> finalState;

  /// All issues collected from all steps
  final List<Issue> allIssues;

  /// Results keyed by tool name for easy retrieval
  final Map<String, ToolResult> resultsByToolName;

  /// Creates a ToolFlowResult
  const ToolFlowResult({
    required this.results,
    required this.finalState,
    required this.allIssues,
    required this.resultsByToolName,
  });

  /// Returns true if any step produced issues
  bool get hasIssues => allIssues.isNotEmpty;

  /// Returns issues filtered by severity
  List<Issue> issuesWithSeverity(IssueSeverity severity) {
    return allIssues.where((issue) => issue.severity == severity).toList();
  }

  /// Returns the final output from the last successful step
  Map<String, dynamic>? get finalOutput {
    if (results.isEmpty) return null;
    return results.last.output;
  }

  /// Gets the result for a specific tool by name
  ToolResult? getResultByToolName(String toolName) {
    return resultsByToolName[toolName];
  }

  /// Gets all results for tools matching a pattern
  List<ToolResult> getResultsWhere(bool Function(ToolResult) predicate) {
    return results.where(predicate).toList();
  }

  /// Gets results by tool names
  List<ToolResult> getResultsByToolNames(List<String> toolNames) {
    return toolNames
        .map((name) => resultsByToolName[name])
        .where((result) => result != null)
        .cast<ToolResult>()
        .toList();
  }

  /// Converts this result to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'results': results.map((r) => r.toJson()).toList(),
      'finalState': finalState,
      'allIssues': allIssues.map((i) => i.toJson()).toList(),
      'hasIssues': hasIssues,
      'resultsByToolName': resultsByToolName.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };
  }

  @override
  String toString() {
    return 'ToolFlowResult(steps: ${results.length}, issues: ${allIssues.length}, tools: ${resultsByToolName.keys.join(', ')})';
  }
}
