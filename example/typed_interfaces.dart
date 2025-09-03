/// Concrete implementations of typed tool interfaces.
///
/// This file demonstrates how to create strongly-typed input and output classes
/// for tool calls, providing better type safety and IDE support.
/// 
/// Updated for Round 15: Redesigned flow with seed colors -> design system colors -> full color suite
library;

import 'package:openai_toolflow/openai_toolflow.dart';

/// Input for generating initial seed colors (Step 1)
class SeedColorGenerationInput extends ToolInput {
  final String designStyle;
  final String mood;
  final int colorCount;
  final Map<String, dynamic> userPreferences;

  const SeedColorGenerationInput({
    this.designStyle = 'modern',
    this.mood = 'professional',
    this.colorCount = 3,
    this.userPreferences = const {},
  });

  factory SeedColorGenerationInput.fromMap(Map<String, dynamic> map) {
    return SeedColorGenerationInput(
      designStyle: map['design_style'] as String? ?? 'modern',
      mood: map['mood'] as String? ?? 'professional',
      colorCount: map['color_count'] as int? ?? 3,
      userPreferences: Map<String, dynamic>.from(
        map['user_preferences'] as Map? ?? {},
      ),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'design_style': designStyle,
      'mood': mood,
      'color_count': colorCount,
      'user_preferences': userPreferences,
      'metadata': {'generated_at': DateTime.now().toIso8601String()},
    };
  }

  @override
  List<String> validate() {
    final issues = <String>[];

    if (designStyle.isEmpty) {
      issues.add('design_style cannot be empty');
    }

    if (mood.isEmpty) {
      issues.add('mood cannot be empty');
    }

    if (colorCount <= 0 || colorCount > 10) {
      issues.add('color_count must be between 1 and 10');
    }

    return issues;
  }
}

/// Legacy class maintained for backward compatibility
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

/// Input for generating main design system colors (Step 2)
class DesignSystemColorInput extends ToolInput {
  final List<String> seedColors;
  final String targetAccessibility;
  final int systemColorCount;
  final List<String> colorCategories;

  const DesignSystemColorInput({
    required this.seedColors,
    this.targetAccessibility = 'AA',
    this.systemColorCount = 6,
    this.colorCategories = const [
      'primary',
      'secondary', 
      'surface',
      'text',
      'warning',
      'error'
    ],
  });

  factory DesignSystemColorInput.fromMap(Map<String, dynamic> map) {
    return DesignSystemColorInput(
      seedColors: List<String>.from(map['seed_colors'] as List),
      targetAccessibility: map['target_accessibility'] as String? ?? 'AA',
      systemColorCount: map['system_color_count'] as int? ?? 6,
      colorCategories: List<String>.from(
        map['color_categories'] as List? ?? [
          'primary', 'secondary', 'surface', 'text', 'warning', 'error'
        ],
      ),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'seed_colors': seedColors,
      'target_accessibility': targetAccessibility,
      'system_color_count': systemColorCount,
      'color_categories': colorCategories,
    };
  }

  @override
  List<String> validate() {
    final issues = <String>[];

    if (seedColors.isEmpty) {
      issues.add('seed_colors cannot be empty');
    }

    if (systemColorCount <= 0 || systemColorCount > 20) {
      issues.add('system_color_count must be between 1 and 20');
    }

    for (final color in seedColors) {
      if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
        issues.add('Invalid seed color format: $color (expected #RRGGBB)');
      }
    }

    if (!['A', 'AA', 'AAA'].contains(targetAccessibility)) {
      issues.add('targetAccessibility must be A, AA, or AAA');
    }

    return issues;
  }
}

/// Input for generating full color suite (Step 3)
class FullColorSuiteInput extends ToolInput {
  final Map<String, String> systemColors;
  final int suiteColorCount;
  final List<String> colorVariants;
  final String brandPersonality;

  const FullColorSuiteInput({
    required this.systemColors,
    this.suiteColorCount = 30,
    this.colorVariants = const [
      'primaryText',
      'secondaryText',
      'interactiveText',
      'mutedText',
      'primaryBackground',
      'secondaryBackground',
      'surfaceBackground',
      'cardBackground',
      'overlayBackground',
      'errorBackground',
      'warningBackground',
      'successBackground',
      'infoBackground'
    ],
    this.brandPersonality = 'professional',
  });

