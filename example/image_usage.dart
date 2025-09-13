/// Image generation usage example.
///
/// This example demonstrates the image generation functionality using OpenAI's
/// images/generations API within the ToolFlow pipeline. This is a single-step
/// workflow showcasing image generation capabilities.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

void main() async {
  print('🎨 OpenAI Image Generation Example');
  print('==================================\n');

  // Create configuration - use test values if .env is not available
  late OpenAIConfig config;
  try {
    config = OpenAIConfig.fromDotEnv();
  } catch (e) {
    print('⚠️  No .env file found, using test configuration for demonstration\n');
    config = OpenAIConfig(
      apiKey: 'test-api-key',
      baseUrl: 'https://api.openai.com/v1',
      defaultModel: 'gpt-4',
      defaultTemperature: 0.7,
      defaultMaxTokens: 2000,
    );
  }

  // Register the image generation step definition
  final imageStepDefinition = ImageGenerationStepDefinition();
  
  // Create a tool call step for image generation
  final imageStep = ToolCallStep.fromStepDefinition(
    imageStepDefinition,
    model: 'dall-e-3', // or 'dall-e-2' or 'gpt-image-1'
    stepConfig: StepConfig(
      maxRetries: 2,
      stopOnFailure: true,
    ),
  );

  // Create a mock service for demonstration
  final mockService = MockOpenAiToolService();

  // Create the tool flow with service injection
  final flow = ToolFlow(
    config: config,
    steps: [imageStep],
    openAiService: mockService, // Use real service: DefaultOpenAiToolService(config: config)
  );

  // Execute the flow with image generation input
  try {
    print('🚀 Starting image generation...\n');

    final result = await flow.run(
      input: {
        'prompt': 'A majestic mountain landscape at sunset with snow-capped peaks, reflected in a crystal-clear alpine lake, painted in impressionist style',
        'model': 'dall-e-3',
        'n': 1,
        'size': '1024x1024',
        'quality': 'hd',
        'style': 'vivid',
        'response_format': 'b64_json',
      },
    );

    print('✅ Image generation completed!\n');

    // Display execution summary
    _displayExecutionSummary(result);

    // Display image generation output
    _displayImageOutput(result);

    // Display token usage
    _displayTokenUsage(result);

  } catch (e) {
    print('❌ Image generation failed: $e');
  }
}

/// Display execution summary
void _displayExecutionSummary(ToolFlowResult result) {
  print('📊 Execution Summary:');
  print('Successful execution: ${result.passesCriteria}');
  print('Steps executed: ${result.results.length}');
  print('Tools used: ${result.finalResults.map((r) => r.toolName).join(', ')}\n');
}

/// Display image generation output
void _displayImageOutput(ToolFlowResult result) {
  print('🖼️ Image Generation Output:');
  
  // Get the image generation result
  final imageResult = result.finalResults.last; // Last step is image generation
  final outputMap = imageResult.output.toMap();
  
  print('  Created: ${outputMap['created']}');
  
  final data = outputMap['data'] as List?;
  if (data != null && data.isNotEmpty) {
    print('  Generated Images: ${data.length}');
    
    for (int i = 0; i < data.length; i++) {
      final imageData = data[i] as Map<String, dynamic>;
      print('    Image ${i + 1}:');
      
      if (imageData['url'] != null) {
        print('      URL: ${imageData['url']}');
      }
      
      if (imageData['b64_json'] != null) {
        final b64Data = imageData['b64_json'] as String;
        print('      Base64 data: ${b64Data.substring(0, 50)}... (${b64Data.length} characters)');
      }
      
      if (imageData['revised_prompt'] != null) {
        print('      Revised prompt: ${imageData['revised_prompt']}');
      }
    }
  }
  
  // Display usage information if available
  final usage = outputMap['usage'] as Map<String, dynamic>?;
  if (usage != null) {
    print('  Usage Statistics:');
    if (usage['total_tokens'] != null) {
      print('    Total tokens: ${usage['total_tokens']}');
    }
    if (usage['input_tokens'] != null) {
      print('    Input tokens: ${usage['input_tokens']}');
    }
    if (usage['output_tokens'] != null) {
      print('    Output tokens: ${usage['output_tokens']}');
    }
  }
  
  print('');
}

/// Display token usage
void _displayTokenUsage(ToolFlowResult result) {
  print('🔢 Token Usage:');
  
  // Get token usage from the final result
  final imageResult = result.finalResults.last;
  final tokenUsage = imageResult.tokenUsage;
  
  print('  Prompt tokens: ${tokenUsage.promptTokens}');
  print('  Completion tokens: ${tokenUsage.completionTokens}');
  print('  Total tokens: ${tokenUsage.totalTokens}');
  
  print('');
}

/// Example of creating an image generation input with validation
ImageGenerationInput createImageInput({
  required String prompt,
  String? imageModel,
  int? n,
  String? quality,
  String? size,
  String? style,
}) {
  final input = ImageGenerationInput(
    prompt: prompt,
    imageModel: imageModel ?? 'dall-e-3',
    n: n ?? 1,
    quality: quality ?? 'standard',
    size: size ?? '1024x1024',
    style: style ?? 'vivid',
    responseFormat: 'b64_json',
  );
  
  // Validate the input
  final validationIssues = input.validate();
  if (validationIssues.isNotEmpty) {
    throw ArgumentError('Invalid input: ${validationIssues.join(', ')}');
  }
  
  return input;
}

/// Example of a multi-step workflow that uses image generation
/// This could be extended to first generate an image and then analyze it
void exampleMultiStepWithImage() {
  print('Example: Multi-step workflow with image generation');
  print('This could include:');
  print('1. Generate image based on prompt');
  print('2. Analyze the generated image');
  print('3. Provide feedback or modifications');
  print('');
}