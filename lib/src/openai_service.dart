import 'package:openai_toolflow/src/typed_interfaces.dart';

import 'tool_call_step.dart';
import 'tool_result.dart';

/// Response from OpenAI tool call execution containing both output and usage information
class ToolCallResponse {
  /// The tool output data
  final Map<String, dynamic> output;

  /// Token usage information from the OpenAI response
  final Map<String, dynamic> usage;

  const ToolCallResponse({
    required this.output,
    required this.usage,
  });
}

/// Abstract interface for OpenAI tool execution services.
///
/// This abstraction allows for different implementations (real API calls, mocking, etc.)
/// and enables dependency injection for testing.
abstract class OpenAiToolService {
  /// Executes a tool call with the given step and input parameters.
  ///
  /// Returns both the tool output and usage information from the OpenAI response.
  ///
  /// [includedResults] contains previous results and their filtered issues to include
  /// in the system message for context about previous attempts and problems.
  /// [currentStepRetries] contains retry attempts from the current step with filtered issues.
  Future<ToolCallResponse> executeToolCall(
    ToolCallStep step,
    ToolInput input, {
    List<ToolResult> includedResults = const [],
    List<ToolResult> currentStepRetries = const [],
  });
}

/// Structured request for OpenAI API calls.
///
/// Handles model-specific parameter differences and provides type safety.
class OpenAiRequest {
  /// OpenAI model to use for the request
  final String model;

  /// System message for the conversation
  final String systemMessage;

  /// User message for the conversation
  final String userMessage;

  /// Tool definitions for the request
  final List<Map<String, dynamic>> tools;

  /// Tool choice specification
  final Map<String, dynamic> toolChoice;

  /// Temperature parameter (not supported in GPT-5+)
  final double? temperature;

  /// Max tokens for older models
  final int? maxTokens;

  /// Max completion tokens for newer models (GPT-5+)
  final int? maxCompletionTokens;

  /// Additional parameters for the request
  final Map<String, dynamic> additionalParams;

  const OpenAiRequest({
    required this.model,
    required this.systemMessage,
    required this.userMessage,
    required this.tools,
    required this.toolChoice,
    this.temperature,
    this.maxTokens,
    this.maxCompletionTokens,
    this.additionalParams = const {},
  });

  /// Creates an OpenAI request with model-specific parameter handling.
  ///
  /// Automatically handles differences between model generations:
  /// - GPT-5+ models: Use max_completion_tokens, no temperature
  /// - Older models: Use max_tokens and temperature
  factory OpenAiRequest.forModel({
    required String model,
    required String systemMessage,
    required String userMessage,
    required List<Map<String, dynamic>> tools,
    required Map<String, dynamic> toolChoice,
    double? temperature,
    int? maxTokens,
    Map<String, dynamic> additionalParams = const {},
  }) {
    final isGpt5Plus =
        model.toLowerCase().contains('gpt-5') ||
        model.toLowerCase().contains('o1') ||
        model.toLowerCase().contains('o3');

    if (isGpt5Plus) {
      // GPT-5+ models don't support temperature and use max_completion_tokens
      return OpenAiRequest(
        model: model,
        systemMessage: systemMessage,
        userMessage: userMessage,
        tools: tools,
        toolChoice: toolChoice,
        maxCompletionTokens: maxTokens ?? 2000,
        additionalParams: additionalParams,
      );
    } else {
      // Older models use temperature and max_tokens
      return OpenAiRequest(
        model: model,
        systemMessage: systemMessage,
        userMessage: userMessage,
        tools: tools,
        toolChoice: toolChoice,
        temperature: temperature ?? 0.7,
        maxTokens: maxTokens ?? 2000,
        additionalParams: additionalParams,
      );
    }
  }

  /// Converts this request to the JSON payload for OpenAI API
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemMessage},
        {'role': 'user', 'content': userMessage},
      ],
      'tools': tools,
      'tool_choice': toolChoice,
    };

    // Add model-specific parameters
    if (temperature != null) {
      json['temperature'] = temperature;
    }
    if (maxTokens != null) {
      json['max_tokens'] = maxTokens;
    }
    if (maxCompletionTokens != null) {
      json['max_completion_tokens'] = maxCompletionTokens;
    }

    // Add any additional parameters
    json.addAll(additionalParams);

    return json;
  }
}

/// Strongly-typed input for system message building
class SystemMessageInput {
  /// Context about the tool flow and current step
  final String toolFlowContext;

  /// Current step information
  final String stepDescription;

  /// Previous step results with filtered issues relevant to this step
  final List<ToolResult> previousResults;

  /// Current step retry attempts with filtered issues (excluding the final attempt)
  final List<ToolResult> currentStepRetries;

  /// Additional context data
  final Map<String, dynamic> additionalContext;

  const SystemMessageInput({
    required this.toolFlowContext,
    required this.stepDescription,
    this.previousResults = const [],
    this.currentStepRetries = const [],
    this.additionalContext = const {},
  });

  /// Converts to a clean map for serialization
  Map<String, dynamic> toMap() {
    return {
      'toolFlowContext': toolFlowContext,
      'stepDescription': stepDescription,
      'previousResults': previousResults
          .map((result) => result.toJson())
          .toList(),
      'currentStepRetries': currentStepRetries
          .map((result) => result.toJson())
          .toList(),
      'additionalContext': additionalContext,
    };
  }
}