  factory FullColorSuiteInput.fromMap(Map<String, dynamic> map) {
    return FullColorSuiteInput(
      systemColors: Map<String, String>.from(map['system_colors'] as Map),
      suiteColorCount: map['suite_color_count'] as int? ?? 30,
      colorVariants: List<String>.from(
        map['color_variants'] as List? ?? [
          'primaryText', 'secondaryText', 'interactiveText', 'mutedText',
          'primaryBackground', 'secondaryBackground', 'surfaceBackground', 
          'cardBackground', 'overlayBackground', 'errorBackground',
          'warningBackground', 'successBackground', 'infoBackground'
        ],
      ),
      brandPersonality: map['brand_personality'] as String? ?? 'professional',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'system_colors': systemColors,
      'suite_color_count': suiteColorCount,
      'color_variants': colorVariants,
      'brand_personality': brandPersonality,
    };
  }

  @override
  List<String> validate() {
    final issues = <String>[];

    if (systemColors.isEmpty) {
      issues.add('system_colors cannot be empty');
    }

    if (suiteColorCount <= 0 || suiteColorCount > 100) {
      issues.add('suite_color_count must be between 1 and 100');
    }

    for (final entry in systemColors.entries) {
      if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(entry.value)) {
        issues.add('Invalid system color format for ${entry.key}: ${entry.value} (expected #RRGGBB)');
      }
    }

    return issues;
  }
}

/// Legacy class maintained for backward compatibility
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

/// Output for seed color generation (Step 1)
class SeedColorGenerationOutput extends ToolOutput {
  static const String stepName = 'generate_seed_colors';

  final List<String> seedColors;
  final String designStyle;
  final String mood;
  final Map<String, dynamic> colorTheory;
  final double confidence;

  const SeedColorGenerationOutput({
    required this.seedColors,
    required this.designStyle,
    required this.mood,
    this.colorTheory = const {},
    required this.confidence,
    required super.round,
  }) : super.subclass();

  factory SeedColorGenerationOutput.fromMap(Map<String, dynamic> map, int round) {
    return SeedColorGenerationOutput(
      seedColors: List<String>.from(map['seed_colors'] as List),
      designStyle: map['design_style'] as String,
      mood: map['mood'] as String,
      colorTheory: Map<String, dynamic>.from(map['color_theory'] as Map? ?? {}),
      confidence: map['confidence'] as double,
      round: round,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'seed_colors': seedColors,
      'design_style': designStyle,
      'mood': mood,
      'color_theory': colorTheory,
      'confidence': confidence,
    };
  }

  static OutputSchema getOutputSchema() {
    return OutputSchema(
      properties: [
        PropertyEntry.array(
          name: 'seed_colors',
          items: PropertyType.string,
          description: 'Array of generated seed color codes in hex format',
        ),
        PropertyEntry.string(
          name: 'design_style',
          description: 'Design style that influenced the color selection',
        ),
        PropertyEntry.string(
          name: 'mood',
          description: 'Mood that influenced the color palette',
        ),
        PropertyEntry.object(
          name: 'color_theory',
          description: 'Color theory principles used in generation',
        ),
        PropertyEntry.number(
          name: 'confidence',
          minimum: 0.0,
          maximum: 1.0,
          description: 'Confidence score for the generated seed colors',
        ),
      ],
      required: ['seed_colors', 'design_style', 'mood', 'confidence'],
    );
  }
}

/// Output for design system colors (Step 2)
class DesignSystemColorOutput extends ToolOutput {
  static const String stepName = 'generate_design_system_colors';

  final Map<String, String> systemColors;
  final Map<String, double> accessibilityScores;
  final List<String> colorHarmonies;
  final Map<String, dynamic> designPrinciples;

  const DesignSystemColorOutput({
    required this.systemColors,
    this.accessibilityScores = const {},
    this.colorHarmonies = const [],
    this.designPrinciples = const {},
    required super.round,
  }) : super.subclass();

  factory DesignSystemColorOutput.fromMap(Map<String, dynamic> map, int round) {
    return DesignSystemColorOutput(
      systemColors: Map<String, String>.from(map['system_colors'] as Map),
      accessibilityScores: Map<String, double>.from(
        map['accessibility_scores'] as Map? ?? {},
      ),
      colorHarmonies: List<String>.from(map['color_harmonies'] as List? ?? []),
      designPrinciples: Map<String, dynamic>.from(
        map['design_principles'] as Map? ?? {},
      ),
      round: round,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'system_colors': systemColors,
      'accessibility_scores': accessibilityScores,
      'color_harmonies': colorHarmonies,
      'design_principles': designPrinciples,
    };
  }

  static OutputSchema getOutputSchema() {
    return OutputSchema(
      properties: [
        PropertyEntry.object(
          name: 'system_colors',
          description: 'Map of color category names to hex color codes',
        ),
        PropertyEntry.object(
          name: 'accessibility_scores',
          description: 'Accessibility scores for each system color',
        ),
        PropertyEntry.array(
          name: 'color_harmonies',
          items: PropertyType.string,
          description: 'Color harmony techniques applied',
        ),
        PropertyEntry.object(
          name: 'design_principles',
          description: 'Design principles applied during color generation',
        ),
      ],
      required: ['system_colors'],
    );
  }
}

