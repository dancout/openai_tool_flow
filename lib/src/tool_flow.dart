import 'package:meta/meta.dart';
import 'package:openai_toolflow/openai_toolflow.dart';

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

  /// Results from completed steps (ordered list) using type-safe wrappers
  final List<TypedToolResult> _results = [];

  /// All retry attempts for all steps, organized by step index
  /// Each step index maps to a list of attempts (including the final successful one)
  final Map<int, List<TypedToolResult>> _allAttempts = {};

  /// Gets all retry attempts for a specific step (for testing purposes)
  @visibleForTesting
  List<TypedToolResult>? getStepAttempts(int stepIndex) {
    return _allAttempts[stepIndex];
  }

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
  Future<ToolFlowResult> run({required Map<String, dynamic> input}) async {
    _state.clear();
    _results.clear();
    _allAttempts.clear();
    _state.addAll(input);

    // Create initial TypedToolResult from input
    final initialOutput = ToolOutput(input, round: 0);
    final initialInput = ToolInput(
      round: 0,
      customData: input,
      model: config.defaultModel,
      temperature: config.defaultTemperature,
      maxTokens: config.defaultMaxTokens,
    );
    final initialResult = ToolResult<ToolOutput>(
      toolName: 'initial_input',
      input: initialInput,
      output: initialOutput,
      issues: [],
    );
    final initialTypedResult = TypedToolResult.fromWithType(
      initialResult,
      ToolOutput,
    );

    // Add initial result to collections
    _results.add(initialTypedResult);

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final stepConfig = step.stepConfig;

      TypedToolResult? stepResult;
      bool stepPassed = false;
      int attemptCount = 0;
      final maxRetries = stepConfig.maxRetries;

      // Initialize attempts list for this step
      _allAttempts[i] = [];

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
            stepResult = await _runAuditsForStep(
              result: stepResult,
              stepConfig: stepConfig,
              stepIndex: i,
            );
          }

          // Store this attempt (whether it passes or fails)
          _allAttempts[i]!.add(stepResult);

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
          final errorToolResult = ToolResult<ToolOutput>(
            toolName: step.toolName,
            input: errorStepInput,
            output: ToolOutput({
              'error': e.toString(),
            }, round: attemptCount - 1),
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
          // Wrap error result in TypedToolResult
          stepResult = TypedToolResult.fromWithType(
            errorToolResult,
            ToolOutput,
          );
          
          // Store this attempt (error case)
          _allAttempts[i]!.add(stepResult);
          stepPassed = false;
        }
      }

      // Add the final result
      if (stepResult != null) {
        _results.add(stepResult);

        // TODO: It would be kinda cool to add how many tokens were consumed form that step into the state, both input and output tokens

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

    // Aggregate token usage from all steps
    _aggregateTokenUsage();

    return ToolFlowResult._fromTyped(
      typedResults: List.unmodifiable(_results),
      finalState: Map.unmodifiable(_state),
      allIssues: _getAllIssues(),
    );
  }

  /// Executes a single step
  Future<TypedToolResult> _executeStep({
    required ToolCallStep step,
    required int stepIndex,
    required int round,
  }) async {
    ToolInput stepInput = _buildStepInput(
      step: step,
      stepIndex: stepIndex,
      round: round,
    );

    // Get results to include in tool call if configured
    final includedResults = _getIncludedResults(step: step);

    // Get current step retry attempts (excluding the current attempt)
    final currentStepRetries = _getCurrentStepAttempts(
      stepIndex: stepIndex,
      severityFilter: step.stepConfig.issuesSeverityFilter,
    );

    // Execute using the injected OpenAI service with included results and retry attempts
    final response = await openAiService.executeToolCall(
      step,
      stepInput,
      includedResults: includedResults,
      currentStepRetries: currentStepRetries,
    );

    // Store usage information in state
    _state['step_${stepIndex}_usage'] = response.usage;

    // Apply output sanitization first if configured
    final sanitizedOutput = step.stepConfig.hasOutputSanitizer
        ? step.stepConfig.sanitizeOutput(response.output)
        : response.output;

    // Try to create typed interfaces if available
    late ToolOutput typedOutput;

    if (!ToolOutputRegistry.hasTypedOutput(step.toolName)) {
      throw Exception('No typed output registered for ${step.toolName}');
    }

    // Create typed output using registry with round information
    typedOutput = ToolOutputRegistry.create(
      toolName: step.toolName,
      data: sanitizedOutput,
      round: round,
    );

    // Create initial result without issues (audits will add them)
    final result = ToolResult<ToolOutput>(
      toolName: step.toolName,
      input: stepInput,
      output: typedOutput,
      issues: [],
    );

    // Create TypedToolResult with type information from registry
    final outputType = ToolOutputRegistry.getOutputType(step.toolName);
    return TypedToolResult.fromWithType(result, outputType);
  }

  /// Runs audits for a step and returns the result with any issues found
  Future<TypedToolResult> _runAuditsForStep({
    required TypedToolResult result,
    required StepConfig stepConfig,
    required int stepIndex,
  }) async {
    var auditedResult = result;

    // Run step-specific audits only (global audits are deprecated)
    for (final audit in stepConfig.audits) {
      // Execute audit with proper type-safe casting
      late List<Issue> auditIssues;

      try {
        // Use a type-safe approach to execute the audit
        auditIssues = audit.runWithTypeChecking(result.underlyingResult);
      } catch (e) {
        // If audit execution fails, create an audit execution error
        auditIssues = [
          Issue(
            id: 'audit_execution_error_${audit.name}_$stepIndex',
            severity: IssueSeverity.critical,
            description: 'Audit ${audit.name} execution failed: $e',
            context: {
              'step_index': stepIndex,
              'audit_name': audit.name,
              'error': e.toString(),
              'actual_output_type': auditedResult.outputType.toString(),
            },
            suggestions: [
              'Check audit function implementation',
              'Verify tool output structure matches expectations',
              'Ensure tool output type matches audit expectations',
            ],
            round:
                int.tryParse(
                  result.input.toMap()['_round']?.toString() ?? '0',
                ) ??
                0,
          ),
        ];
      }

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
                  int.tryParse(
                    result.input.toMap()['_round']?.toString() ?? '0',
                  ) ??
                  0,
              relatedData: {
                'step_index': stepIndex,
                'audit_name': audit.name,
                'tool_output': result.output,
              },
            ),
          )
          .toList();

      auditedResult = auditedResult.copyWith(
        result: auditedResult.underlyingResult.copyWith(
          issues: [...auditedResult.underlyingResult.issues, ...roundedIssues],
        ),
      );
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
    final inputBuilderResults = List<TypedToolResult>.unmodifiable(_results);

    // Execute the inputBuilder to get custom input data
    Map<String, dynamic> customData;
    try {
      if (step.inputBuilder != null) {
        customData = step.inputBuilder!(inputBuilderResults);
      } else {
        // Default behavior: use previous step's output as input
        final previousResult = inputBuilderResults.last;
        customData = previousResult.output.toMap();
      }
    } catch (e) {
      throw Exception(
        'Failed to execute inputBuilder for step "${step.toolName}": $e',
      );
    }

    // Create structured input with previous results
    ToolInput stepInput = ToolInput(
      round: round,
      customData: customData,
      model: step.model ?? config.defaultModel,
      temperature: config.defaultTemperature,
      maxTokens: step.stepConfig.maxTokens ?? config.defaultMaxTokens,
    );

    // Apply input sanitization if configured (before execution)
    if (step.stepConfig.hasInputSanitizer) {
      // So, I'm not certain it works as expected.
      final sanitizedInput = step.stepConfig.sanitizeInput(stepInput.toMap());
      stepInput = ToolInput.fromMap(sanitizedInput);
    }

    return stepInput;
  }

  /// Gets the list of results to include in tool call system messages with filtered issues
  List<ToolResult<ToolOutput>> _getIncludedResults({
    required ToolCallStep step,
  }) {
    final includedResults = <ToolResult<ToolOutput>>[];
    final stepConfig = step.stepConfig;

    for (final index in step.includeResultsInToolcall) {
      // Pull all attempts for the referenced step index
      final attempts = _allAttempts[index] ?? [];
      for (final attempt in attempts) {
        // Filter issues by severity level
        final filteredIssues = attempt.issues
            .where(
              (issue) => _isIssueSeverityIncluded(
                issue.severity,
                stepConfig.issuesSeverityFilter,
              ),
            )
            .toList();

        // Only include attempt if it has issues matching the filter
        if (filteredIssues.isNotEmpty) {
          // Create a copy of the result with filtered issues
          final filteredResult = attempt.underlyingResult.copyWith(
            issues: filteredIssues,
          );
          includedResults.add(filteredResult);
        }
      }
    }

    return includedResults;
  }

  /// Checks if an issue severity should be included based on the filter level
  bool _isIssueSeverityIncluded(
    IssueSeverity issueSeverity,
    IssueSeverity filterLevel,
  ) {
    final severityLevels = [
      IssueSeverity.low,
      IssueSeverity.medium,
      IssueSeverity.high,
      IssueSeverity.critical,
    ];

    final issueIndex = severityLevels.indexOf(issueSeverity);
    final filterIndex = severityLevels.indexOf(filterLevel);

    return issueIndex >= filterIndex;
  }

  /// Gets the retry attempts for the current step with filtered issues
  List<ToolResult<ToolOutput>> _getCurrentStepAttempts({
    required int stepIndex,
    required IssueSeverity severityFilter,
  }) {
    final attemptResults = <ToolResult<ToolOutput>>[];
    final attempts = _allAttempts[stepIndex] ?? [];

    for (final attempt in attempts) {
      // Filter issues by severity level
      final filteredIssues = attempt.issues
          .where(
            (issue) => _isIssueSeverityIncluded(issue.severity, severityFilter),
          )
          .toList();

      // Only include attempt if it has issues matching the filter
      if (filteredIssues.isNotEmpty) {
        // Create a copy of the result with filtered issues
        final filteredResult = attempt.underlyingResult.copyWith(
          issues: filteredIssues,
        );
        attemptResults.add(filteredResult);
      }
    }

    return attemptResults;
  }

  /// Gets all issues from all completed steps
  // TODO: To be more accurate, this is all issues in the final results of each step - NOT across all attempts.
  // TODO: Add another getter and handler for retrieving truly all issues from all attempts and name both getters accordingly.
  List<Issue> _getAllIssues() {
    final allIssues = <Issue>[];
    for (final result in _results) {
      allIssues.addAll(result.issues);
    }
    return allIssues;
  }

  /// Aggregates token usage from all steps into the state
  void _aggregateTokenUsage() {
    // TODO: Would it be better to store the token usage in the TypedToolResult somewhere? Then it would be accessible at a more granular level to the user.
    /// We could even have it be a list of usages per attempt so that the user could see how many tokens were consumed per attempt of each step
    /// Then the total per step could be a convenience getter for total tokens
    /// Same with the tool flow, we could have convenience getters for total token usage
    /// BUT - still have access at each layer if the user was interested
    int totalPromptTokens = 0;
    int totalCompletionTokens = 0;
    int totalTokens = 0;

    // Sum up usage from all steps
    for (int i = 0; i < steps.length; i++) {
      final stepUsage = _state['step_${i}_usage'] as Map<String, dynamic>?;
      if (stepUsage != null) {
        totalPromptTokens += (stepUsage['prompt_tokens'] as int? ?? 0);
        totalCompletionTokens += (stepUsage['completion_tokens'] as int? ?? 0);
        totalTokens += (stepUsage['total_tokens'] as int? ?? 0);
      }
    }

    // Store aggregated usage in state
    _state['token_usage'] = {
      'total_prompt_tokens': totalPromptTokens,
      'total_completion_tokens': totalCompletionTokens,
      'total_tokens': totalTokens,
    };
  }
}

/// Result of executing a ToolFlow
class ToolFlowResult {
  /// Internal typed results from all executed steps
  final List<TypedToolResult> _typedResults;

  /// Results from all executed steps (now returns TypedToolResult)
  List<TypedToolResult> get results => List.unmodifiable(_typedResults);

  /// Final state after all steps completed
  final Map<String, dynamic> finalState;

  /// All issues collected from all steps
  final List<Issue> allIssues;

  /// Creates a ToolFlowResult from typed results
  ToolFlowResult._fromTyped({
    required List<TypedToolResult> typedResults,
    required this.finalState,
    required this.allIssues,
  }) : _typedResults = typedResults;

  /// Creates a ToolFlowResult (backward compatible constructor)
  const ToolFlowResult({
    required List<ToolResult<ToolOutput>> results,
    required this.finalState,
    required this.allIssues,
  }) : _typedResults = const [];

  /// Converts this result to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'results': results.map((r) => r.toJson()).toList(),
      'finalState': finalState,
      'allIssues': allIssues.map((i) => i.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'ToolFlowResult(steps: ${results.length}, issues: ${allIssues.length})';
  }
}
