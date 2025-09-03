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

  // TODO: (SKIP) Consider changing all toMap to toJson.
  // - [ ] Consolidate usages of `toJson` and `toMap` to all be named identically, since these are doing the same thing.
  //   - Uniformity is nice. Let's go with toJson.
  @override
  Map<String, dynamic> toMap() {
    return {
      'imagePath': imagePath,
      'maxColors': maxColors,
      'minSaturation': minSaturation,
      'userPreferences': userPreferences,
      'metadata': {'generated_at': DateTime.now().toIso8601String()},
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
  final double confidence;
  final bool enhanceContrast;
  final String targetAccessibility;

  const ColorRefinementInput({
    required this.colors,
    required this.confidence,
    this.enhanceContrast = true,
    this.targetAccessibility = 'AA',
  });

  factory ColorRefinementInput.fromMap(Map<String, dynamic> map) {
    return ColorRefinementInput(
      colors: List<String>.from(map['colors'] as List),
      confidence: map['confidence'] as double,
      enhanceContrast: map['enhance_contrast'] as bool? ?? true,
      targetAccessibility: map['target_accessibility'] as String? ?? 'AA',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'colors': colors,
      'confidence': confidence,
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

    if (confidence < 0.0 || confidence > 1.0) {
      issues.add('confidence must be between 0.0 and 1.0');
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
  /// Static step name for this tool output type
  static const String stepName = 'extract_palette';

  final List<String> colors;
  final double confidence;
  final String imageAnalyzed;
  final Map<String, dynamic> metadata;

  const PaletteExtractionOutput({
    required this.colors,
    required this.confidence,
    required this.imageAnalyzed,
    this.metadata = const {},
    required super.round,
  }) : super.subclass();

  factory PaletteExtractionOutput.fromMap(Map<String, dynamic> map, int round) {
    return PaletteExtractionOutput(
      colors: List<String>.from(map['colors'] as List),
      confidence: map['confidence'] as double,
      imageAnalyzed: map['image_analyzed'] as String,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      round: round,
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

  static OutputSchema getOutputSchema() {
    return OutputSchema(
      properties: [
        PropertyEntry.array(
          name: 'colors',
          items: PropertyType.string,
          description: 'Array of extracted color codes',
        ),
        PropertyEntry.number(
          name: 'confidence',
          minimum: 0.0,
          maximum: 1.0,
          description: 'Confidence score for the extraction',
        ),
        PropertyEntry.string(
          name: 'image_analyzed',
          description: 'Path of the analyzed image',
        ),
        PropertyEntry.object(
          name: 'metadata',
          description: 'Additional metadata about the extraction',
        ),
      ],
      required: ['colors', 'confidence', 'image_analyzed'],
    );
  }
}

/// Example concrete implementation for color refinement output
class ColorRefinementOutput extends ToolOutput {
  /// Static step name for this tool output type
  static const String stepName = 'refine_colors';

  final List<String> refinedColors;
  final List<String> improvementsMade;
  final Map<String, double> accessibilityScores;

  const ColorRefinementOutput({
    required this.refinedColors,
    required this.improvementsMade,
    this.accessibilityScores = const {},
    required super.round,
  }) : super.subclass();

  factory ColorRefinementOutput.fromMap(Map<String, dynamic> map, int round) {
    return ColorRefinementOutput(
      refinedColors: List<String>.from(map['refined_colors'] as List),
      improvementsMade: List<String>.from(map['improvements_made'] as List),
      accessibilityScores: Map<String, double>.from(
        map['accessibility_scores'] as Map? ?? {},
      ),
      round: round,
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

  static OutputSchema getOutputSchema() {
    return OutputSchema(
      properties: [
        PropertyEntry.array(
          name: 'refined_colors',
          items: PropertyType.string,
          description: 'List of refined color codes',
        ),
        PropertyEntry.array(
          name: 'improvements_made',
          items: PropertyType.string,
          description: 'List of improvements that were applied',
        ),
        PropertyEntry.object(
          name: 'accessibility_scores',
          description: 'Accessibility scores for the refined colors',
        ),
      ],
      required: ['refined_colors', 'improvements_made'],
    );
  }
}

/// Example concrete implementation for theme generation output
class ThemeGenerationOutput extends ToolOutput {
  /// Static step name for this tool output type
  static const String stepName = 'generate_theme';

  final Map<String, String> theme;
  final Map<String, dynamic> metadata;

  const ThemeGenerationOutput({
    required this.theme,
    this.metadata = const {},
    required super.round,
  }) : super.subclass();

  factory ThemeGenerationOutput.fromMap(Map<String, dynamic> map, int round) {
    return ThemeGenerationOutput(
      theme: Map<String, String>.from(map['theme'] as Map),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      round: round,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {'theme': theme, 'metadata': metadata};
  }

  static OutputSchema getOutputSchema() {
    return OutputSchema(
      properties: [
        PropertyEntry.object(
          name: 'theme',
          description: 'Generated theme configuration',
        ),
        PropertyEntry.object(
          name: 'metadata',
          description: 'Additional metadata about the theme generation',
        ),
      ],
      required: ['theme'],
    );
  }
}

/// Step definitions that encapsulate tool metadata and functionality

/// Step definition for palette extraction
class PaletteExtractionStepDefinition
    extends StepDefinition<PaletteExtractionOutput> {
  @override
  String get stepName => PaletteExtractionOutput.stepName;

  @override
  OutputSchema get outputSchema => PaletteExtractionOutput.getOutputSchema();

  @override
  PaletteExtractionOutput fromMap(Map<String, dynamic> data, int round) =>
      PaletteExtractionOutput.fromMap(data, round);
}

/// Step definition for color refinement
class ColorRefinementStepDefinition
    extends StepDefinition<ColorRefinementOutput> {
  @override
  String get stepName => ColorRefinementOutput.stepName;

  @override
  OutputSchema get outputSchema => ColorRefinementOutput.getOutputSchema();

  @override
  ColorRefinementOutput fromMap(Map<String, dynamic> data, int round) =>
      ColorRefinementOutput.fromMap(data, round);
}

/// Step definition for theme generation
class ThemeGenerationStepDefinition
    extends StepDefinition<ThemeGenerationOutput> {
  @override
  String get stepName => ThemeGenerationOutput.stepName;

  @override
  OutputSchema get outputSchema => ThemeGenerationOutput.getOutputSchema();

  @override
  ThemeGenerationOutput fromMap(Map<String, dynamic> data, int round) =>
      ThemeGenerationOutput.fromMap(data, round);
}