/// Output for full color suite (Step 3)
class FullColorSuiteOutput extends ToolOutput {
  static const String stepName = 'generate_full_color_suite';

  final Map<String, String> colorSuite;
  final Map<String, List<String>> colorFamilies;
  final Map<String, dynamic> brandGuidelines;
  final Map<String, dynamic> usageRecommendations;

  const FullColorSuiteOutput({
    required this.colorSuite,
    this.colorFamilies = const {},
    this.brandGuidelines = const {},
    this.usageRecommendations = const {},
    required super.round,
  }) : super.subclass();

  factory FullColorSuiteOutput.fromMap(Map<String, dynamic> map, int round) {
    return FullColorSuiteOutput(
      colorSuite: Map<String, String>.from(map['color_suite'] as Map),
      colorFamilies: map['color_families'] != null
          ? Map<String, List<String>>.from(
              (map['color_families'] as Map).map(
                (key, value) => MapEntry(key, List<String>.from(value as List)),
              ),
            )
          : {},
      brandGuidelines: Map<String, dynamic>.from(
        map['brand_guidelines'] as Map? ?? {},
      ),
      usageRecommendations: Map<String, dynamic>.from(
        map['usage_recommendations'] as Map? ?? {},
      ),
      round: round,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'color_suite': colorSuite,
      'color_families': colorFamilies,
      'brand_guidelines': brandGuidelines,
      'usage_recommendations': usageRecommendations,
    };
  }

  static OutputSchema getOutputSchema() {
    return OutputSchema(
      properties: [
        PropertyEntry.object(
          name: 'color_suite',
          description: 'Complete suite of named colors with hex codes',
        ),
        PropertyEntry.object(
          name: 'color_families',
          description: 'Grouping of colors by family or purpose',
        ),
        PropertyEntry.object(
          name: 'brand_guidelines',
          description: 'Brand-specific color usage guidelines',
        ),
        PropertyEntry.object(
          name: 'usage_recommendations',
          description: 'Recommendations for using colors in different contexts',
        ),
      ],
      required: ['color_suite'],
    );
  }
}

/// Legacy output maintained for backward compatibility
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
    Map<String, String> themeMap;

    themeMap = {};
    if (map.containsKey('theme_type')) {
      themeMap['theme_type'] = map['theme_type'] as String;
    }
    if (map.containsKey('base_colors')) {
      // Convert base_colors list to a comma-separated string for storage
      final baseColors = map['base_colors'] as List?;
      if (baseColors != null) {
        themeMap['base_colors'] = baseColors.join(',');
      }
    }
    if (map.containsKey('primary_color')) {
      themeMap['primary_color'] = map['primary_color'] as String;
    }
    return ThemeGenerationOutput(
      theme: themeMap,
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

/// Step definition for seed color generation (New workflow Step 1)
class SeedColorGenerationStepDefinition
    extends StepDefinition<SeedColorGenerationOutput> {
  @override
  String get stepName => SeedColorGenerationOutput.stepName;

  @override
  OutputSchema get outputSchema => SeedColorGenerationOutput.getOutputSchema();

  @override
  SeedColorGenerationOutput fromMap(Map<String, dynamic> data, int round) =>
      SeedColorGenerationOutput.fromMap(data, round);
}

/// Step definition for design system color generation (New workflow Step 2)
class DesignSystemColorStepDefinition
    extends StepDefinition<DesignSystemColorOutput> {
  @override
  String get stepName => DesignSystemColorOutput.stepName;

  @override
  OutputSchema get outputSchema => DesignSystemColorOutput.getOutputSchema();

  @override
  DesignSystemColorOutput fromMap(Map<String, dynamic> data, int round) =>
      DesignSystemColorOutput.fromMap(data, round);
}

/// Step definition for full color suite generation (New workflow Step 3)
class FullColorSuiteStepDefinition
    extends StepDefinition<FullColorSuiteOutput> {
  @override
  String get stepName => FullColorSuiteOutput.stepName;

  @override
  OutputSchema get outputSchema => FullColorSuiteOutput.getOutputSchema();

  @override
  FullColorSuiteOutput fromMap(Map<String, dynamic> data, int round) =>
      FullColorSuiteOutput.fromMap(data, round);
}

/// Legacy step definition for palette extraction (maintained for backward compatibility)
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

/// Legacy step definition for color refinement (maintained for backward compatibility)
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

/// Legacy step definition for theme generation (maintained for backward compatibility)
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
