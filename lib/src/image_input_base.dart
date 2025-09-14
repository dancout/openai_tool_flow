/// Base class for OpenAI image operation inputs.
///
/// This file provides a common base class for image generation and editing inputs,
/// reducing code duplication while maintaining type safety.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

/// Enum to distinguish between different image operations
enum ImageOperation { 
  /// Image generation operation
  generation, 
  /// Image editing operation
  editing 
}

/// Base class for OpenAI image operation inputs (generation and editing)
abstract class ImageInputBase extends ToolInput {
  final String prompt;
  final String? imageModel;
  final int? n;
  final String? quality;
  final String? responseFormat;
  final String? size;
  final String? user;

  const ImageInputBase({
    required this.prompt,
    this.imageModel,
    this.n,
    this.quality,
    this.responseFormat,
    this.size,
    this.user,
    super.round = 0,
    required super.model,
  });

  /// Validates common fields shared between image generation and editing
  List<String> validateCommonFields() {
    final issues = <String>[];

    if (prompt.isEmpty) {
      issues.add('prompt cannot be empty');
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

    if (size != null && !['256x256', '512x512', '1024x1024', '1792x1024', '1024x1792'].contains(size)) {
      issues.add('size must be one of: 256x256, 512x512, 1024x1024, 1792x1024, 1024x1792');
    }

    return issues;
  }

  /// Helper method to add common fields to a map
  void addCommonFieldsToMap(Map<String, dynamic> result) {
    result['prompt'] = prompt;
    
    if (imageModel != null) result['model'] = imageModel;
    if (n != null) result['n'] = n;
    if (quality != null) result['quality'] = quality;
    if (responseFormat != null) result['response_format'] = responseFormat;
    if (size != null) result['size'] = size;
    if (user != null) result['user'] = user;
    if (round > 0) result['_round'] = round;
  }
}