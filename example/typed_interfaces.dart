/// Concrete implementations of typed tool interfaces.
///
/// This file demonstrates how to create strongly-typed input and output classes
/// for tool calls, providing better type safety and IDE support.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

/// Example concrete implementation for palette extraction input
class PaletteExtractionInput extends ToolInput {
  final String imagePath;
  final int maxColors;
  final double minSaturation;
  final Map<String, dynamic> userPreferences;

  const PaletteExtractionInput({
    required this.imagePath,
    this.maxColors = 8,
    this.minSaturation = 0.3,
    this.userPreferences = const {},
  });

  factory PaletteExtractionInput.fromMap(Map<String, dynamic> map) {
    return PaletteExtractionInput(
      imagePath: map['imagePath'] as String,
      maxColors: map['maxColors'] as int? ?? 8,
      minSaturation: map['minSaturation'] as double? ?? 0.3,
      userPreferences: Map<String, dynamic>.from(
        map['userPreferences'] as Map? ?? {},
      ),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'imagePath': imagePath,
      'maxColors': maxColors,
      'minSaturation': minSaturation,
      'userPreferences': userPreferences,
    };
  }

  @override
  List<String> validate() {
    final issues = <String>[];

    if (imagePath.isEmpty) {
      issues.add('imagePath cannot be empty');
    }

    if (maxColors <= 0) {
      issues.add('maxColors must be positive');
    }

    if (minSaturation < 0.0 || minSaturation > 1.0) {
      issues.add('minSaturation must be between 0.0 and 1.0');
    }

    return issues;
  }
}

/// Example concrete implementation for color refinement input
class ColorRefinementInput extends ToolInput {
  final List<String> colors;
  final bool enhanceContrast;
  final String targetAccessibility;

  const ColorRefinementInput({
    required this.colors,
    this.enhanceContrast = true,
    this.targetAccessibility = 'AA',
  });

  factory ColorRefinementInput.fromMap(Map<String, dynamic> map) {
    return ColorRefinementInput(
      colors: List<String>.from(map['colors'] as List),
      enhanceContrast: map['enhance_contrast'] as bool? ?? true,
      targetAccessibility: map['target_accessibility'] as String? ?? 'AA',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'colors': colors,
      'enhance_contrast': enhanceContrast,
      'target_accessibility': targetAccessibility,
    };
  }

  @override
  List<String> validate() {
    final issues = <String>[];

    if (colors.isEmpty) {
      issues.add('colors list cannot be empty');
    }

    for (final color in colors) {
      if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
        issues.add('Invalid color format: $color (expected #RRGGBB)');
      }
    }

    if (!['A', 'AA', 'AAA'].contains(targetAccessibility)) {
      issues.add('targetAccessibility must be A, AA, or AAA');
    }

    return issues;
  }
}

/// Example concrete implementation for palette extraction output
class PaletteExtractionOutput extends ToolOutput {
  final List<String> colors;
  final double confidence;
  final String imageAnalyzed;
  final Map<String, dynamic> metadata;

  const PaletteExtractionOutput({
    required this.colors,
    required this.confidence,
    required this.imageAnalyzed,
    this.metadata = const {},
  });

  factory PaletteExtractionOutput.fromMap(Map<String, dynamic> map) {
    return PaletteExtractionOutput(
      colors: List<String>.from(map['colors'] as List),
      confidence: map['confidence'] as double,
      imageAnalyzed: map['image_analyzed'] as String,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'colors': colors,
      'confidence': confidence,
      'image_analyzed': imageAnalyzed,
      'metadata': metadata,
    };
  }
}

/// Example concrete implementation for color refinement output
class ColorRefinementOutput extends ToolOutput {
  final List<String> refinedColors;
  final List<String> improvementsMade;
  final Map<String, double> accessibilityScores;

  const ColorRefinementOutput({
    required this.refinedColors,
    required this.improvementsMade,
    this.accessibilityScores = const {},
  });

  factory ColorRefinementOutput.fromMap(Map<String, dynamic> map) {
    return ColorRefinementOutput(
      refinedColors: List<String>.from(map['refined_colors'] as List),
      improvementsMade: List<String>.from(map['improvements_made'] as List),
      accessibilityScores: Map<String, double>.from(
        map['accessibility_scores'] as Map? ?? {},
      ),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'refined_colors': refinedColors,
      'improvements_made': improvementsMade,
      'accessibility_scores': accessibilityScores,
    };
  }
}

/// Example concrete implementation for theme generation output
class ThemeGenerationOutput extends ToolOutput {
  final Map<String, String> theme;
  final Map<String, dynamic> metadata;

  const ThemeGenerationOutput({required this.theme, this.metadata = const {}});

  factory ThemeGenerationOutput.fromMap(Map<String, dynamic> map) {
    return ThemeGenerationOutput(
      theme: Map<String, String>.from(map['theme'] as Map),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {'theme': theme, 'metadata': metadata};
  }
}

// TODO: Is this ever used?
/// Example of extending the ToolResult class for custom data
class ColorExtractionResult extends ToolResult {
  /// Confidence score for the extraction
  final double confidence;

  /// Image metadata
  final Map<String, dynamic> imageMetadata;

  ColorExtractionResult({
    required super.toolName,
    required super.input,
    required super.output,
    super.issues,
    super.typedInput,
    super.typedOutput,
    required this.confidence,
    required this.imageMetadata,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['confidence'] = confidence;
    json['imageMetadata'] = imageMetadata;
    return json;
  }
}

/// Registers typed outputs for type-safe operations
void registerColorThemeTypedOutputs() {
  ToolOutputRegistry.register(
    'extract_palette',
    (data) => PaletteExtractionOutput.fromMap(data),
  );

  ToolOutputRegistry.register(
    'refine_colors',
    (data) => ColorRefinementOutput.fromMap(data),
  );

  ToolOutputRegistry.register(
    'generate_theme',
    (data) => ThemeGenerationOutput.fromMap(data),
  );
}
