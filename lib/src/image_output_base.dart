/// Base class for OpenAI image operation outputs.
///
/// This file provides a common base class for image generation and editing outputs,
/// reducing code duplication while maintaining type safety.
library;

import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:openai_toolflow/src/image_generation_interfaces.dart';

/// Base class for OpenAI image operation outputs (generation and editing)
abstract class ImageOutputBase extends ToolOutput {
  final int created;
  final List<ImageData> data;
  final Map<String, dynamic>? usage;

  const ImageOutputBase({
    required this.created,
    required this.data,
    this.usage,
    required super.round,
  }) : super.subclass();

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

  /// Creates a common output schema for image operations
  static OutputSchema createImageOutputSchema({
    required String dataDescription,
    required String systemMessageTemplate,
  }) {
    return OutputSchema(
      properties: [
        PropertyEntry.number(
          name: 'created',
          description: 'The Unix timestamp (in seconds) of when the image was created',
        ),
        PropertyEntry.array(
          name: 'data',
          items: PropertyType.object,
          description: dataDescription,
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
      systemMessageTemplate: systemMessageTemplate,
    );
  }
}