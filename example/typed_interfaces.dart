/// Concrete implementations of typed tool interfaces for professional color workflow.
///
/// This file implements strongly-typed input and output classes for the 3-step 
/// professional color generation workflow, providing better type safety and IDE support.
/// 
/// Professional workflow: seed colors → design system colors → full color suite
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


