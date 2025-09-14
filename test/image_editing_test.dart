import 'package:test/test.dart';
import 'package:openai_toolflow/openai_toolflow.dart';

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

    test('should distinguish between different step types by tool name', () {
      final genStep = ToolCallStep.forImageGeneration();
      final editStep = ToolCallStep.forImageEditing();
      final chatStep = ToolCallStep.forChatCompletion(TestStepDefinition());

      expect(genStep.toolName, equals('generate_image'));
      expect(editStep.toolName, equals('edit_image'));
      expect(chatStep.toolName, equals('test_tool'));
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