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
  /// For duplicate tool names, this contains the MOST RECENT result
  final Map<String, ToolResult> _resultsByToolName = {};

  /// All results grouped by tool name (handles duplicates)
  /// Each tool name maps to a list of results in execution order
  final Map<String, List<ToolResult>> _allResultsByToolName = {};

  /// Creates a ToolFlow with configuration and steps
  ToolFlow({
    required this.config,
    required this.steps,
    OpenAiToolService? openAiService,
  }) : openAiService =
           openAiService ?? DefaultOpenAiToolService(config: config);

  /// Executes the tool flow with the given input
  ///
  /// Returns a ToolFlowResult containing all step results and final state
  Future<ToolFlowResult> run({Map<String, dynamic> input = const {}}) async {
    _state.clear();
    _results.clear();
    _resultsByToolName.clear();
    _allResultsByToolName.clear();
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
          stepResult = await _executeStep(
            step: step,
            stepIndex: i,
            round: attemptCount - 1,
          );

          // Run audits if configured for this step
          if (stepConfig.hasAudits) {
            final shouldRunAudits =
                !stepConfig.auditOnlyFinalAttempt ||
                attemptCount > maxRetries ||
                attemptCount == 1; // Always run on first attempt

            if (shouldRunAudits) {
              stepResult = await _runAuditsForStep(
                result: stepResult,
                stepConfig: stepConfig,
                stepIndex: i,
              );
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
          // Create an error result - build step input for error case
          final errorStepInput = _buildStepInput(
            step: step,
            stepIndex: i,
            round: attemptCount,
          );
          stepResult = ToolResult(
            toolName: step.toolName,
            input: errorStepInput,
            output: GenericToolOutput({'error': e.toString()}),
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

        // Update results by tool name (most recent wins for simple access)
        _resultsByToolName[stepResult.toolName] = stepResult;

        // Update all results by tool name (for duplicate handling)
        _allResultsByToolName
            .putIfAbsent(stepResult.toolName, () => [])
            .add(stepResult);

        // Update state with step results
        _state['step_${i}_result'] = stepResult.toJson();
        _state.addAll(stepResult.output.toMap());
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
      allResultsByToolName: _allResultsByToolName.map(
        (key, value) => MapEntry(key, List<ToolResult>.unmodifiable(value)),
      ),
    );
  }

  /// Executes a single step
  Future<ToolResult> _executeStep({
    required ToolCallStep step,
    required int stepIndex,
    required int round,
  }) async {
    ToolInput stepInput = _buildStepInput(
      step: step,
      stepIndex: stepIndex,
      round: round,
    );

    // Execute using the injected OpenAI service
    final response = await openAiService.executeToolCall(step, stepInput);

    // Apply output sanitization first if configured
    final sanitizedOutput = step.stepConfig.hasOutputSanitizer
        ? step.stepConfig.sanitizeOutput(response)
        : response;

    // Try to create typed interfaces if available
    ToolOutput? typedOutput;

    // Attempt to create typed output if registry has a creator using sanitized data
    if (ToolOutputRegistry.hasTypedOutput(step.toolName)) {
      try {
        typedOutput = ToolOutputRegistry.create(
          toolName: step.toolName,
          data: sanitizedOutput,
        );
      } catch (e) {
        throw Exception(
          'Failed to create typed output for ${step.toolName}: $e',
        );
      }
    }

    // Ensure we have a typed output
    typedOutput ??= GenericToolOutput(sanitizedOutput);

    // Create initial result without issues (audits will add them)
    final result = ToolResult(
      toolName: step.toolName,
      input: stepInput,
      output: typedOutput,
      issues: [],
    );

    return result;
  }

  /// Runs audits for a step and returns the result with any issues found
  Future<ToolResult> _runAuditsForStep({
    required ToolResult result,
    required StepConfig stepConfig,
    required int stepIndex,
  }) async {
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
                  int.tryParse(result.input.toMap()['_round']?.toString() ?? '0') ?? 0,
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

  /// Builds input for a step based on inputBuilder and step configuration
  ToolInput _buildStepInput({
    required ToolCallStep step,
    required int stepIndex,
    required int round,
  }) {
    // Get the results to pass to the inputBuilder
    final inputBuilderResults = _getInputBuilderResults(step: step);

    // Execute the inputBuilder to get custom input data
    Map<String, dynamic> customData;
    try {
      customData = step.inputBuilder(inputBuilderResults);
    } catch (e) {
      throw Exception(
        'Failed to execute inputBuilder for step "${step.toolName}": $e',
      );
    }

    // Include results from previous steps if configured (for includeOutputsFrom)
    List<ToolResult> includedResults = [];
    if (step.stepConfig.hasOutputInclusion) {
      includedResults = _getIncludedResults(stepConfig: step.stepConfig);
      final includedOutputs = step.stepConfig.buildIncludedOutputs(
        _results,
        _resultsByToolName,
      );
      customData.addAll(includedOutputs);
    }

    // Create structured input with previous results
    ToolInput stepInput = ToolInput(
      round: round,
      previousResults: includedResults,
      customData: customData,
      model: step.model,
      temperature: config.defaultTemperature,
      maxTokens: config.defaultMaxTokens,
    );

    // Apply input sanitization if configured (before execution)
    if (step.stepConfig.hasInputSanitizer) {
      // TODO: We don't actually use the sanitizedInput in our example.
      // So, I'm not certain it works as expected.
      final sanitizedInput = step.stepConfig.sanitizeInput(
        rawInput: stepInput.toMap(),
        // TODO: Why does sanitizeInput take in the entire list of results?
        previousResults: _results,
      );
      stepInput = ToolInput.fromMap(sanitizedInput);
    }

    return stepInput;
  }

  /// Gets the list of results that should be passed to inputBuilder
  List<ToolResult> _getInputBuilderResults({required ToolCallStep step}) {
    final inputResults = <ToolResult>[];

    for (final reference in step.buildInputsFrom) {
      ToolResult? sourceResult;

      // Find the source result by index or tool name
      if (reference is int) {
        if (reference >= 0 && reference < _results.length) {
          sourceResult = _results[reference];
        }
      } else if (reference is String) {
        sourceResult = _resultsByToolName[reference];
      }

      if (sourceResult != null) {
        inputResults.add(sourceResult);
      }
    }

    return inputResults;
  }

  /// Gets the list of results that should be included based on step configuration
  List<ToolResult> _getIncludedResults({required StepConfig stepConfig}) {
    final includedResults = <ToolResult>[];

    for (final include in stepConfig.includeOutputsFrom) {
      if (include is int) {
        // Include by step index
        if (include >= 0 && include < _results.length) {
          includedResults.add(_results[include]);
        }
      } else if (include is String) {
        // Include by tool name (most recent)
        final result = _resultsByToolName[include];
        if (result != null) {
          includedResults.add(result);
        }
      }
    }

    return includedResults;
  }

  /// Gets all issues from all completed steps
  List<Issue> _getAllIssues() {
    final allIssues = <Issue>[];
    for (final result in _results) {
      allIssues.addAll(result.issues);
    }
    return allIssues;
  }

  // TODO: Eventually, investigate if these visible for testings are necessary
  /// Gets the current state (for testing/debugging)
  @visibleForTesting
  Map<String, dynamic> get currentState => Map.unmodifiable(_state);

  /// Gets the current results (for testing/debugging)
  @visibleForTesting
  List<ToolResult> get currentResults => List.unmodifiable(_results);

  /// Gets the current results by tool name (for testing/debugging)
  @visibleForTesting
  Map<String, ToolResult> get currentResultsByToolName =>
      Map.unmodifiable(_resultsByToolName);

  /// Gets the current all results by tool name (for testing/debugging)
  @visibleForTesting
  Map<String, List<ToolResult>> get currentAllResultsByToolName =>
      Map.unmodifiable(
        _allResultsByToolName.map(
          (key, value) => MapEntry(key, List.unmodifiable(value)),
        ),
      );
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
  /// For duplicate tool names, this contains the MOST RECENT result
  ///
  /// **Example:**
  /// ```dart
  /// final latestPaletteResult = result.resultsByToolName['extract_palette'];
  /// ```
  final Map<String, ToolResult> resultsByToolName;

  /// All results grouped by tool name (handles duplicates)
  /// Each tool name maps to a list of results in execution order
  ///
  /// **Use this when you need all instances of a tool:**
  /// ```dart
  /// final allPaletteResults = result.allResultsByToolName['extract_palette'] ?? [];
  /// for (final result in allPaletteResults) {
  ///   print('Palette from step ${result.input['_round']}: ${result.output}');
  /// }
  /// ```
  final Map<String, List<ToolResult>> allResultsByToolName;

  /// Creates a ToolFlowResult
  const ToolFlowResult({
    required this.results,
    required this.finalState,
    required this.allIssues,
    required this.resultsByToolName,
    required this.allResultsByToolName,
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
    return results.last.output.toMap();
  }

  /// Gets the result for a specific tool by name
  /// Returns the most recent result if there are duplicates
  ///
  /// **Example:**
  /// ```dart
  /// final paletteResult = result.getResultByToolName('extract_palette');
  /// if (paletteResult != null) {
  ///   final colors = paletteResult.output['colors'];
  /// }
  /// ```
  ToolResult? getResultByToolName(String toolName) {
    return resultsByToolName[toolName];
  }

  /// Gets all results for a specific tool name (handles duplicates)
  /// Returns results in execution order
  ///
  /// **Use when the same tool was called multiple times:**
  /// ```dart
  /// final allRefinements = result.getAllResultsByToolName('refine_colors');
  /// for (int i = 0; i < allRefinements.length; i++) {
  ///   print('Refinement iteration ${i + 1}: ${allRefinements[i].output}');
  /// }
  /// ```
  List<ToolResult> getAllResultsByToolName(String toolName) {
    return allResultsByToolName[toolName] ?? [];
  }

  /// Gets all results for tools matching a pattern
  List<ToolResult> getResultsWhere(bool Function(ToolResult) predicate) {
    return results.where(predicate).toList();
  }

  /// Gets results by tool names (most recent for each tool)
  List<ToolResult> getResultsByToolNames(List<String> toolNames) {
    return toolNames
        .map((name) => resultsByToolName[name])
        .where((result) => result != null)
        .cast<ToolResult>()
        .toList();
  }

  /// Gets all results by tool names (including duplicates)
  List<ToolResult> getAllResultsByToolNames(List<String> toolNames) {
    return toolNames.expand((name) => getAllResultsByToolName(name)).toList();
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
      'allResultsByToolName': allResultsByToolName.map(
        (key, value) => MapEntry(key, value.map((r) => r.toJson()).toList()),
      ),
    };
  }

  @override
  String toString() {
    return 'ToolFlowResult(steps: ${results.length}, issues: ${allIssues.length}, tools: ${resultsByToolName.keys.join(', ')})';
  }
}
