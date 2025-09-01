import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openai_toolflow/src/typed_interfaces.dart';

import 'openai_config.dart';
import 'openai_service.dart';
import 'tool_call_step.dart';

/// Default implementation of OpenAiToolService that makes actual API calls.
class DefaultOpenAiToolService implements OpenAiToolService {
  /// OpenAI configuration for API access
  final OpenAIConfig config;

  /// HTTP client for making requests
  final http.Client? _httpClient;

  DefaultOpenAiToolService({required this.config, http.Client? httpClient})
    : _httpClient = httpClient;

  @override
  Future<Map<String, dynamic>> executeToolCall(
    ToolCallStep step,
    ToolInput input,
  ) async {
    final client = _httpClient ?? http.Client();

    try {
      // Build the OpenAI request
      final request = _buildOpenAiRequest(step: step, input: input);

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
  OpenAiRequest _buildOpenAiRequest({
    required ToolCallStep step,
    required ToolInput input,
  }) {
    // Create tool definition
    final toolDefinition = _buildToolDefinition(step: step, input: input);

    // previousResults removed from ToolInput; pass workflow context to inputBuilder and messaging as needed
    final systemMessageInput = SystemMessageInput(
      toolFlowContext: 'Executing tool call in a structured workflow',
      stepDescription: 'Tool: ${step.toolName}, Model: ${step.model}',
      previousResults: [], // No previousResults on ToolInput
      additionalContext: {'step_tool': step.toolName, 'step_model': step.model},
    );

    // Build user message
    final userMessageInput = UserMessageInput(
      toolInput: input,
      instructions:
          'Execute the ${step.toolName} tool with the provided parameters.',
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
  Map<String, dynamic> _buildToolDefinition({
    required ToolCallStep step,
    required ToolInput input,
  }) {
    return {
      'type': 'function',
      'function': {
        'name': step.toolName,
        'description': 'Execute ${step.toolName} tool with provided parameters',
        'parameters': step.stepConfig.getEffectiveOutputSchema(step.toolName).toMap(),
      },
      "strict": true,
    };
  }

  /// Builds system message from structured input
  String _buildSystemMessage(SystemMessageInput input) {
    final buffer = StringBuffer();

    buffer.writeln(
      'You are an AI assistant executing tool calls in a structured workflow.',
    );
    buffer.writeln();
    buffer.writeln('Context: ${input.toolFlowContext}');
    buffer.writeln('Current Step: ${input.stepDescription}');

    // previousResults logic removed; handle workflow context in inputBuilder and messaging as needed

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
    ToolInput input,
  ) async {
    // Simulate some processing time
    await Future.delayed(const Duration(milliseconds: 100));
    final inputJson = input.toMap();

    // Return predefined response if available
    if (responses.containsKey(step.toolName)) {
      final response = Map<String, dynamic>.from(responses[step.toolName]!);

      // Add input information for testing
      response['_mock_input_received'] = inputJson.keys.toList();
      response['_mock_model_used'] = step.model;

      return response;
    }

    // Return default response with some input context
    final response = Map<String, dynamic>.from(defaultResponse);
    response['toolName'] = step.toolName;
    response['inputKeys'] = inputJson.keys.toList();
    response['model'] = step.model;

    return response;
  }
}
