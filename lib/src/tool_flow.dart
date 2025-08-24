import 'package:meta/meta.dart';

import 'audit_function.dart';
import 'issue.dart';
import 'openai_config.dart';
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
class ToolFlow {
  /// Configuration for OpenAI API access
  final OpenAIConfig config;
  
  /// Ordered list of tool call steps to execute
  final List<ToolCallStep> steps;
  
  /// Optional audit functions to run after each step (legacy)
  /// Use stepConfigs for more granular control
  final List<AuditFunction> audits;

  /// Per-step configuration for audits and retry behavior
  /// Key is step index (0-based), value is configuration for that step
  final Map<int, StepConfig> stepConfigs;
  
  /// Internal state accumulated across steps
  final Map<String, dynamic> _state = {};
  
  /// Results from completed steps
  final List<ToolResult> _results = [];

  /// Creates a ToolFlow with configuration and steps
  ToolFlow({
    required this.config,
    required this.steps,
    this.audits = const [],
    this.stepConfigs = const {},
  });

  /// Executes the tool flow with the given input
  /// 
  /// Returns a ToolFlowResult containing all step results and final state
  Future<ToolFlowResult> run({
    Map<String, dynamic> input = const {},
  }) async {
    _state.clear();
    _results.clear();
    _state.addAll(input);

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final stepConfig = stepConfigs.getConfigForStep(i);
      
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
          if (stepConfig.hasAudits || audits.isNotEmpty) {
            final shouldRunAudits = !stepConfig.auditOnlyFinalAttempt || 
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
            print('Step $i attempt $attemptCount failed. ${stepConfig.getFailureReason(allIssues)}. Retrying...');
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
        
        // Update state with step results
        _state['step_${i}_result'] = stepResult.toJson();
        _state.addAll(stepResult.output);
      }
      
      // Check if we should stop on failure
      if (!stepPassed && stepConfig.stopOnFailure) {
        print('Step $i failed after $maxRetries retries. Stopping flow execution.');
        break;
      }
    }

    return ToolFlowResult(
      results: List.unmodifiable(_results),
      finalState: Map.unmodifiable(_state),
      allIssues: _getAllIssues(),
    );
  }

  /// Executes a single step
  Future<ToolResult> _executeStep(ToolCallStep step, int stepIndex, int round) async {
    final stepInput = _buildStepInput(step, stepIndex);
    
    // Add round information to input
    stepInput['_round'] = round;
    stepInput['_previous_issues'] = step.issues.map((issue) => issue.toJson()).toList();
    
    // For now, we'll create a mock response since we don't want to make actual OpenAI calls
    // In a real implementation, this would call the OpenAI API
    final response = await _mockToolCall(step, stepInput);
    
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
  Future<ToolResult> _runAuditsForStep(
    ToolResult result, 
    StepConfig stepConfig, 
    int stepIndex,
  ) async {
    var auditedResult = result;
    
    // Run step-specific audits first
    for (final audit in stepConfig.audits) {
      final auditIssues = audit.run(auditedResult);
      // Add round information to audit issues
      final roundedIssues = auditIssues.map((issue) => Issue(
        id: issue.id,
        severity: issue.severity,
        description: issue.description,
        context: issue.context,
        suggestions: issue.suggestions,
        round: int.tryParse(result.input['_round']?.toString() ?? '0') ?? 0,
        relatedData: {
          'step_index': stepIndex,
          'audit_name': audit.name,
          'tool_output': result.output,
        },
      )).toList();
      
      auditedResult = auditedResult.withAdditionalIssues(roundedIssues);
    }
    
    // Run legacy global audits if no step-specific audits are configured
    if (!stepConfig.hasAudits) {
      for (final audit in audits) {
        final auditIssues = audit.run(auditedResult);
        // Add round information to audit issues
        final roundedIssues = auditIssues.map((issue) => Issue(
          id: issue.id,
          severity: issue.severity,
          description: issue.description,
          context: issue.context,
          suggestions: issue.suggestions,
          round: int.tryParse(result.input['_round']?.toString() ?? '0') ?? 0,
          relatedData: {
            'step_index': stepIndex,
            'audit_name': audit.name,
            'tool_output': result.output,
          },
        )).toList();
        
        auditedResult = auditedResult.withAdditionalIssues(roundedIssues);
      }
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
    
    // Add model configuration
    input['_model'] = step.model;
    input['_temperature'] = config.defaultTemperature;
    input['_max_tokens'] = config.defaultMaxTokens;
    
    return input;
  }

  /// Mock tool call implementation
  /// 
  /// In a real implementation, this would make HTTP calls to OpenAI API
  Future<Map<String, dynamic>> _mockToolCall(
    ToolCallStep step,
    Map<String, dynamic> input,
  ) async {
    // Simulate some processing time
    await Future.delayed(Duration(milliseconds: 100));
    
    // Return mock response based on tool name
    switch (step.toolName) {
      case 'extract_palette':
        return {
          'colors': ['#FF5733', '#33FF57', '#3357FF', '#F333FF'],
          'confidence': 0.85,
          'image_analyzed': input['imagePath'] ?? 'unknown',
        };
      
      case 'refine_colors':
        return {
          'refined_colors': ['#E74C3C', '#2ECC71', '#3498DB', '#9B59B6'],
          'improvements_made': ['contrast adjustment', 'saturation optimization'],
        };
      
      case 'generate_theme':
        return {
          'theme': {
            'primary': '#E74C3C',
            'secondary': '#2ECC71',
            'accent': '#3498DB',
            'background': '#FFFFFF',
          },
          'metadata': {
            'generated_at': DateTime.now().toIso8601String(),
            'model_used': step.model,
          },
        };
      
      default:
        return {
          'message': 'Tool ${step.toolName} executed successfully',
          'input_received': input.keys.toList(),
          'model_used': step.model,
        };
    }
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
}

/// Result of executing a ToolFlow
class ToolFlowResult {
  /// Results from all executed steps
  final List<ToolResult> results;
  
  /// Final state after all steps completed
  final Map<String, dynamic> finalState;
  
  /// All issues collected from all steps
  final List<Issue> allIssues;

  /// Creates a ToolFlowResult
  const ToolFlowResult({
    required this.results,
    required this.finalState,
    required this.allIssues,
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

  /// Converts this result to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'results': results.map((r) => r.toJson()).toList(),
      'finalState': finalState,
      'allIssues': allIssues.map((i) => i.toJson()).toList(),
      'hasIssues': hasIssues,
    };
  }

  @override
  String toString() {
    return 'ToolFlowResult(steps: ${results.length}, issues: ${allIssues.length})';
  }
}