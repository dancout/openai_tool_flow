import 'package:meta/meta.dart';

import 'audit_function.dart';
import 'issue.dart';
import 'openai_config.dart';
import 'tool_call_step.dart';
import 'tool_result.dart';

/// Manages ordered execution of tool call steps with internal state management.
/// 
/// The ToolFlow orchestrator:
/// - Executes steps in order
/// - Manages internal state across steps
/// - Collects issues from audits
/// - Provides structured results at the end
class ToolFlow {
  /// Configuration for OpenAI API access
  final OpenAIConfig config;
  
  /// Ordered list of tool call steps to execute
  final List<ToolCallStep> steps;
  
  /// Optional audit functions to run after each step
  final List<AuditFunction> audits;
  
  /// Internal state accumulated across steps
  final Map<String, dynamic> _state = {};
  
  /// Results from completed steps
  final List<ToolResult> _results = [];

  /// Creates a ToolFlow with configuration and steps
  ToolFlow({
    required this.config,
    required this.steps,
    this.audits = const [],
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
      try {
        final result = await _executeStep(step, i);
        _results.add(result);
        
        // Update state with step results
        _state['step_${i}_result'] = result.toJson();
        _state.addAll(result.output);
        
      } catch (e) {
        // Create an error result
        final errorResult = ToolResult(
          toolName: step.toolName,
          input: _buildStepInput(step, i),
          output: {'error': e.toString()},
          issues: [
            Issue(
              id: 'error_${step.toolName}_$i',
              severity: IssueSeverity.critical,
              description: 'Tool execution failed: $e',
              context: {
                'step': i,
                'toolName': step.toolName,
                'model': step.model,
              },
              suggestions: ['Check tool configuration and input parameters'],
            ),
          ],
        );
        _results.add(errorResult);
        break; // Stop execution on error
      }
    }

    return ToolFlowResult(
      results: List.unmodifiable(_results),
      finalState: Map.unmodifiable(_state),
      allIssues: _getAllIssues(),
    );
  }

  /// Executes a single step
  Future<ToolResult> _executeStep(ToolCallStep step, int stepIndex) async {
    final stepInput = _buildStepInput(step, stepIndex);
    
    // For now, we'll create a mock response since we don't want to make actual OpenAI calls
    // In a real implementation, this would call the OpenAI API
    final response = await _mockToolCall(step, stepInput);
    
    // Create initial result
    var result = ToolResult(
      toolName: step.toolName,
      input: stepInput,
      output: response,
      issues: [],
    );

    // Run audits on the result
    for (final audit in audits) {
      final auditIssues = audit.run(result);
      result = result.withAdditionalIssues(auditIssues);
    }

    return result;
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