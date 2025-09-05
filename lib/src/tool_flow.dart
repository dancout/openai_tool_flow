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

    // Build tool name maps from results list
    final Map<String, TypedToolResult> resultsByToolName = {};
    final Map<String, List<TypedToolResult>> allResultsByToolName = {};
    
    for (final result in _results) {
      final toolName = result.toolName;
      resultsByToolName[toolName] = result; // Most recent wins
      allResultsByToolName.putIfAbsent(toolName, () => []).add(result);
    }

    // Aggregate token usage from all steps
    _aggregateTokenUsage();

    return ToolFlowResult._fromTyped(
      typedResults: List.unmodifiable(_results),
      finalState: Map.unmodifiable(_state),
      allIssues: _getAllIssues(),
      typedResultsByToolName: Map.unmodifiable(resultsByToolName),
      allTypedResultsByToolName: allResultsByToolName.map(
        (key, value) =>
            MapEntry(key, List<TypedToolResult>.unmodifiable(value)),
      ),
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

    // Execute using the injected OpenAI service with included results
    final response = await openAiService.executeToolCall(
      step,
      stepInput,
      includedResults: includedResults,
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
      TypedToolResult? sourceTypedResult;

      // Find the source result by index only
      if (index >= 0 && index < _results.length) {
        sourceTypedResult = _results[index];
      }

      if (sourceTypedResult != null) {
        // Filter issues by severity level
        final filteredIssues = sourceTypedResult.issues
            .where(
              (issue) => _isIssueSeverityIncluded(
                issue.severity,
                stepConfig.issuesSeverityFilter,
              ),
            )
            .toList();

        // Only include result if it has issues matching the filter
        if (filteredIssues.isNotEmpty) {
          // Create a copy of the result with filtered issues
          final filteredResult = sourceTypedResult.underlyingResult.copyWith(
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

  /// Gets all issues from all completed steps
  List<Issue> _getAllIssues() {
    final allIssues = <Issue>[];
    for (final result in _results) {
      allIssues.addAll(result.issues);
    }
    return allIssues;
  }

  /// Aggregates token usage from all steps into the state
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
  final List<TypedToolResult> _typedResults;

  /// Results from all executed steps (now returns TypedToolResult)
  List<TypedToolResult> get results => List.unmodifiable(_typedResults);

  /// Final state after all steps completed
  final Map<String, dynamic> finalState;

  /// All issues collected from all steps
  final List<Issue> allIssues;

  /// Results keyed by tool name for easy retrieval (backward compatible interface)
  /// For duplicate tool names, this contains the MOST RECENT result
  ///
  /// **Example:**
  /// ```dart
  /// final latestPaletteResult = result.resultsByToolName['extract_palette'];
  /// ```
  Map<String, ToolResult<ToolOutput>> get resultsByToolName =>
      _typedResultsByToolName.map(
        (key, value) => MapEntry(key, value.underlyingResult),
      );

  /// All results grouped by tool name (backward compatible interface)
  /// Each tool name maps to a list of results in execution order
  ///
  /// **Use this when you need all instances of a tool:**
  /// ```dart
  /// final allPaletteResults = result.allResultsByToolName['extract_palette'] ?? [];
  /// for (final result in allPaletteResults) {
  ///   print('Palette from step ${result.input['_round']}: ${result.output}');
  /// }
  /// ```
  Map<String, List<ToolResult<ToolOutput>>> get allResultsByToolName =>
      _allTypedResultsByToolName.map(
        (key, value) =>
            MapEntry(key, value.map((tr) => tr.underlyingResult).toList()),
      );

  /// Internal typed results keyed by tool name
  final Map<String, TypedToolResult> _typedResultsByToolName;

  /// Internal all typed results grouped by tool name
  final Map<String, List<TypedToolResult>> _allTypedResultsByToolName;

  /// Creates a ToolFlowResult from typed results
  ToolFlowResult._fromTyped({
    required List<TypedToolResult> typedResults,
    required this.finalState,
    required this.allIssues,
    required Map<String, TypedToolResult> typedResultsByToolName,
    required Map<String, List<TypedToolResult>> allTypedResultsByToolName,
  }) : _typedResults = typedResults,
       _typedResultsByToolName = typedResultsByToolName,
       _allTypedResultsByToolName = allTypedResultsByToolName;

  /// Creates a ToolFlowResult (backward compatible constructor)
  const ToolFlowResult({
    required List<ToolResult<ToolOutput>> results,
    required this.finalState,
    required this.allIssues,
    required Map<String, ToolResult<ToolOutput>> resultsByToolName,
    required Map<String, List<ToolResult<ToolOutput>>> allResultsByToolName,
  }) : _typedResults = const [],
       _typedResultsByToolName = const {},
       _allTypedResultsByToolName = const {};

  /// Returns true if any step produced issues
  bool get hasIssues => allIssues.isNotEmpty;

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
  ToolResult<ToolOutput>? getResultByToolName(String toolName) {
    return resultsByToolName[toolName];
  }

  /// Gets the typed result for a specific tool by name
  /// Returns the most recent result if there are duplicates
  ///
  /// This method enables type-safe access to results for audit functions
  /// and other code that needs the specific output type.
  TypedToolResult? getTypedResultByToolName(String toolName) {
    return _typedResultsByToolName[toolName];
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
  List<ToolResult<ToolOutput>> getAllResultsByToolName(String toolName) {
    return allResultsByToolName[toolName] ?? [];
  }

  /// Gets all typed results for a specific tool name (handles duplicates)
  /// Returns results in execution order
  List<TypedToolResult> getAllTypedResultsByToolName(String toolName) {
    return _allTypedResultsByToolName[toolName] ?? [];
  }

  /// Gets all results for tools matching a pattern
  List<TypedToolResult> getResultsWhere(
    bool Function(TypedToolResult) predicate,
  ) {
    return results.where(predicate).toList();
  }

  /// Gets results by tool names (most recent for each tool)
  List<TypedToolResult> getResultsByToolNames(List<String> toolNames) {
    return toolNames
        .map((name) => _typedResultsByToolName[name])
        .where((result) => result != null)
        .cast<TypedToolResult>()
        .toList();
  }

  /// Gets all results by tool names (including duplicates)
  List<TypedToolResult> getAllResultsByToolNames(List<String> toolNames) {
    return toolNames
        .expand((name) => getAllTypedResultsByToolName(name))
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
