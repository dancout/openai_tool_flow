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

  /// All attempts for all steps, organized by step index
  /// Each step index maps to a list of attempts (including the final successful one)
  /// Index 0 contains initial input data, indices 1+ contain step attempts
  final List<List<TypedToolResult>> _stepAttempts = [];

  // TODO: Consider if these visibleForTesting are actually needed.

  /// Gets all attempts for a specific step (0-indexed from steps array)
  @visibleForTesting
  List<TypedToolResult>? getStepAttempts(int stepIndex) {
    // Step index maps directly to _stepAttempts index
    // stepIndex 0 -> _stepAttempts[1], stepIndex 1 -> _stepAttempts[2], etc.
    // Index 0 in _stepAttempts is reserved for initial input data
    final storageIndex = stepIndex + 1;
    if (storageIndex < _stepAttempts.length) {
      return _stepAttempts[storageIndex];
    }
    return null;
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
    _stepAttempts.clear();
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
      result: initialResult,
      outputType: ToolOutput,
      tokenUsage: const TokenUsage.zero(), // Initial input has no token usage
    );

    // Initialize storage: index 0 is initial input, indices 1+ are step attempts
    _stepAttempts.add([initialTypedResult]);

    for (int stepIndex = 0; stepIndex < steps.length; stepIndex++) {
      final step = steps[stepIndex];
      final stepConfig = step.stepConfig;

      TypedToolResult? stepResult;
      bool stepPassed = false;
      int attemptCount = 0;
      final maxRetries = stepConfig.maxRetries;

      // Initialize attempts list for this step
      _stepAttempts.add(<TypedToolResult>[]);

      // Retry loop for this step
      while (attemptCount <= maxRetries && !stepPassed) {
        attemptCount++;

        try {
          // Execute the step
          stepResult = await _executeStep(
            step: step,
            stepIndex: stepIndex,
            round: attemptCount - 1,
          );

          // Run audits if configured for this step
          if (stepConfig.hasAudits) {
            stepResult = await _runAuditsForStep(
              result: stepResult,
              stepConfig: stepConfig,
              stepIndex: stepIndex,
            );
          }

          // Store this attempt (whether it passes or fails)
          final currentStepStorageIndex = stepIndex + 1;
          _stepAttempts[currentStepStorageIndex].add(stepResult);

          // Check if step passed criteria
          final allIssues = stepResult.issues;
          stepPassed = stepConfig.passedCriteria(allIssues);

          if (!stepPassed && attemptCount <= maxRetries) {
            // Log retry attempt
            print(
              'Step ${stepIndex + 1} attempt $attemptCount failed. ${stepConfig.getFailureReason(allIssues)}. Retrying...',
            );
          }
        } catch (e) {
          // Create an error result - build step input for error case
          final errorStepInput = _buildStepInput(
            step: step,
            stepIndex: stepIndex,
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
                id: 'error_${step.toolName}_${stepIndex + 1}_attempt_$attemptCount',
                severity: IssueSeverity.critical,
                description: 'Tool execution failed: $e',
                context: {
                  'step': stepIndex + 1,
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
            result: errorToolResult,
            outputType: ToolOutput,
            tokenUsage: const TokenUsage.zero(), // Error cases have no token usage
          );

          // Store this attempt (error case)
          final currentStepStorageIndex = stepIndex + 1;
          _stepAttempts[currentStepStorageIndex].add(stepResult);
          stepPassed = false;
        }
      }

      // Check if step completed successfully
      if (stepResult != null) {
        // Update state with step results
        _state['step_${stepIndex}_result'] = stepResult.toJson();
        _state.addAll(stepResult.output.toMap());
      }

      // Check if we should stop on failure
      if (!stepPassed && stepConfig.stopOnFailure) {
        print(
          'Step ${stepIndex + 1} failed after $maxRetries retries. Stopping flow execution.',
        );
        break;
      }
    }

    // Aggregate token usage from all steps
    _aggregateTokenUsage();

    return ToolFlowResult.fromTypedResults(
      typedResults: List.unmodifiable(_stepAttempts),
      finalState: Map.unmodifiable(_state),
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

    // TODO: We probably don't need to be storing response usage into the state anymore, since we have it at each tool result
    // Store usage information in state
    _state['step_${stepIndex}_usage'] = response.usage;

    // Create token usage object from response (always included)
    final tokenUsage = TokenUsage.fromMap(response.usage);

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

    // Create TypedToolResult with type information from registry and token usage
    final outputType = ToolOutputRegistry.getOutputType(step.toolName);
    return TypedToolResult.fromWithType(
      result: result, 
      outputType: outputType,
      tokenUsage: tokenUsage,
    );
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
  /// Gets the final attempt of each step for passing to inputBuilder
  List<TypedToolResult> _getFinalAttemptsForInputBuilder() {
    // Simply iterate through all step attempts and get the last (final) attempt of each
    final finalAttempts = <TypedToolResult>[];
    for (final stepAttempts in _stepAttempts) {
      if (stepAttempts.isNotEmpty) {
        finalAttempts.add(stepAttempts.last);
      }
    }
    return List.unmodifiable(finalAttempts);
  }

  ToolInput _buildStepInput({
    required ToolCallStep step,
    required int stepIndex,
    required int round,
  }) {
    // Get the results to pass to the inputBuilder (final attempt of each step)
    final inputBuilderResults = _getFinalAttemptsForInputBuilder();

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
      // Get attempts for the referenced step index
      // Convert step index to storage index if needed
      final storageIndex = index == 0 ? 0 : index; // Index 0 is initial input, others are direct
      if (storageIndex < _stepAttempts.length) {
        final attempts = _stepAttempts[storageIndex];
        final filteredResults = _filterAttemptsBySeverity(
          attempts: attempts,
          severityFilter: stepConfig.issuesSeverityFilter,
        );
        includedResults.addAll(filteredResults);
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

  /// Filters TypedToolResult attempts by issue severity and returns ToolResult objects
  /// Consolidates logic previously duplicated in _getIncludedResults and _getCurrentStepAttempts
  List<ToolResult<ToolOutput>> _filterAttemptsBySeverity({
    required List<TypedToolResult> attempts,
    required IssueSeverity severityFilter,
  }) {
    final filteredResults = <ToolResult<ToolOutput>>[];

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
        filteredResults.add(filteredResult);
      }
    }

    return filteredResults;
  }

  /// Gets the retry attempts for the current step with filtered issues
  List<ToolResult<ToolOutput>> _getCurrentStepAttempts({
    required int stepIndex,
    required IssueSeverity severityFilter,
  }) {
    // Get attempts for the current step using storage index
    final storageIndex = stepIndex + 1;
    if (storageIndex >= _stepAttempts.length) {
      throw StateError('Step storage index $storageIndex is out of bounds. _stepAttempts has ${_stepAttempts.length} entries.');
    }
    final attempts = _stepAttempts[storageIndex];
    return _filterAttemptsBySeverity(
      attempts: attempts,
      severityFilter: severityFilter,
    );
  }



  /// Aggregates token usage from all steps into the state
  // TODO: Is this needed anymore since we have the tokenUsage at each TypedToolResult?
  void _aggregateTokenUsage() {
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
  /// Structure: List of steps, where each step contains a list of attempts
  final List<List<TypedToolResult>> _stepResults;

  /// Results from all executed steps organized by step
  /// Returns `List<List<TypedToolResult>>` where:
  /// - Outer list index: step index (0 = initial input, 1+ = actual steps)
  /// - Inner list: all attempts for that step (or just final attempt if includeAllAttempts=false)
  List<List<TypedToolResult>> get results {
    return List.unmodifiable(
      _stepResults.map((stepAttempts) => 
        List<TypedToolResult>.unmodifiable(stepAttempts)
      ).toList()
    );
  }

  /// Returns only the final (successful or last failed) result from each step
  List<TypedToolResult> get finalResults {
    final finals = <TypedToolResult>[];
    for (final stepAttempts in _stepResults) {
      if (stepAttempts.isNotEmpty) {
        finals.add(stepAttempts.last);
      }
    }
    return finals;
  }

  /// Final state after all steps completed
  final Map<String, dynamic> finalState;

  /// All issues collected from all steps (derived from results)
  List<Issue> get allIssues {
    final issues = <Issue>[];
    for (final stepAttempts in _stepResults) {
      for (final attempt in stepAttempts) {
        issues.addAll(attempt.issues);
      }
    }
    return issues;
  }

  /// Issues collected from only the final results of each step
  List<Issue> get allFinalResultsIssues {
    final issues = <Issue>[];
    for (final stepAttempts in _stepResults) {
      if (stepAttempts.isNotEmpty) {
        issues.addAll(stepAttempts.last.issues);
      }
    }
    return issues;
  }

  /// Creates a ToolFlowResult from typed results
  ToolFlowResult.fromTypedResults({
    required List<List<TypedToolResult>> typedResults,
    required this.finalState,
  }) : _stepResults = typedResults;

  /// Converts this result to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'results': results.map((stepAttempts) => 
          stepAttempts.map((attempt) => attempt.toJson()).toList()).toList(),
      'finalState': finalState,
      'allIssues': allIssues.map((i) => i.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'ToolFlowResult(steps: ${results.length}, totalIssues: ${allIssues.length})';
  }
}
