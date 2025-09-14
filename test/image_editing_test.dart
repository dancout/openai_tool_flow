import 'package:test/test.dart';
import 'package:openai_toolflow/openai_toolflow.dart';

/// Mock service to capture input types for testing
class MockOpenAiService implements OpenAiToolService {
  ImageEditInput? lastEditInput;
  ImageGenerationInput? lastGenerationInput;

  @override
  Future<ToolCallResponse> executeToolCall(
    ToolCallStep step,
    ToolInput input, {
    List<ToolResult> includedResults = const [],
    List<ToolResult> currentStepRetries = const [],
  }) async {
    // Capture the input types
    if (input is ImageEditInput) {
      lastEditInput = input;
    } else if (input is ImageGenerationInput) {
      lastGenerationInput = input;
    }

    // Return a mock response
    Map<String, dynamic> output;
    if (step.toolName == 'edit_image') {
      output = {
        'images': [{'url': 'test-edited-image-url.png'}],
      };
    } else if (step.toolName == 'generate_image') {
      output = {
        'images': [{'url': 'test-generated-image-url.png'}],
      };
    } else {
      output = {'result': 'test'};
    }

    return ToolCallResponse(
      output: output,
      usage: {
        'prompt_tokens': 100,
        'completion_tokens': 50,
        'total_tokens': 150,
      },
    );
  }
}

