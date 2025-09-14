/// Typed interfaces for OpenAI image editing functionality.
///
/// This file implements strongly-typed input and output classes for OpenAI's
/// image editing API, providing type safety and integration with the 
/// existing ToolFlow pipeline.
library;

import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:openai_toolflow/src/image_generation_interfaces.dart'; // For ImageData
import 'package:openai_toolflow/src/image_output_base.dart';
import 'package:openai_toolflow/src/image_input_base.dart';

/// Checks if the given model is an image editing model
bool isImageEditingModel(String model) {
  return model.startsWith('dall-e') || model.startsWith('gpt-image');
}

/// Input for OpenAI image editing
class ImageEditInput extends ImageInputBase {
  final List<String> images; // Array of image paths or base64 strings
  final String? background;
  final String? inputFidelity;
  final String? mask; // Path to mask file
  final int? outputCompression;
  final String? outputFormat;
  final int? partialImages;
  final bool? stream;

  const ImageEditInput({
    required super.prompt,
    required this.images,
    super.imageModel,
    this.background,
    this.inputFidelity,
    this.mask,
    super.n,
    this.outputCompression,
    this.outputFormat,
    this.partialImages,
    super.quality,
    super.responseFormat,
    super.size,
    this.stream,
    super.user,
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
    final result = <String, dynamic>{};
    
    addCommonFieldsToMap(result);
    result['images'] = images;
    
    if (background != null) result['background'] = background;
    if (inputFidelity != null) result['input_fidelity'] = inputFidelity;
    if (mask != null) result['mask'] = mask;
    if (outputCompression != null) result['output_compression'] = outputCompression;
    if (outputFormat != null) result['output_format'] = outputFormat;
    if (partialImages != null) result['partial_images'] = partialImages;
    if (stream != null) result['stream'] = stream;
    if (model != 'dall-e-2') result['_model'] = model;

    return result;
  }

  @override
  List<String> validate() {
    final issues = validateCommonFields();

    // Add editing-specific validation
    if (prompt.length > 32000) {
      issues.add('prompt cannot exceed 32000 characters for gpt-image-1, 1000 for dall-e-2');
    }

    if (images.isEmpty) {
      issues.add('at least one image must be provided');
    }

    if (images.length > 16) {
      issues.add('maximum 16 images allowed for gpt-image-1, 1 for dall-e-2');
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

    // Override common validation with more specific sizes for editing
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
class ImageEditOutput extends ImageOutputBase {
  static const String stepName = 'edit_image';

  const ImageEditOutput({
    required super.created,
    required super.data,
    super.usage,
    required super.round,
  });

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

  static OutputSchema getOutputSchema() {
    return ImageOutputBase.createImageOutputSchema(
      dataDescription: 'A list of edited image objects',
      systemMessageTemplate: 'You are an AI image editing tool that modifies existing images based on text prompts. Edit images accurately according to the provided instructions while maintaining the quality and style of the original.',
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