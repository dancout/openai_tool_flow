import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openai_toolflow/src/typed_interfaces.dart';
import 'package:openai_toolflow/src/image_generation_interfaces.dart';

import 'openai_config.dart';
import 'openai_service.dart';
import 'tool_call_step.dart';
import 'tool_result.dart';

/// Default implementation of OpenAiToolService that makes actual API calls.
class DefaultOpenAiToolService implements OpenAiToolService {
  /// OpenAI configuration for API access
  final OpenAIConfig config;

  /// HTTP client for making requests
  final http.Client? _httpClient;

  DefaultOpenAiToolService({required this.config, http.Client? httpClient})
    : _httpClient = httpClient;

  @override
  Future<ToolCallResponse> executeToolCall(
    ToolCallStep step,
    ToolInput input, {
    List<ToolResult> includedResults = const [],
    List<ToolResult> currentStepRetries = const [],
  }) async {
    final client = _httpClient ?? http.Client();

    try {
      // Check if this is an image generation request based on model
      if (_isImageGenerationModel(input.model)) {
        return await _executeImageGeneration(
          step: step,
          input: input,
          client: client,
        );
      }

      // Standard tool call handling for chat completions
      final request = _buildOpenAiRequest(
        step: step,
        input: input,
        includedResults: includedResults,
        currentStepRetries: currentStepRetries,
      );

      final requestJson = request.toJson();
      final response = await client.post(
        Uri.parse('${config.baseUrl}/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestJson),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'OpenAI API error: ${response.statusCode} - ${response.body}',
        );
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      // Extract tool call result and usage from OpenAI response
      final toolOutput = _extractToolCallResult(responseData, step.toolName);
      final usage = responseData['usage'] as Map<String, dynamic>? ?? {};

      return ToolCallResponse(output: toolOutput, usage: usage);
    } catch (e) {
      throw Exception('Failed to execute tool call: $e');
    } finally {
      if (_httpClient == null) {
        // Only close if we created the client
        client.close();
      }
    }
  }

  /// Checks if the given model is an image generation model
  bool _isImageGenerationModel(String model) {
    return model.startsWith('dall-e');
  }

  /// Executes an image generation request using OpenAI's images API
  Future<ToolCallResponse> _executeImageGeneration({
    required ToolCallStep step,
    required ToolInput input,
    required http.Client client,
  }) async {
    try {
      // Build image generation request from input
      final imageRequest = _buildImageGenerationRequest(input);
      
      final response = await client.post(
        Uri.parse('${config.baseUrl}/images/generations'),
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(imageRequest),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'OpenAI Images API error: ${response.statusCode} - ${response.body}',
        );
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      
      // The image generation API returns the data directly, not wrapped in a tool call
      final usage = responseData['usage'] as Map<String, dynamic>? ?? {};
      
      // Remove usage from response data to create clean output
      final outputData = Map<String, dynamic>.from(responseData);
      
      return ToolCallResponse(output: outputData, usage: usage);
    } catch (e) {
      // Re-throw the exception to be handled by the calling code
      throw Exception('Failed to execute image generation: $e');
    } finally {
      if (_httpClient == null) {
        // Only close if we created the client
        client.close();
      }
    }
  }

  /// Builds an image generation request from ToolInput
  Map<String, dynamic> _buildImageGenerationRequest(ToolInput input) {
    // If we have a strongly typed ImageGenerationInput, use its properties directly
    if (input is ImageGenerationInput) {
      final request = <String, dynamic>{
        'prompt': input.prompt,
      };
      
      // Add optional fields if they are set
      if (input.imageModel != null) request['model'] = input.imageModel;
      if (input.n != null) request['n'] = input.n;
      if (input.quality != null) request['quality'] = input.quality;
      if (input.responseFormat != null) request['response_format'] = input.responseFormat;
      if (input.size != null) request['size'] = input.size;
      if (input.style != null) request['style'] = input.style;
      if (input.user != null) request['user'] = input.user;
      
      return request;
    }
    
    // Fallback to generic map-based approach for backward compatibility
    final inputData = input.getCleanToolInput();
    final request = <String, dynamic>{};

    // Required field
    final prompt = inputData['prompt'];
    if (prompt == null) {
      throw Exception('prompt is required for image generation');
    }
    request['prompt'] = prompt;

    // Optional fields - use the actual model field names from the image API
    if (inputData['model'] != null) request['model'] = inputData['model'];
    if (inputData['n'] != null) request['n'] = inputData['n'];
    if (inputData['quality'] != null) request['quality'] = inputData['quality'];
    if (inputData['response_format'] != null) request['response_format'] = inputData['response_format'];
    if (inputData['size'] != null) request['size'] = inputData['size'];
    if (inputData['style'] != null) request['style'] = inputData['style'];
    if (inputData['user'] != null) request['user'] = inputData['user'];

    return request;
  }

  /// Builds the OpenAI request from step and input
  OpenAiRequest _buildOpenAiRequest({
    required ToolCallStep step,
    required ToolInput input,
    List<ToolResult> includedResults = const [],
    List<ToolResult> currentStepRetries = const [],
  }) {
    // Create tool definition
    final toolDefinition = _buildToolDefinition(step: step, input: input);

    // Build system message directly instead of using complex SystemMessageInput
    final systemMessage = _buildSystemMessage(
      step: step,
      previousResults: includedResults,
      currentStepRetries: currentStepRetries,
    );
    final userMessage = _buildUserMessage(input);

    return OpenAiRequest.forModel(
      model: step.model ?? config.defaultModel,
      systemMessage: systemMessage,
      userMessage: userMessage,
      tools: [toolDefinition],
      toolChoice: {
        'type': 'function',
        'function': {'name': step.toolName},
      },
      temperature: config.defaultTemperature,
      maxTokens: step.stepConfig.maxTokens ?? config.defaultMaxTokens,
    );
  }

  /// Builds tool definition for OpenAI
  Map<String, dynamic> _buildToolDefinition({
    required ToolCallStep step,
    required ToolInput input,
  }) {
    // Use tool description from step if available, otherwise fallback to generic description
    final description =
        step.toolDescription ??
        'Execute ${step.toolName} tool with provided parameters';

    return {
      'type': 'function',
      'function': {
        'name': step.toolName,
        'description': description,
        'parameters': step.outputSchema.toMap(),
        "strict": true,
      },
    };
  }

  /// Builds system message with step context and results
  String _buildSystemMessage({
    required ToolCallStep step,
    required List<ToolResult> previousResults,
    required List<ToolResult> currentStepRetries,
  }) {
    final buffer = StringBuffer();

    // Use system message template from step if available
    final systemMessageTemplate = step.outputSchema.systemMessageTemplate;

    if (systemMessageTemplate?.isNotEmpty == true) {
      buffer.writeln(systemMessageTemplate);
    } else {
      // Fallback to original behavior
      buffer.writeln(
        'You are an AI assistant executing tool calls in a structured workflow.',
      );
    }

    // Include previous results and their associated issues if provided
    if (previousResults.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Previous step results and associated issues:');
      for (int i = 0; i < previousResults.length; i++) {
        final result = previousResults[i];
        buffer.writeln('  Step: ${result.toolName}');
        buffer.writeln('    Output: ${jsonEncode(result.output.toMap())}');

        // Include issues associated with this specific result
        if (result.auditResults.issues.isNotEmpty) {
          buffer.writeln('    Associated issues:');
          for (final issue in result.auditResults.issues) {
            buffer.writeln(
              '      - ${issue.severity.name.toUpperCase()}: ${issue.description}',
            );
            if (issue.suggestions.isNotEmpty) {
              buffer.writeln(
                '        Suggestions: ${issue.suggestions.join(', ')}',
              );
            }
          }
        }
      }
    }

    // Include current step retry attempts and their associated issues if provided
    if (currentStepRetries.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Current step retry attempts and associated issues:');
      for (int i = 0; i < currentStepRetries.length; i++) {
        final result = currentStepRetries[i];
        buffer.writeln('  Attempt ${i + 1}: ${result.toolName}');
        buffer.writeln('    Output: ${jsonEncode(result.output.toMap())}');

        // Include issues associated with this specific retry attempt
        if (result.auditResults.issues.isNotEmpty) {
          buffer.writeln('    Associated issues:');
          for (final issue in result.auditResults.issues) {
            buffer.writeln(
              '      - ${issue.severity.name.toUpperCase()}: ${issue.description}',
            );
            if (issue.suggestions.isNotEmpty) {
              buffer.writeln(
                '        Suggestions: ${issue.suggestions.join(', ')}',
              );
            }
          }
        }
      }
    }

    return buffer.toString();
  }

  /// Builds user message from structured input
  String _buildUserMessage(ToolInput input) {
    final buffer = StringBuffer();

    buffer.writeln(jsonEncode(input.getCleanToolInput()));

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
        final finishReason = firstChoice['finish_reason'] as String?;
        if (finishReason == 'length') {
          throw Exception(
            'OpenAI Tool Call ran out of available completion tokens.',
          );
        }
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

      try {
        final arguments = jsonDecode(argumentsString) as Map<String, dynamic>;
        return arguments;
      } catch (e) {
        throw Exception(
          'Failed to decode argumentsString: \'$argumentsString\'. Error: $e',
        );
      }
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
  Future<ToolCallResponse> executeToolCall(
    ToolCallStep step,
    ToolInput input, {
    List<ToolResult> includedResults = const [],
    List<ToolResult> currentStepRetries = const [],
  }) async {
    final inputJson = input.toMap();

    // Special handling for image generation based on model
    if (_isImageGenerationModel(input.model)) {
      return _mockImageGeneration(input);
    }

    // Return predefined response if available
    if (responses.containsKey(step.toolName)) {
      final response = Map<String, dynamic>.from(responses[step.toolName]!);

      // Add input information for testing
      response['_mock_input_received'] = inputJson.keys.toList();
      response['_mock_model_used'] = step.model ?? 'mock-model';

      return ToolCallResponse(
        output: response,
        usage: {
          'prompt_tokens': 100,
          'completion_tokens': 50,
          'total_tokens': 150,
          'prompt_tokens_details': {'cached_tokens': 0, 'audio_tokens': 0},
          'completion_tokens_details': {
            'reasoning_tokens': 0,
            'audio_tokens': 0,
            'accepted_prediction_tokens': 0,
            'rejected_prediction_tokens': 0,
          },
        },
      );
    }

    // Return default response with some input context
    final response = Map<String, dynamic>.from(defaultResponse);
    response['toolName'] = step.toolName;
    response['inputKeys'] = inputJson.keys.toList();
    response['model'] = step.model ?? 'mock-model';

    return ToolCallResponse(
      output: response,
      usage: {
        'prompt_tokens': 100,
        'completion_tokens': 50,
        'total_tokens': 150,
        'prompt_tokens_details': {'cached_tokens': 0, 'audio_tokens': 0},
        'completion_tokens_details': {
          'reasoning_tokens': 0,
          'audio_tokens': 0,
          'accepted_prediction_tokens': 0,
          'rejected_prediction_tokens': 0,
        },
      },
    );
  }

  /// Checks if the given model is an image generation model
  bool _isImageGenerationModel(String model) {
    return model.startsWith('dall-e');
  }

  /// Mock image generation response
  ToolCallResponse _mockImageGeneration(ToolInput input) {
    final inputData = input.getCleanToolInput();
    final prompt = inputData['prompt'] as String? ?? 'default prompt';
    
    return ToolCallResponse(
      output: {
        'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'data': [
          {
            'b64_json': 'mock_base64_encoded_image_data_for_prompt_${prompt.replaceAll(' ', '_')}',
          },
        ],
      },
      usage: {
        'total_tokens': 100,
        'input_tokens': 50,
        'output_tokens': 50,
        'input_tokens_details': {
          'text_tokens': 10,
          'image_tokens': 40,
        },
      },
    );
  }
}
