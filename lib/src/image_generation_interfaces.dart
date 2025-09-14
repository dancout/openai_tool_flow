/// Typed interfaces for OpenAI image generation functionality.
///
/// This file implements strongly-typed input and output classes for OpenAI's
/// image generation API, providing type safety and integration with the 
/// existing ToolFlow pipeline.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

/// Checks if the given model is an image generation model
bool isImageGenerationModel(String model) {
  return model.startsWith('dall-e');
}

/// Input for OpenAI image generation
class ImageGenerationInput extends ToolInput {
  final String prompt;
  final String? imageModel;
  final int? n;
  final String? quality;
  final String? responseFormat;
  final String? size;
  final String? style;
  final String? user;

  const ImageGenerationInput({
    required this.prompt,
    this.imageModel,
    this.n,
    this.quality,
    this.responseFormat,
    this.size,
    this.style,
    this.user,
    super.round = 0,
    super.model = 'dall-e-3',
  });

  factory ImageGenerationInput.fromMap(Map<String, dynamic> map) {
    final prompt = map['prompt'];
    if (prompt == null) {
      throw ArgumentError('Missing required field: prompt');
    }

    return ImageGenerationInput(
      prompt: prompt as String,
      imageModel: map['model'] as String?,
      n: map['n'] as int?,
      quality: map['quality'] as String?,
      responseFormat: map['response_format'] as String?,
      size: map['size'] as String?,
      style: map['style'] as String?,
      user: map['user'] as String?,
      round: map['_round'] as int? ?? 0,
      model: map['_model'] as String? ?? 'dall-e-3',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{
      'prompt': prompt,
    };

    if (imageModel != null) result['model'] = imageModel;
    if (n != null) result['n'] = n;
    if (quality != null) result['quality'] = quality;
    if (responseFormat != null) result['response_format'] = responseFormat;
    if (size != null) result['size'] = size;
    if (style != null) result['style'] = style;
    if (user != null) result['user'] = user;
    if (round > 0) result['_round'] = round;
    if (model != 'dall-e-3') result['_model'] = model;

    return result;
  }

  @override
  List<String> validate() {
    final issues = <String>[];

    if (prompt.isEmpty) {
      issues.add('prompt cannot be empty');
    }

    if (prompt.length > 4000) {
      issues.add('prompt cannot exceed 4000 characters');
    }

    if (n != null && (n! < 1 || n! > 10)) {
      issues.add('n must be between 1 and 10');
    }

    if (quality != null && !['auto', 'hd', 'standard', 'high', 'medium', 'low'].contains(quality)) {
      issues.add('quality must be one of: auto, hd, standard, high, medium, low');
    }

    if (responseFormat != null && !['url', 'b64_json'].contains(responseFormat)) {
      issues.add('response_format must be url or b64_json');
    }

    if (size != null) {
      final validSizes = [
        '1024x1024', '1536x1024', '1024x1536', // gpt-image-1
        '256x256', '512x512', '1024x1024', // dall-e-2
        '1024x1024', '1792x1024', '1024x1792', // dall-e-3
        'auto'
      ];
      if (!validSizes.contains(size)) {
        issues.add('size must be one of: ${validSizes.join(', ')}');
      }
    }

    if (style != null && !['vivid', 'natural'].contains(style)) {
      issues.add('style must be vivid or natural');
    }

    return issues;
  }
}

/// Output for OpenAI image generation
class ImageGenerationOutput extends ToolOutput {
  static const String stepName = 'generate_image';

  final int created;
  final List<ImageData> data;
  final Map<String, dynamic>? usage;

  const ImageGenerationOutput({
    required this.created,
    required this.data,
    this.usage,
    required super.round,
  }) : super.subclass();

  factory ImageGenerationOutput.fromMap(Map<String, dynamic> map, int round) {
    final created = map['created'] as int? ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final dataList = map['data'] as List? ?? [];
    final usage = map['usage'] as Map<String, dynamic>?;

    return ImageGenerationOutput(
      created: created,
      data: dataList.map((item) => ImageData.fromMap(item as Map<String, dynamic>)).toList(),
      usage: usage,
      round: round,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{
      'created': created,
      'data': data.map((item) => item.toMap()).toList(),
    };

    if (usage != null) {
      result['usage'] = usage;
    }

    return result;
  }

  static OutputSchema getOutputSchema() {
    return OutputSchema(
      properties: [
        PropertyEntry.number(
          name: 'created',
          description: 'The Unix timestamp (in seconds) of when the image was created',
        ),
        PropertyEntry.array(
          name: 'data',
          items: PropertyType.object,
          description: 'A list of image objects',
        ),
        PropertyEntry.object(
          name: 'usage',
          description: 'Usage statistics for the request',
          properties: [
            PropertyEntry.number(
              name: 'total_tokens',
              description: 'Total tokens used in the request',
            ),
            PropertyEntry.number(
              name: 'input_tokens',
              description: 'Input tokens used in the request',
            ),
            PropertyEntry.number(
              name: 'output_tokens',
              description: 'Output tokens used in the request',
            ),
          ],
        ),
      ],
      systemMessageTemplate:
          'You are an AI image generation tool that creates images based on text prompts. Generate detailed, high-quality images that accurately reflect the given prompt.',
    );
  }
}

/// Represents a single generated image
class ImageData {
  final String? b64Json;
  final String? url;
  final String? revisedPrompt;

  const ImageData({
    this.b64Json,
    this.url,
    this.revisedPrompt,
  }) : assert(
         b64Json != null || url != null,
         'ImageData must have either b64Json or url'
       );

  factory ImageData.fromMap(Map<String, dynamic> map) {
    return ImageData(
      b64Json: map['b64_json'] as String?,
      url: map['url'] as String?,
      revisedPrompt: map['revised_prompt'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};
    
    if (b64Json != null) result['b64_json'] = b64Json;
    if (url != null) result['url'] = url;
    if (revisedPrompt != null) result['revised_prompt'] = revisedPrompt;
    
    return result;
  }
}

/// Step definition for image generation
class ImageGenerationStepDefinition extends StepDefinition<ImageGenerationOutput> {
  @override
  String get stepName => ImageGenerationOutput.stepName;

  @override
  OutputSchema get outputSchema => ImageGenerationOutput.getOutputSchema();

  @override
  ImageGenerationOutput fromMap(Map<String, dynamic> data, int round) =>
      ImageGenerationOutput.fromMap(data, round);
}