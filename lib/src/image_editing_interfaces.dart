/// Typed interfaces for OpenAI image editing functionality.
///
/// This file implements strongly-typed input and output classes for OpenAI's
/// image editing API, providing type safety and integration with the 
/// existing ToolFlow pipeline.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

/// Checks if the given model is an image editing model
bool isImageEditingModel(String model) {
  return model.startsWith('dall-e') || model.startsWith('gpt-image');
}

/// Input for OpenAI image editing
class ImageEditInput extends ToolInput {
  final String prompt;
  final List<String> images; // Array of image paths or base64 strings
  final String? imageModel;
  final String? background;
  final String? inputFidelity;
  final String? mask; // Path to mask file
  final int? n;
  final int? outputCompression;
  final String? outputFormat;
  final int? partialImages;
  final String? quality;
  final String? responseFormat;
  final String? size;
  final bool? stream;
  final String? user;

  const ImageEditInput({
    required this.prompt,
    required this.images,
    this.imageModel,
    this.background,
    this.inputFidelity,
    this.mask,
    this.n,
    this.outputCompression,
    this.outputFormat,
    this.partialImages,
    this.quality,
    this.responseFormat,
    this.size,
    this.stream,
    this.user,
    super.round = 0,
    super.model = 'dall-e-2',
  });

  factory ImageEditInput.fromMap(Map<String, dynamic> map) {
    final prompt = map['prompt'];
    if (prompt == null) {
      throw ArgumentError('Missing required field: prompt');
    }

    final images = map['images'] ?? map['image'];
    if (images == null) {
      throw ArgumentError('Missing required field: images');
    }

    // Handle both single image and array of images
    final imagesList = images is List 
        ? images.cast<String>() 
        : [images.toString()];

    return ImageEditInput(
      prompt: prompt as String,
      images: imagesList,
      imageModel: map['model'] as String?,
      background: map['background'] as String?,
      inputFidelity: map['input_fidelity'] as String?,
      mask: map['mask'] as String?,
      n: map['n'] as int?,
      outputCompression: map['output_compression'] as int?,
      outputFormat: map['output_format'] as String?,
      partialImages: map['partial_images'] as int?,
      quality: map['quality'] as String?,
      responseFormat: map['response_format'] as String?,
      size: map['size'] as String?,
      stream: map['stream'] as bool?,
      user: map['user'] as String?,
      round: map['_round'] as int? ?? 0,
      model: map['_model'] as String? ?? 'dall-e-2',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{
      'prompt': prompt,
      'images': images,
    };

    if (imageModel != null) result['model'] = imageModel;
    if (background != null) result['background'] = background;
    if (inputFidelity != null) result['input_fidelity'] = inputFidelity;
    if (mask != null) result['mask'] = mask;
    if (n != null) result['n'] = n;
    if (outputCompression != null) result['output_compression'] = outputCompression;
    if (outputFormat != null) result['output_format'] = outputFormat;
    if (partialImages != null) result['partial_images'] = partialImages;
    if (quality != null) result['quality'] = quality;
    if (responseFormat != null) result['response_format'] = responseFormat;
    if (size != null) result['size'] = size;
    if (stream != null) result['stream'] = stream;
    if (user != null) result['user'] = user;
    if (round > 0) result['_round'] = round;
    if (model != 'dall-e-2') result['_model'] = model;

    return result;
  }

  @override
  List<String> validate() {
    final issues = <String>[];

    if (prompt.isEmpty) {
      issues.add('prompt cannot be empty');
    }

    if (prompt.length > 32000) {
      issues.add('prompt cannot exceed 32000 characters for gpt-image-1, 1000 for dall-e-2');
    }

    if (images.isEmpty) {
      issues.add('at least one image must be provided');
    }

    if (images.length > 16) {
      issues.add('maximum 16 images allowed for gpt-image-1, 1 for dall-e-2');
    }

    if (n != null && (n! < 1 || n! > 10)) {
      issues.add('n must be between 1 and 10');
    }

    if (background != null && !['transparent', 'opaque', 'auto'].contains(background)) {
      issues.add('background must be one of: transparent, opaque, auto');
    }

    if (inputFidelity != null && !['high', 'low'].contains(inputFidelity)) {
      issues.add('input_fidelity must be high or low');
    }

    if (outputCompression != null && (outputCompression! < 0 || outputCompression! > 100)) {
      issues.add('output_compression must be between 0 and 100');
    }

    if (outputFormat != null && !['png', 'jpeg', 'webp'].contains(outputFormat)) {
      issues.add('output_format must be one of: png, jpeg, webp');
    }

    if (partialImages != null && (partialImages! < 0 || partialImages! > 3)) {
      issues.add('partial_images must be between 0 and 3');
    }

    if (quality != null && !['auto', 'high', 'medium', 'low', 'standard'].contains(quality)) {
      issues.add('quality must be one of: auto, high, medium, low, standard');
    }

    if (responseFormat != null && !['url', 'b64_json'].contains(responseFormat)) {
      issues.add('response_format must be url or b64_json');
    }

    if (size != null) {
      final validSizes = [
        '1024x1024', '1536x1024', '1024x1536', 'auto', // gpt-image-1
        '256x256', '512x512', '1024x1024', // dall-e-2
      ];
      if (!validSizes.contains(size)) {
        issues.add('size must be one of: ${validSizes.join(', ')}');
      }
    }

    return issues;
  }
}

/// Output for OpenAI image editing
class ImageEditOutput extends ToolOutput {
  static const String stepName = 'edit_image';

  final int created;
  final List<ImageData> data;
  final Map<String, dynamic>? usage;

  const ImageEditOutput({
    required this.created,
    required this.data,
    this.usage,
    required super.round,
  }) : super.subclass();

  factory ImageEditOutput.fromMap(Map<String, dynamic> map, int round) {
    final created = map['created'] as int? ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final dataList = map['data'] as List? ?? [];
    final usage = map['usage'] as Map<String, dynamic>?;

    return ImageEditOutput(
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
          description: 'A list of edited image objects',
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
          'You are an AI image editing tool that modifies existing images based on text prompts. Edit images accurately according to the provided instructions while maintaining the quality and style of the original.',
    );
  }
}

/// Step definition for image editing
class ImageEditStepDefinition extends StepDefinition<ImageEditOutput> {
  @override
  String get stepName => ImageEditOutput.stepName;

  @override
  OutputSchema get outputSchema => ImageEditOutput.getOutputSchema();

  @override
  ImageEditOutput fromMap(Map<String, dynamic> data, int round) =>
      ImageEditOutput.fromMap(data, round);
}