void main() {
  group('Image Editing Features', () {
    setUpAll(() {
      // Clear any existing registrations
      ToolOutputRegistry.clearRegistry();
    });

    test('should create ImageEditInput with required prompt and images', () {
      final input = ImageEditInput(
        prompt: 'Add a rainbow to this landscape',
        images: ['path/to/image.png'],
        imageModel: 'dall-e-2',
        n: 1,
        size: '1024x1024',
      );

      expect(input.prompt, equals('Add a rainbow to this landscape'));
      expect(input.images, equals(['path/to/image.png']));
      expect(input.imageModel, equals('dall-e-2'));
      expect(input.n, equals(1));
      expect(input.size, equals('1024x1024'));
    });

    test('should handle multiple images in ImageEditInput', () {
      final input = ImageEditInput(
        prompt: 'Combine these images into a collage',
        images: ['image1.png', 'image2.png', 'image3.png'],
        imageModel: 'gpt-image-1',
      );

      expect(input.images.length, equals(3));
      expect(input.images, contains('image1.png'));
      expect(input.images, contains('image2.png'));
      expect(input.images, contains('image3.png'));
    });

    test('should validate ImageEditInput correctly', () {
      // Valid input
      final validInput = ImageEditInput(
        prompt: 'A valid editing prompt',
        images: ['valid/path.png'],
        n: 1,
        quality: 'standard',
        size: '1024x1024',
      );

      final validationIssues = validInput.validate();
      expect(validationIssues, isEmpty);
    });

    test('should detect validation errors in ImageEditInput', () {
      // Empty prompt
      final emptyPromptInput = ImageEditInput(
        prompt: '',
        images: ['image.png'],
      );
      expect(emptyPromptInput.validate(), contains('prompt cannot be empty'));

      // No images
      final noImagesInput = ImageEditInput(
        prompt: 'Valid prompt',
        images: [],
      );
      expect(noImagesInput.validate(), contains('at least one image must be provided'));

      // Too many images
      final tooManyImagesInput = ImageEditInput(
        prompt: 'Valid prompt',
        images: List.generate(17, (i) => 'image$i.png'), // 17 images, max is 16
      );
      expect(tooManyImagesInput.validate(), contains('maximum 16 images allowed for gpt-image-1, 1 for dall-e-2'));

      // Invalid n value
      final invalidNInput = ImageEditInput(
        prompt: 'Valid prompt',
        images: ['image.png'],
        n: 0,
      );
      expect(invalidNInput.validate(), contains('n must be between 1 and 10'));

      // Invalid background value
      final invalidBackgroundInput = ImageEditInput(
        prompt: 'Valid prompt',
        images: ['image.png'],
        background: 'invalid',
      );
      expect(invalidBackgroundInput.validate(), contains('background must be one of: transparent, opaque, auto'));

      // Invalid quality value
      final invalidQualityInput = ImageEditInput(
        prompt: 'Valid prompt',
        images: ['image.png'],
        quality: 'invalid',
      );
      expect(invalidQualityInput.validate(), contains('quality must be one of: auto, high, medium, low, standard'));

      // Invalid size value
      final invalidSizeInput = ImageEditInput(
        prompt: 'Valid prompt',
        images: ['image.png'],
        size: 'invalid',
      );
      expect(invalidSizeInput.validate().first, contains('size must be one of:'));
    });

    test('should create ImageEditInput from Map correctly', () {
      final map = {
        'prompt': 'Edit this image',
        'images': ['image1.png', 'image2.png'],
        'model': 'dall-e-2',
        'background': 'transparent',
        'quality': 'high',
        'size': '1024x1024',
        'n': 2,
        '_round': 1,
        '_model': 'dall-e-2',
      };

      final input = ImageEditInput.fromMap(map);

      expect(input.prompt, equals('Edit this image'));
      expect(input.images, equals(['image1.png', 'image2.png']));
      expect(input.imageModel, equals('dall-e-2'));
      expect(input.background, equals('transparent'));
      expect(input.quality, equals('high'));
      expect(input.size, equals('1024x1024'));
      expect(input.n, equals(2));
      expect(input.round, equals(1));
      expect(input.model, equals('dall-e-2'));
    });

    test('should handle single image string in fromMap', () {
      final map = {
        'prompt': 'Edit this image',
        'image': 'single_image.png', // Single image as string
      };

      final input = ImageEditInput.fromMap(map);

      expect(input.images, equals(['single_image.png']));
    });

    test('should convert ImageEditInput to Map correctly', () {
      final input = ImageEditInput(
        prompt: 'Add effects to this image',
        images: ['base_image.png'],
        imageModel: 'dall-e-2',
        background: 'opaque',
        quality: 'standard',
        mask: 'mask.png',
        n: 1,
        size: '512x512',
        round: 2,
      );

      final map = input.toMap();

      expect(map['prompt'], equals('Add effects to this image'));
      expect(map['images'], equals(['base_image.png']));
      expect(map['model'], equals('dall-e-2'));
      expect(map['background'], equals('opaque'));
      expect(map['quality'], equals('standard'));
      expect(map['mask'], equals('mask.png'));
      expect(map['n'], equals(1));
      expect(map['size'], equals('512x512'));
      expect(map['_round'], equals(2));
    });

    test('should create ImageEditOutput from Map correctly', () {
      final map = {
        'created': 1234567890,
        'data': [
          {
            'url': 'https://example.com/edited_image.png',
            'revised_prompt': 'Enhanced prompt',
          },
        ],
        'usage': {
          'total_tokens': 150,
          'input_tokens': 100,
          'output_tokens': 50,
        },
      };

      final output = ImageEditOutput.fromMap(map, 1);

      expect(output.created, equals(1234567890));
      expect(output.data.length, equals(1));
      expect(output.data.first.url, equals('https://example.com/edited_image.png'));
      expect(output.data.first.revisedPrompt, equals('Enhanced prompt'));
      expect(output.usage?['total_tokens'], equals(150));
      expect(output.round, equals(1));
    });

    test('should convert ImageEditOutput to Map correctly', () {
      final imageData = ImageData(
        url: 'https://example.com/edited.png',
        revisedPrompt: 'Edited landscape with rainbow',
      );

      final output = ImageEditOutput(
        created: 1234567890,
        data: [imageData],
        usage: {'total_tokens': 100},
        round: 1,
      );

      final map = output.toMap();

      expect(map['created'], equals(1234567890));
      expect(map['data'], isA<List>());
      expect((map['data'] as List).length, equals(1));
      expect((map['data'] as List).first['url'], equals('https://example.com/edited.png'));
      expect(map['usage']['total_tokens'], equals(100));
    });

    test('should register ImageEditStepDefinition correctly', () {
      final stepDef = ImageEditStepDefinition();
      ToolOutputRegistry.registerStepDefinition(stepDef);

      expect(ToolOutputRegistry.hasTypedOutput('edit_image'), isTrue);
      expect(ToolOutputRegistry.getOutputType('edit_image'), equals(ImageEditOutput));
    });

    test('should create ToolCallStep for image editing using factory method', () {
      final step = ToolCallStep.forImageEditing(
        model: 'dall-e-2',
        stepConfig: StepConfig(maxRetries: 3),
      );

      expect(step.toolName, equals('edit_image'));
      expect(step.model, equals('dall-e-2'));
      expect(step.stepConfig.maxRetries, equals(3));
      expect(step.toolDescription, contains('Edit existing images'));
    });

    test('should create ToolCallStep for image generation using factory method', () {
      final step = ToolCallStep.forImageGeneration(
        model: 'dall-e-3',
        stepConfig: StepConfig(maxRetries: 2),
      );

      expect(step.toolName, equals('generate_image'));
      expect(step.model, equals('dall-e-3'));
      expect(step.stepConfig.maxRetries, equals(2));
      expect(step.toolDescription, contains('Generate images'));
    });

    test('should distinguish between different step types by operation', () {
      final genStep = ToolCallStep.forImageGeneration();
      final editStep = ToolCallStep.forImageEditing();
      final chatStep = ToolCallStep.forChatCompletion(TestStepDefinition());

      expect(genStep.operation, equals(ToolCallStepOperation.imageGeneration));
      expect(editStep.operation, equals(ToolCallStepOperation.imageEditing));
      expect(chatStep.operation, equals(ToolCallStepOperation.chatCompletion));
    });

    test('should handle gpt-image-1 specific parameters', () {
      final input = ImageEditInput(
        prompt: 'Edit with gpt-image-1',
        images: ['image.png'],
        imageModel: 'gpt-image-1',
        background: 'transparent',
        inputFidelity: 'high',
        outputFormat: 'webp',
        outputCompression: 85,
        partialImages: 2,
      );

      final validationIssues = input.validate();
      expect(validationIssues, isEmpty);

      final map = input.toMap();
      expect(map['background'], equals('transparent'));
      expect(map['input_fidelity'], equals('high'));
      expect(map['output_format'], equals('webp'));
      expect(map['output_compression'], equals(85));
      expect(map['partial_images'], equals(2));
    });

    test('should validate gpt-image-1 specific parameters', () {
      // Invalid input fidelity
      final invalidFidelityInput = ImageEditInput(
        prompt: 'Valid prompt',
        images: ['image.png'],
        inputFidelity: 'invalid',
      );
      expect(invalidFidelityInput.validate(), contains('input_fidelity must be high or low'));

      // Invalid output format
      final invalidFormatInput = ImageEditInput(
        prompt: 'Valid prompt',
        images: ['image.png'],
        outputFormat: 'invalid',
      );
      expect(invalidFormatInput.validate(), contains('output_format must be one of: png, jpeg, webp'));

      // Invalid output compression
      final invalidCompressionInput = ImageEditInput(
        prompt: 'Valid prompt',
        images: ['image.png'],
        outputCompression: 150, // Out of range
      );
      expect(invalidCompressionInput.validate(), contains('output_compression must be between 0 and 100'));

      // Invalid partial images
      final invalidPartialInput = ImageEditInput(
        prompt: 'Valid prompt',
        images: ['image.png'],
        partialImages: 5, // Out of range
      );
      expect(invalidPartialInput.validate(), contains('partial_images must be between 0 and 3'));
    });

    test('should create correct input type in ToolFlow based on operation type', () async {
      // Mock service to capture the input types
      final mockService = MockOpenAiService();
      
      // Create ToolFlow with image editing step
      final editFlow = ToolFlow(
        config: OpenAIConfig(apiKey: 'test-key'),
        steps: [
          ToolCallStep.forImageEditing(
            model: 'dall-e-2',
            inputBuilder: (previousResults) => {
              'prompt': 'Edit this image',
              'images': ['test.png'],
            },
          ),
        ],
        openAiService: mockService,
      );

      // Create ToolFlow with image generation step
      final genFlow = ToolFlow(
        config: OpenAIConfig(apiKey: 'test-key'),
        steps: [
          ToolCallStep.forImageGeneration(
            model: 'dall-e-3',
            inputBuilder: (previousResults) => {
              'prompt': 'Generate an image',
            },
          ),
        ],
        openAiService: mockService,
      );

      // Execute both flows and verify the input types are created correctly
      try {
        await editFlow.run(input: {});
      } catch (e) {
        // Expected to fail due to mock, but input should be created
      }

      try {
        await genFlow.run(input: {});
      } catch (e) {
        // Expected to fail due to mock, but input should be created
      }

      // Verify that the mock service received the correct input types
      expect(mockService.lastEditInput, isA<ImageEditInput>());
      expect(mockService.lastGenerationInput, isA<ImageGenerationInput>());
      
      // Verify the inputs have the expected data
      expect(mockService.lastEditInput?.prompt, equals('Edit this image'));
      expect(mockService.lastEditInput?.images, equals(['test.png']));
      expect(mockService.lastGenerationInput?.prompt, equals('Generate an image'));
    });

    test('should support custom tool names with operation types', () async {
      // Mock service to capture the input types
      final mockService = MockOpenAiService();
      
      // Create steps with custom tool names but specific operation types
      final customEditStep = ToolCallStep(
        toolName: 'my_custom_image_editor',
        operation: ToolCallStepOperation.imageEditing,
        stepConfig: StepConfig(),
        outputSchema: ImageEditStepDefinition().outputSchema,
        inputBuilder: (previousResults) => {
          'prompt': 'Custom edit prompt',
          'images': ['custom.png'],
        },
      );
      
      final customGenStep = ToolCallStep(
        toolName: 'my_custom_image_generator', 
        operation: ToolCallStepOperation.imageGeneration,
        stepConfig: StepConfig(),
        outputSchema: ImageGenerationStepDefinition().outputSchema,
        inputBuilder: (previousResults) => {
          'prompt': 'Custom generation prompt',
        },
      );

      // Register the step definitions for custom tools
      ToolOutputRegistry.register<ImageEditOutput>('my_custom_image_editor', ImageEditOutput.fromMap);
      ToolOutputRegistry.register<ImageGenerationOutput>('my_custom_image_generator', ImageGenerationOutput.fromMap);

      // Create ToolFlow with custom edit step
      final editFlow = ToolFlow(
        config: OpenAIConfig(apiKey: 'test-key'),
        steps: [customEditStep],
        openAiService: mockService,
      );

      // Create ToolFlow with custom generation step  
      final genFlow = ToolFlow(
        config: OpenAIConfig(apiKey: 'test-key'),
        steps: [customGenStep],
        openAiService: mockService,
      );

      // Execute both flows
      try {
        await editFlow.run(input: {});
      } catch (e) {
        // Expected to fail due to mock, but input should be created
      }

      try {
        await genFlow.run(input: {});
      } catch (e) {
        // Expected to fail due to mock, but input should be created
      }

      // Verify that the correct input types are created based on operation, not tool name
      expect(mockService.lastEditInput, isA<ImageEditInput>());
      expect(mockService.lastGenerationInput, isA<ImageGenerationInput>());
      
      // Verify the inputs have the expected data from custom tools
      expect(mockService.lastEditInput?.prompt, equals('Custom edit prompt'));
      expect(mockService.lastEditInput?.images, equals(['custom.png']));
      expect(mockService.lastGenerationInput?.prompt, equals('Custom generation prompt'));
    });
  });
}

/// Test step definition for chat completion testing
class TestStepDefinition extends StepDefinition<TestOutput> {
  @override
  String get stepName => 'test_tool';

  @override
  OutputSchema get outputSchema => OutputSchema(
    properties: [
      PropertyEntry.string(name: 'result', description: 'Test result'),
    ],
  );

  @override
  TestOutput fromMap(Map<String, dynamic> data, int round) =>
      TestOutput.fromMap(data, round);
}

/// Test output for chat completion testing
class TestOutput extends ToolOutput {
  final String result;

  const TestOutput({
    required this.result,
    required super.round,
  }) : super.subclass();

  factory TestOutput.fromMap(Map<String, dynamic> map, int round) {
    return TestOutput(
      result: map['result'] as String? ?? '',
      round: round,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'result': result,
    };
  }
}