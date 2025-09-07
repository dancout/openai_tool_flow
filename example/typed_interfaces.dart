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
    required this.designStyle,
    required this.mood,
    required this.colorCount,
    required this.userPreferences,
  });

  factory SeedColorGenerationInput.fromMap(Map<String, dynamic> map) {
    final designStyle = map['design_style'];
    if (designStyle == null) {
      throw ArgumentError('Missing required field: design_style');
    }

    final mood = map['mood'];
    if (mood == null) {
      throw ArgumentError('Missing required field: mood');
    }

    final colorCount = map['color_count'];
    if (colorCount == null) {
      throw ArgumentError('Missing required field: color_count');
    }

    final userPreferences = map['user_preferences'];
    if (userPreferences == null) {
      throw ArgumentError('Missing required field: user_preferences');
    }

    return SeedColorGenerationInput(
      designStyle: designStyle as String,
      mood: mood as String,
      colorCount: colorCount as int,
      userPreferences: Map<String, dynamic>.from(userPreferences as Map),
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

  const DesignSystemColorInput({
    required this.seedColors,
    required this.targetAccessibility,
  });

  factory DesignSystemColorInput.fromMap(Map<String, dynamic> map) {
    final seedColors = map['seed_colors'];
    if (seedColors == null) {
      throw ArgumentError('Missing required field: seed_colors');
    }

    final targetAccessibility = map['target_accessibility'];
    if (targetAccessibility == null) {
      throw ArgumentError('Missing required field: target_accessibility');
    }

    return DesignSystemColorInput(
      seedColors: List<String>.from(seedColors as List),
      targetAccessibility: targetAccessibility as String,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'seed_colors': seedColors,
      'target_accessibility': targetAccessibility,
    };
  }

  @override
  List<String> validate() {
    final issues = <String>[];

    if (seedColors.isEmpty) {
      issues.add('seed_colors cannot be empty');
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
  final String brandPersonality;

  const FullColorSuiteInput({
    required this.systemColors,
    required this.brandPersonality,
  });

  factory FullColorSuiteInput.fromMap(Map<String, dynamic> map) {
    final systemColors = map['system_colors'];
    if (systemColors == null) {
      throw ArgumentError('Missing required field: system_colors');
    }

    final brandPersonality = map['brand_personality'];
    if (brandPersonality == null) {
      throw ArgumentError('Missing required field: brand_personality');
    }

    return FullColorSuiteInput(
      systemColors: Map<String, String>.from(systemColors as Map),
      brandPersonality: brandPersonality as String,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'system_colors': systemColors,
      'brand_personality': brandPersonality,
    };
  }

  @override
  List<String> validate() {
    final issues = <String>[];

    if (systemColors.isEmpty) {
      issues.add('system_colors cannot be empty');
    }

    for (final entry in systemColors.entries) {
      if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(entry.value)) {
        issues.add(
          'Invalid system color format for ${entry.key}: ${entry.value} (expected #RRGGBB)',
        );
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

  factory SeedColorGenerationOutput.fromMap(
    Map<String, dynamic> map,
    int round,
  ) {
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
          properties: [
            PropertyEntry.string(
              name: 'harmony_type',
              description:
                  'Type of color harmony applied (e.g., complementary)',
            ),
            PropertyEntry.array(
              name: 'principles',
              items: PropertyType.string,
              description: 'List of color theory principles applied',
            ),
            PropertyEntry.string(
              name: 'psychological_impact',
              description: 'Intended psychological impact of the colors',
            ),
          ],
        ),
        PropertyEntry.number(
          name: 'confidence',
          minimum: 0.0,
          maximum: 1.0,
          description: 'Confidence score for the generated seed colors',
        ),
      ],

      systemMessageTemplate:
          'You are an expert color theorist and UX designer with deep knowledge of color psychology, design principles, and brand identity. You specialize in creating foundational color palettes that serve as the basis for comprehensive design systems.\n\nYour expertise includes understanding color harmony (complementary, triadic, analogous), psychological impact of colors, accessibility considerations, and how colors convey brand personality and user emotions.',
    );
  }
}

/// Output for design system colors (Step 2)
class DesignSystemColorOutput extends ToolOutput {
  static const String stepName = 'generate_design_system_colors';

  final Map<String, String> systemColors;
  final List<String> colorHarmonies;
  final Map<String, dynamic> designPrinciples;

  const DesignSystemColorOutput({
    required this.systemColors,
    this.colorHarmonies = const [],
    this.designPrinciples = const {},
    required super.round,
  }) : super.subclass();

  factory DesignSystemColorOutput.fromMap(Map<String, dynamic> map, int round) {
    return DesignSystemColorOutput(
      systemColors: Map<String, String>.from(map['system_colors'] as Map),
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
          properties: [
            PropertyEntry.string(
              name: 'primary',
              description: 'Primary brand color',
            ),
            PropertyEntry.string(
              name: 'secondary',
              description: 'Secondary brand color',
            ),
            PropertyEntry.string(
              name: 'surface',
              description: 'Surface color for cards and backgrounds',
            ),
            PropertyEntry.string(
              name: 'text',
              description: 'Text color for primary content',
            ),
            PropertyEntry.string(
              name: 'warning',
              description: 'Warning color for alerts',
            ),
            PropertyEntry.string(
              name: 'error',
              description: 'Error color for error messages',
            ),
          ],
        ),
        PropertyEntry.array(
          name: 'color_harmonies',
          items: PropertyType.string,
          description: 'Color harmony techniques applied',
        ),
        PropertyEntry.object(
          name: 'design_principles',
          description: 'Design principles applied during color generation',
          properties: [
            PropertyEntry.string(
              name: 'contrast_ratio',
              description:
                  'WCAG AAA compliant contrast ratio for optimal accessibility',
            ),
            PropertyEntry.string(
              name: 'color_psychology',
              description:
                  'Psychological impact of the color choices, emphasizing trust and innovation',
            ),
            PropertyEntry.string(
              name: 'brand_alignment',
              description:
                  'Alignment of color choices with professional services branding and identity',
            ),
          ],
        ),
      ],
      systemMessageTemplate:
          'You are an expert UX designer with extensive experience in design system architecture and color theory. You specialize in expanding foundational color palettes into systematic, purposeful color sets that serve specific functional roles in user interfaces.\n\nYour expertise includes creating accessible color combinations, understanding semantic color usage (primary, secondary, error, warning), ensuring proper contrast ratios, and establishing clear color hierarchies for optimal user experience.',
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
          properties: [
            // Text colors
            PropertyEntry.string(
              name: 'primaryText',
              description: 'Primary text color',
            ),
            PropertyEntry.string(
              name: 'secondaryText',
              description: 'Secondary text color',
            ),
            PropertyEntry.string(
              name: 'interactiveText',
              description: 'Text color for interactive elements',
            ),
            PropertyEntry.string(
              name: 'mutedText',
              description: 'Muted/low emphasis text color',
            ),
            PropertyEntry.string(
              name: 'disabledText',
              description: 'Disabled text color',
            ),

            // Background colors
            PropertyEntry.string(
              name: 'primaryBackground',
              description: 'Primary background color',
            ),
            PropertyEntry.string(
              name: 'secondaryBackground',
              description: 'Secondary background color',
            ),
            PropertyEntry.string(
              name: 'surfaceBackground',
              description: 'Surface background color (e.g., cards)',
            ),
            PropertyEntry.string(
              name: 'cardBackground',
              description: 'Card background color',
            ),
            PropertyEntry.string(
              name: 'overlayBackground',
              description: 'Overlay background color (with opacity)',
            ),
            PropertyEntry.string(
              name: 'hoverBackground',
              description: 'Background color for hover state',
            ),

            // Status backgrounds
            PropertyEntry.string(
              name: 'errorBackground',
              description: 'Background color for error states',
            ),
            PropertyEntry.string(
              name: 'warningBackground',
              description: 'Background color for warning states',
            ),
            PropertyEntry.string(
              name: 'successBackground',
              description: 'Background color for success states',
            ),
            PropertyEntry.string(
              name: 'infoBackground',
              description: 'Background color for informational states',
            ),

            // Border colors
            PropertyEntry.string(
              name: 'primaryBorder',
              description: 'Primary border color',
            ),
            PropertyEntry.string(
              name: 'secondaryBorder',
              description: 'Secondary border color',
            ),
            PropertyEntry.string(
              name: 'focusBorder',
              description: 'Border color for focus state',
            ),
            PropertyEntry.string(
              name: 'errorBorder',
              description: 'Border color for error state',
            ),
            PropertyEntry.string(
              name: 'warningBorder',
              description: 'Border color for warning state',
            ),

            // Interactive colors
            PropertyEntry.string(
              name: 'primaryButton',
              description: 'Primary button color',
            ),
            PropertyEntry.string(
              name: 'secondaryButton',
              description: 'Secondary button color',
            ),
            PropertyEntry.string(
              name: 'disabledButton',
              description: 'Disabled button color',
            ),
            PropertyEntry.string(
              name: 'primaryLink',
              description: 'Primary link color',
            ),
            PropertyEntry.string(
              name: 'visitedLink',
              description: 'Visited link color',
            ),

            // Icon colors
            PropertyEntry.string(
              name: 'primaryIcon',
              description: 'Primary icon color',
            ),
            PropertyEntry.string(
              name: 'secondaryIcon',
              description: 'Secondary icon color',
            ),
            PropertyEntry.string(
              name: 'warningIcon',
              description: 'Warning icon color',
            ),
            PropertyEntry.string(
              name: 'errorIcon',
              description: 'Error icon color',
            ),
            PropertyEntry.string(
              name: 'successIcon',
              description: 'Success icon color',
            ),
          ],
        ),
        PropertyEntry.object(
          name: 'color_families',
          description: 'Grouping of colors by family or purpose',
          properties: [
            PropertyEntry.array(
              name: 'blues',
              items: PropertyType.string,
              description: 'Array of blue color hex codes',
            ),
            PropertyEntry.array(
              name: 'purples',
              items: PropertyType.string,
              description: 'Array of purple color hex codes',
            ),
            PropertyEntry.array(
              name: 'neutrals',
              items: PropertyType.string,
              description: 'Array of neutral color hex codes',
            ),
          ],
        ),
        PropertyEntry.object(
          name: 'brand_guidelines',
          description: 'Brand-specific color usage guidelines',
          properties: [
            PropertyEntry.string(
              name: 'primary_usage',
              description:
                  'Usage of primary brand color (e.g., call-to-action buttons, links, key highlights)',
            ),
            PropertyEntry.string(
              name: 'secondary_usage',
              description:
                  'Usage of secondary brand color (e.g., accent elements, secondary actions, decorative elements)',
            ),
            PropertyEntry.string(
              name: 'text_hierarchy',
              description:
                  'Text color hierarchy (e.g., primary for headings, secondary for body, muted for captions)',
            ),
            PropertyEntry.string(
              name: 'background_strategy',
              description:
                  'Background color strategy (e.g., layered approach with subtle elevation through background variations)',
            ),
          ],
        ),
        PropertyEntry.object(
          name: 'usage_recommendations',
          description: 'Recommendations for using colors in different contexts',
          properties: [
            PropertyEntry.string(
              name: 'accessibility',
              description:
                  'Accessibility compliance for color usage (e.g., WCAG AA standards)',
            ),
            PropertyEntry.string(
              name: 'contrast_ratios',
              description:
                  'Contrast ratio recommendations for text and background colors (e.g., minimum 4.5:1)',
            ),
            PropertyEntry.string(
              name: 'interactive_states',
              description:
                  'Guidance for interactive states (e.g., hover, focus) using color variants',
            ),
            PropertyEntry.string(
              name: 'error_handling',
              description:
                  'Recommendations for error color usage (e.g., reserved for validation and critical alerts)',
            ),
          ],
        ),
      ],
      systemMessageTemplate:
          'You are a senior design systems architect with expertise in comprehensive color specification for enterprise-grade applications. You specialize in creating complete, scalable color suites that cover all possible interface states and use cases.\n\nYour expertise includes defining granular color tokens (text variants, background layers, interactive states), creating cohesive color families, establishing usage guidelines, and ensuring consistency across complex application ecosystems.',
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
