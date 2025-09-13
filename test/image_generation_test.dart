import 'package:test/test.dart';
import 'package:openai_toolflow/openai_toolflow.dart';

void main() {
  group('Image Generation Features', () {
    late OpenAIConfig config;
    late ImageGenerationStepDefinition stepDefinition;
    late ToolCallStep imageStep;

    setUpAll(() {
      // Clear any existing registrations
      ToolOutputRegistry.clearRegistry();
    });

    setUp(() {
      config = OpenAIConfig(
        apiKey: 'test-key',
        baseUrl: 'https://api.openai.com/v1',
        defaultModel: 'gpt-4',
        defaultTemperature: 0.7,
        defaultMaxTokens: 2000,
      );

      stepDefinition = ImageGenerationStepDefinition();
      imageStep = ToolCallStep.fromStepDefinition(
        stepDefinition,
        model: 'dall-e-3',
        stepConfig: StepConfig(maxRetries: 2),
      );
    });

    test('should create ImageGenerationInput with required prompt', () {
      final input = ImageGenerationInput(
        prompt: 'A beautiful sunset over mountains',
        imageModel: 'dall-e-3',
        n: 1,
        size: '1024x1024',
      );

      expect(input.prompt, equals('A beautiful sunset over mountains'));
      expect(input.imageModel, equals('dall-e-3'));
      expect(input.n, equals(1));
      expect(input.size, equals('1024x1024'));
    });

    test('should validate ImageGenerationInput correctly', () {
      // Valid input
      final validInput = ImageGenerationInput(
        prompt: 'A valid prompt',
        n: 1,
        size: '1024x1024',
      );
      expect(validInput.validate(), isEmpty);

      // Invalid inputs
      final emptyPrompt = ImageGenerationInput(prompt: '');
      expect(emptyPrompt.validate(), contains('prompt cannot be empty'));

      final tooManyImages = ImageGenerationInput(prompt: 'test', n: 15);
      expect(tooManyImages.validate(), contains('n must be between 1 and 10'));

      final invalidQuality = ImageGenerationInput(prompt: 'test', quality: 'invalid');
      expect(invalidQuality.validate(), contains('quality must be one of: auto, hd, standard, high, medium, low'));
    });

    test('should create ImageGenerationOutput from map', () {
      final map = {
        'created': 1713833628,
        'data': [
          {'b64_json': 'base64encodedimage'},
          {'url': 'https://example.com/image.png'},
        ],
        'usage': {
          'total_tokens': 100,
          'input_tokens': 50,
          'output_tokens': 50,
        },
      };

      final output = ImageGenerationOutput.fromMap(map, 0);

      expect(output.created, equals(1713833628));
      expect(output.data.length, equals(2));
      expect(output.data[0].b64Json, equals('base64encodedimage'));
      expect(output.data[1].url, equals('https://example.com/image.png'));
      expect(output.usage?['total_tokens'], equals(100));
    });

    test('should serialize ImageGenerationOutput to map', () {
      final output = ImageGenerationOutput(
        created: 1713833628,
        data: [
          ImageData(b64Json: 'base64data'),
          ImageData(url: 'https://example.com/image.png'),
        ],
        usage: {'total_tokens': 100},
        round: 0,
      );

      final map = output.toMap();

      expect(map['created'], equals(1713833628));
      expect(map['data'], isA<List>());
      expect((map['data'] as List).length, equals(2));
      expect(map['usage'], equals({'total_tokens': 100}));
    });

    test('should execute image generation with mock service', () async {
      final mockService = MockOpenAiToolService();
      
      final flow = ToolFlow(
        config: config,
        steps: [imageStep],
        openAiService: mockService,
      );

      final result = await flow.run(input: {
        'prompt': 'A majestic mountain landscape',
        'model': 'dall-e-3',
        'n': 1,
        'size': '1024x1024',
      });

      expect(result.passesCriteria, isTrue);
      expect(result.finalResults.length, equals(2)); // Initial input + image step
      
      final imageResult = result.finalResults.last;
      expect(imageResult.toolName, equals('generate_image'));
      
      final outputMap = imageResult.output.toMap();
      expect(outputMap['created'], isA<int>());
      expect(outputMap['data'], isA<List>());
    });

    test('should handle image generation in ToolFlow pipeline', () async {
      final mockService = MockOpenAiToolService();
      
      final flow = ToolFlow(
        config: config,
        steps: [imageStep],
        openAiService: mockService,
      );

      final result = await flow.run(input: {
        'prompt': 'A serene lake at dawn',
        'model': 'dall-e-3',
        'size': '1024x1024',
        'quality': 'hd',
        'style': 'natural',
      });

      expect(result.passesCriteria, isTrue);
      expect(result.allIssues, isEmpty);
      
      final imageOutput = result.finalResults.last.output as ImageGenerationOutput;
      expect(imageOutput.data, isNotEmpty);
      expect(imageOutput.created, isA<int>());
    });

    test('should register ImageGenerationStepDefinition correctly', () {
      expect(ToolOutputRegistry.hasTypedOutput('generate_image'), isTrue);
      expect(ToolOutputRegistry.getOutputType('generate_image'), equals(ImageGenerationOutput));
    });

    test('should create image step with proper schema', () {
      final schema = stepDefinition.outputSchema;
      expect(schema.properties.length, greaterThan(0));
      
      // Check for required properties
      final propertyNames = schema.properties.map((p) => p.name).toList();
      expect(propertyNames, contains('created'));
      expect(propertyNames, contains('data'));
      expect(propertyNames, contains('usage'));
    });

    test('should handle ImageData serialization', () {
      final imageData = ImageData(
        b64Json: 'base64data',
        url: 'https://example.com/image.png',
        revisedPrompt: 'Revised prompt',
      );

      final map = imageData.toMap();
      expect(map['b64_json'], equals('base64data'));
      expect(map['url'], equals('https://example.com/image.png'));
      expect(map['revised_prompt'], equals('Revised prompt'));

      final reconstructed = ImageData.fromMap(map);
      expect(reconstructed.b64Json, equals(imageData.b64Json));
      expect(reconstructed.url, equals(imageData.url));
      expect(reconstructed.revisedPrompt, equals(imageData.revisedPrompt));
    });

    test('should create ImageGenerationInput from map', () {
      final map = {
        'prompt': 'Test prompt',
        'model': 'dall-e-3',
        'n': 2,
        'quality': 'hd',
        'size': '1024x1024',
        'style': 'vivid',
        '_round': 1,
      };

      final input = ImageGenerationInput.fromMap(map);
      expect(input.prompt, equals('Test prompt'));
      expect(input.imageModel, equals('dall-e-3'));
      expect(input.n, equals(2));
      expect(input.quality, equals('hd'));
      expect(input.size, equals('1024x1024'));
      expect(input.style, equals('vivid'));
      expect(input.round, equals(1));
    });

    test('should throw error for missing prompt in fromMap', () {
      final map = {
        'model': 'dall-e-3',
        'n': 1,
      };

      expect(
        () => ImageGenerationInput.fromMap(map),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Missing required field: prompt'),
        )),
      );
    });
  });
}