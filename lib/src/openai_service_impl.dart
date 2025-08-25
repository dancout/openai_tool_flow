import 'dart:convert';

import 'package:http/http.dart' as http;

import 'openai_config.dart';
import 'openai_service.dart';
import 'tool_call_step.dart';

/// Default implementation of OpenAiToolService that makes actual API calls.
class DefaultOpenAiToolService implements OpenAiToolService {
  /// OpenAI configuration for API access
  final OpenAIConfig config;

  /// HTTP client for making requests
  final http.Client? _httpClient;

  DefaultOpenAiToolService({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  @override
  Future<Map<String, dynamic>> executeToolCall(
    ToolCallStep step,
    Map<String, dynamic> input,
  ) async {
    final client = _httpClient ?? http.Client();

    try {
      // Build the OpenAI request
      final request = _buildOpenAiRequest(step, input);

      final response = await client.post(
        Uri.parse('${config.baseUrl}/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'OpenAI API error: ${response.statusCode} - ${response.body}',
        );
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      // Extract tool call result from OpenAI response
      return _extractToolCallResult(responseData, step.toolName);
    } finally {
      if (_httpClient == null) {
        // Only close if we created the client
        client.close();
      }
    }
  }

  /// Builds the OpenAI request from step and input
  OpenAiRequest _buildOpenAiRequest(
    ToolCallStep step,
    Map<String, dynamic> input,
  ) {
    // Create tool definition
    final toolDefinition = _buildToolDefinition(step, input);

    // Build system message
    final systemMessageInput = SystemMessageInput(
      toolFlowContext: 'Executing tool call in a structured workflow',
      stepDescription: 'Tool: ${step.toolName}, Model: ${step.model}',
      previousResults: _extractPreviousResults(input),
      relevantIssues: _extractRelevantIssues(input),
      additionalContext: {
        'step_tool': step.toolName,
        'step_model': step.model,
      },
    );

    // Build user message
    final userMessageInput = UserMessageInput(
      toolInput: input,
      instructions: 'Execute the ${step.toolName} tool with the provided parameters.',
      outputFormat: 'Return structured JSON output matching the tool schema.',
    );

    final systemMessage = _buildSystemMessage(systemMessageInput);
    final userMessage = _buildUserMessage(userMessageInput);

    return OpenAiRequest.forModel(
      model: step.model,
      systemMessage: systemMessage,
      userMessage: userMessage,
      tools: [toolDefinition],
      toolChoice: {
        'type': 'function',
        'function': {'name': step.toolName},
      },
      temperature: config.defaultTemperature,
      maxTokens: config.defaultMaxTokens,
    );
  }

  /// Builds tool definition for OpenAI
  Map<String, dynamic> _buildToolDefinition(
    ToolCallStep step,
    Map<String, dynamic> input,
  ) {
    return {
      'type': 'function',
      'function': {
        'name': step.toolName,
        'description': 'Execute ${step.toolName} tool with provided parameters',
        'parameters': {
          'type': 'object',
          'properties': _buildParameterSchema(step, input),
          'required': _getRequiredParameters(step, input),
        },
      },
    };
  }

  /// Builds parameter schema based on step configuration and input
  Map<String, dynamic> _buildParameterSchema(
    ToolCallStep step,
    Map<String, dynamic> input,
  ) {
    final schema = <String, dynamic>{};

    // Add parameters from step configuration
    for (final key in step.params.keys) {
      schema[key] = {
        'type': _inferParameterType(step.params[key]),
        'description': 'Parameter $key for ${step.toolName}',
      };
    }

    // Add parameters from input (excluding internal ones)
    for (final key in input.keys) {
      if (!key.startsWith('_') && !schema.containsKey(key)) {
        schema[key] = {
          'type': _inferParameterType(input[key]),
          'description': 'Input parameter $key',
        };
      }
    }

    return schema;
  }

  /// Infers the JSON schema type from a Dart value
  String _inferParameterType(dynamic value) {
    if (value is String) return 'string';
    if (value is int) return 'integer';
    if (value is double) return 'number';
    if (value is bool) return 'boolean';
    if (value is List) return 'array';
    if (value is Map) return 'object';
    return 'string'; // Default fallback
  }

  /// Gets required parameters from step configuration
  List<String> _getRequiredParameters(
    ToolCallStep step,
    Map<String, dynamic> input,
  ) {
    // For now, treat all non-internal parameters as required
    final required = <String>[];
    
    // Add step parameters
    required.addAll(step.params.keys);
    
    // Add input parameters (excluding internal ones)
    for (final key in input.keys) {
      if (!key.startsWith('_') && !required.contains(key)) {
        required.add(key);
      }
    }
    
    return required;
  }

  /// Builds system message from structured input
  String _buildSystemMessage(SystemMessageInput input) {
    final buffer = StringBuffer();
    
    buffer.writeln('You are an AI assistant executing tool calls in a structured workflow.');
    buffer.writeln();
    buffer.writeln('Context: ${input.toolFlowContext}');
    buffer.writeln('Current Step: ${input.stepDescription}');
    
    if (input.previousResults.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Previous step results:');
      for (int i = 0; i < input.previousResults.length; i++) {
        final result = input.previousResults[i];
        buffer.writeln('  Step ${i + 1}: ${result['toolName']} -> ${result['output']?.keys?.join(', ') ?? 'unknown'}');
      }
    }
    
    if (input.relevantIssues.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Issues from previous steps to consider:');
      for (final issue in input.relevantIssues) {
        buffer.writeln('  - ${issue['severity']}: ${issue['description']}');
        if (issue['suggestions'] != null && (issue['suggestions'] as List).isNotEmpty) {
          buffer.writeln('    Suggestions: ${(issue['suggestions'] as List).join(', ')}');
        }
      }
    }
    
    if (input.additionalContext.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Additional context: ${input.additionalContext}');
    }

    return buffer.toString();
  }

  /// Builds user message from structured input
  String _buildUserMessage(UserMessageInput input) {
    final buffer = StringBuffer();
    
    buffer.writeln('Please execute the tool with the following parameters:');
    buffer.writeln();
    buffer.writeln(jsonEncode(input.getCleanToolInput()));
    
    if (input.instructions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Instructions: ${input.instructions}');
    }
    
    if (input.outputFormat.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Output format: ${input.outputFormat}');
    }
    
    if (input.constraints.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Constraints:');
      for (final constraint in input.constraints) {
        buffer.writeln('  - $constraint');
      }
    }

    return buffer.toString();
  }

  /// Extracts previous results from input for context
  List<Map<String, dynamic>> _extractPreviousResults(Map<String, dynamic> input) {
    final results = <Map<String, dynamic>>[];
    
    // Look for step results in the input
    for (final key in input.keys) {
      if (key.startsWith('step_') && key.endsWith('_result')) {
        final result = input[key];
        if (result is Map<String, dynamic>) {
          results.add(result);
        }
      }
    }
    
    return results;
  }

  /// Extracts relevant issues from input
  List<Map<String, dynamic>> _extractRelevantIssues(Map<String, dynamic> input) {
    final issues = <Map<String, dynamic>>[];
    
    final previousIssues = input['_previous_issues'];
    if (previousIssues is List) {
      for (final issue in previousIssues) {
        if (issue is Map<String, dynamic>) {
          issues.add(issue);
        }
      }
    }
    
    return issues;
  }

  /// Extracts tool call result from OpenAI response
  Map<String, dynamic> _extractToolCallResult(
    Map<String, dynamic> response,
    String expectedToolName,
  ) {
    try {
      final choices = response['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('No choices in OpenAI response');
      }

      final firstChoice = choices.first as Map<String, dynamic>;
      final message = firstChoice['message'] as Map<String, dynamic>?;
      if (message == null) {
        throw Exception('No message in OpenAI response choice');
      }

      final toolCalls = message['tool_calls'] as List?;
      if (toolCalls == null || toolCalls.isEmpty) {
        throw Exception('No tool calls in OpenAI response');
      }

      final toolCall = toolCalls.first as Map<String, dynamic>;
      final function = toolCall['function'] as Map<String, dynamic>?;
      if (function == null) {
        throw Exception('No function in OpenAI tool call');
      }

      final functionName = function['name'] as String?;
      if (functionName != expectedToolName) {
        throw Exception(
          'Expected tool $expectedToolName but got $functionName',
        );
      }

      final argumentsString = function['arguments'] as String?;
      if (argumentsString == null) {
        throw Exception('No arguments in OpenAI function call');
      }

      final arguments = jsonDecode(argumentsString) as Map<String, dynamic>;
      return arguments;
    } catch (e) {
      throw Exception('Failed to parse OpenAI response: $e');
    }
  }
}

/// Mock implementation of OpenAiToolService for testing.
///
/// Returns predefined responses without making actual API calls.
class MockOpenAiToolService implements OpenAiToolService {
  /// Predefined responses for different tool names
  final Map<String, Map<String, dynamic>> responses;

  /// Default response to use if no specific response is configured
  final Map<String, dynamic> defaultResponse;

  MockOpenAiToolService({
    this.responses = const {},
    this.defaultResponse = const {
      'message': 'Mock tool executed successfully',
      'mock': true,
    },
  });

  @override
  Future<Map<String, dynamic>> executeToolCall(
    ToolCallStep step,
    Map<String, dynamic> input,
  ) async {
    // Simulate some processing time
    await Future.delayed(const Duration(milliseconds: 100));

    // Return predefined response if available
    if (responses.containsKey(step.toolName)) {
      final response = Map<String, dynamic>.from(responses[step.toolName]!);
      
      // Add input information for testing
      response['_mock_input_received'] = input.keys.toList();
      response['_mock_model_used'] = step.model;
      
      return response;
    }

    // Return default response with some input context
    final response = Map<String, dynamic>.from(defaultResponse);
    response['toolName'] = step.toolName;
    response['inputKeys'] = input.keys.toList();
    response['model'] = step.model;
    
    return response;
  }
}