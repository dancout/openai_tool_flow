/// Image generation and editing usage example.
///
/// This example demonstrates both image generation and editing functionality 
/// using OpenAI's images APIs within the ToolFlow pipeline. This is a two-step
/// workflow showcasing image generation followed by image editing capabilities.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

void main() async {
  print('🎨 OpenAI Image Generation & Editing Example');
  print('===========================================\n');

  // Create configuration - use test values if .env is not available
  late OpenAIConfig config;
  try {
    config = OpenAIConfig.fromDotEnv();
  } catch (e) {
    print(
      '⚠️  No .env file found, using test configuration for demonstration\n',
    );
    config = OpenAIConfig(
      apiKey: 'test-api-key',
      baseUrl: 'https://api.openai.com/v1',
      defaultModel: 'gpt-4',
      defaultTemperature: 0.7,
      defaultMaxTokens: 2000,
    );
  }

  // Step 1: Create image generation step using new factory method
  final imageGenerationStep = ToolCallStep.forImageGeneration(
    model: 'dall-e-3',
    stepConfig: StepConfig(maxRetries: 2, stopOnFailure: true),
  );

  // Step 2: Create image editing step that takes the generated image and modifies it
  final imageEditingStep = ToolCallStep.forImageEditing(
    model: 'dall-e-2',
    stepConfig: StepConfig(maxRetries: 2, stopOnFailure: true),
    inputBuilder: (previousResults) {
      // Get the image generated in the previous step
      final generationResult = previousResults.last;
      final generationOutput = generationResult.output.toMap();
      final imageData = generationOutput['data'] as List;
      
      // Extract the first image's URL or base64 data
      String imageSource;
      if (imageData.isNotEmpty) {
        final firstImage = imageData.first as Map<String, dynamic>;
        // For this example, we'll assume we have a URL or base64 data
        imageSource = firstImage['url'] ?? firstImage['b64_json'] ?? 'placeholder_image_path';
      } else {
        imageSource = 'placeholder_image_path';
      }
      
      return {
        'prompt': 'Add a rainbow arching over the mountain landscape',
        'images': [imageSource], // The image to edit
        'model': 'dall-e-2',
        'n': 1,
        'size': '1024x1024',
        'response_format': 'url',
      };
    },
  );

  // Create a mock service for demonstration
  // final mockService = MockOpenAiToolService();

  // Create the tool flow with both generation and editing steps
  final flow = ToolFlow(
    config: config,
    steps: [imageGenerationStep, imageEditingStep],
    // openAiService:
    //     mockService, // Use real service: DefaultOpenAiToolService(config: config)
  );

  // Execute the flow with image generation input
  try {
    print('🚀 Starting image generation and editing workflow...\n');

    final result = await flow.run(
      input: {
        'prompt':
            'A majestic mountain landscape at sunset with snow-capped peaks, reflected in a crystal-clear alpine lake, painted in impressionist style',
        'model': 'dall-e-3',
        'n': 1,
        'size': '1024x1024',
        'quality': 'hd',
        'style': 'vivid',
        'response_format': 'url',
      },
    );

    print('✅ Image generation and editing workflow completed!\n');

    // Display execution summary
    _displayExecutionSummary(result);

    // Display image generation output
    _displayImageGenerationOutput(result);

    // Display image editing output
    _displayImageEditingOutput(result);

    // Display token usage
    _displayTokenUsage(result);
  } catch (e) {
    print('❌ Image workflow failed: $e');
  }
}

/// Display execution summary
void _displayExecutionSummary(ToolFlowResult result) {
  print('📊 Execution Summary:');
  print('Successful execution: ${result.passesCriteria}');
  print('Steps executed: ${result.results.length}');
  print(
    'Tools used: ${result.finalResults.map((r) => r.toolName).join(', ')}\n',
  );
}

/// Display image generation output (Step 1)
void _displayImageGenerationOutput(ToolFlowResult result) {
  if (result.finalResults.isEmpty) return;
  
  print('🖼️ Image Generation Output (Step 1):');

  // Get the first step result (image generation)
  final imageResult = result.finalResults.first;
  final outputMap = imageResult.output.toMap();

  print('  Tool: ${imageResult.toolName}');
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
        print(
          '      Base64 data: ${b64Data.substring(0, 50)}... (${b64Data.length} characters)',
        );
      }

      if (imageData['revised_prompt'] != null) {
        print('      Revised prompt: ${imageData['revised_prompt']}');
      }
    }
  }

  print('');
}

/// Display image editing output (Step 2)
void _displayImageEditingOutput(ToolFlowResult result) {
  if (result.finalResults.length < 2) return;
  
  print('✏️ Image Editing Output (Step 2):');

  // Get the second step result (image editing)
  final editResult = result.finalResults[1];
  final outputMap = editResult.output.toMap();

  print('  Tool: ${editResult.toolName}');
  print('  Created: ${outputMap['created']}');

  final data = outputMap['data'] as List?;
  if (data != null && data.isNotEmpty) {
    print('  Edited Images: ${data.length}');

    for (int i = 0; i < data.length; i++) {
      final imageData = data[i] as Map<String, dynamic>;
      print('    Edited Image ${i + 1}:');

      if (imageData['url'] != null) {
        print('      URL: ${imageData['url']}');
      }

      if (imageData['b64_json'] != null) {
        final b64Data = imageData['b64_json'] as String;
        print(
          '      Base64 data: ${b64Data.substring(0, 50)}... (${b64Data.length} characters)',
        );
      }

      if (imageData['revised_prompt'] != null) {
        print('      Revised prompt: ${imageData['revised_prompt']}');
      }
    }
  }

  print('');
}

/// Display token usage across all steps
void _displayTokenUsage(ToolFlowResult result) {
  print('🔢 Token Usage Summary:');

  int totalPromptTokens = 0;
  int totalCompletionTokens = 0;
  int totalTokens = 0;

  for (int i = 0; i < result.finalResults.length; i++) {
    final stepResult = result.finalResults[i];
    final tokenUsage = stepResult.tokenUsage;
    
    print('  Step ${i + 1} (${stepResult.toolName}):');
    print('    Prompt tokens: ${tokenUsage.promptTokens}');
    print('    Completion tokens: ${tokenUsage.completionTokens}');
    print('    Total tokens: ${tokenUsage.totalTokens}');
    
    totalPromptTokens += tokenUsage.promptTokens;
    totalCompletionTokens += tokenUsage.completionTokens;
    totalTokens += tokenUsage.totalTokens;
  }

  print('  Overall Total:');
  print('    Prompt tokens: $totalPromptTokens');
  print('    Completion tokens: $totalCompletionTokens');
  print('    Total tokens: $totalTokens');

  print('');
}


