/// Example usage of the openai_toolflow package.
///
/// This example demonstrates how to create a color theme generation pipeline
/// that extracts colors from an image, refines them, and generates a final theme.
/// Features strongly-typed interfaces, per-step audits, and retry logic.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

import 'audit_functions.dart';

void main() async {
  print('🎨 Color Theme Generator Example');
  print('=================================\n');

  // Register typed outputs for type safety
  registerColorThemeTypedOutputs();

  // Create configuration (in practice, this would load from environment or .env)
  final config = OpenAIConfig(
    apiKey: 'your-api-key-here', // In practice: load from environment
    defaultModel: 'gpt-4',
    defaultTemperature: 0.7,
    defaultMaxTokens: 2000,
  );

  // Define audit functions using the example implementations
  final colorFormatAudit = ColorQualityAuditFunction();
  final diversityAudit = ColorDiversityAuditFunction(
    minimumColors: 4,
    weightedThreshold: 3.0, // Lower threshold for stricter requirements
  );

  // Create a mock service for demonstration
  final mockService = MockOpenAiToolService(
    responses: {
      'extract_palette': {
        'colors': ['#FF5733', '#33FF57', '#3357FF', '#F333FF', '#FF33F5'],
        'confidence': 0.85,
        'image_analyzed': 'assets/sample_image.jpg',
        'metadata': {'extraction_method': 'k-means', 'processing_time': 2.3},
      },
      'refine_colors': {
        'refined_colors': ['#E74C3C', '#2ECC71', '#3498DB', '#9B59B6'],
        'improvements_made': [
          'contrast adjustment',
          'saturation optimization',
          'accessibility compliance',
        ],
      },
      'generate_theme': {
        'theme': {
          'primary': '#3498DB',
          'secondary': '#2ECC71',
          'accent': '#E74C3C',
          'background': '#FFFFFF',
          'variants': {
            'light': {'opacity': 0.7},
            'dark': {'opacity': 0.9},
          },
        },
        'metadata': {'theme_type': 'material_design', 'version': '1.0'},
      },
    },
  );

  // Define steps with integrated configuration (new Round 3 pattern)
  final steps = [
    // Step 1: Extract base colors from image
    ToolCallStep(
      toolName: 'extract_palette',
      model: 'gpt-4',
      params: PaletteExtractionInput(
        imagePath: 'assets/sample_image.jpg',
        maxColors: 8,
        minSaturation: 0.3,
        userPreferences: {'style': 'modern', 'mood': 'energetic'},
      ).toMap(),
      stepConfig: StepConfig(audits: [diversityAudit], maxRetries: 3),
    ),

    // Step 2: Refine the extracted colors
    ToolCallStep(
      toolName: 'refine_colors',
      model: 'gpt-4',
      // TODO: These params cannot possibly all be defined yet, especially if they rely on the previous step.
      // Note the colors below" "Will be populated..."
      // Figure out a better way to do this, either by only including static params
      // OR would it be better to force a TypedInput here?
      //  We could build the Typed Input from the previous output, populating the colors in a more elegant way.
      //    Yeah, I like the latter way.
      params: ColorRefinementInput(
        colors: [], // Will be populated from previous step
        enhanceContrast: true,
        targetAccessibility: 'AA',
      ).toMap(),
      stepConfig: StepConfig(
        audits: [colorFormatAudit],
        maxRetries: 5, // Override default retries for this step
        customPassCriteria: (issues) {
          // Custom criteria: pass if no medium or higher issues
          return !issues.any(
            (issue) =>
                issue.severity == IssueSeverity.medium ||
                issue.severity == IssueSeverity.high ||
                issue.severity == IssueSeverity.critical,
          );
        },
        includeOutputsFrom: ['extract_palette'],
      ),
    ),

    // Step 3: Generate final theme
    ToolCallStep(
      toolName: 'generate_theme',
      model: 'gpt-4',
      params: {'theme_type': 'material_design', 'include_variants': true},
      stepConfig: StepConfig(
        audits: [],
        maxRetries: 1,
        stopOnFailure: false, // Continue even if this step fails
      ),
    ),
  ];

  // Create the tool flow with service injection (new Round 3 pattern)
  final flow = ToolFlow(
    config: config,
    steps: steps,
    openAiService: mockService, // Inject mock service for testing
  );

  // Execute the flow
  try {
    print('🚀 Starting color theme generation...\n');

    final result = await flow.run(
      input: {
        'user_preferences': {'style': 'modern', 'mood': 'energetic'},
      },
    );

    print('✅ Flow completed!\n');

    // Display results with enhanced information
    print('📊 Execution Summary:');
    print('Steps executed: ${result.results.length}');
    print('Total issues found: ${result.allIssues.length}');
    print(
      'Critical issues: ${result.issuesWithSeverity(IssueSeverity.critical).length}',
    );
    print(
      'High issues: ${result.issuesWithSeverity(IssueSeverity.high).length}',
    );
    print(
      'Medium issues: ${result.issuesWithSeverity(IssueSeverity.medium).length}',
    );
    print(
      'Low issues: ${result.issuesWithSeverity(IssueSeverity.low).length}\n',
    );

    // Show step results with typed outputs
    for (int i = 0; i < result.results.length; i++) {
      final stepResult = result.results[i];
      print('Step ${i + 1}: ${stepResult.toolName}');
      print('  Output keys: ${stepResult.output.keys.join(', ')}');
      print('  Has typed output: ${stepResult.typedOutput != null}');
      print('  Issues: ${stepResult.issues.length}');

      // Show typed output information if available
      if (stepResult.typedOutput != null) {
        print('  Typed output type: ${stepResult.typedOutput.runtimeType}');
      }

      if (stepResult.issues.isNotEmpty) {
        for (final issue in stepResult.issues) {
          final roundInfo = issue.round > 0 ? ' (Round ${issue.round})' : '';
          print(
            '    ⚠️ ${issue.severity.name.toUpperCase()}$roundInfo: ${issue.description}',
          );

          // Show ColorQualityIssue specific information
          if (issue is ColorQualityIssue) {
            print('      🎨 Problematic color: ${issue.problematicColor}');
            print(
              '      📊 Quality score: ${issue.qualityScore.toStringAsFixed(2)}',
            );
          }
        }
      }
      print('');
    }

    // Show final theme if available with type safety
    final finalOutput = result.finalOutput;
    if (finalOutput != null && finalOutput.containsKey('theme')) {
      print('🎨 Generated Theme:');
      final theme = finalOutput['theme'] as Map<String, dynamic>;
      theme.forEach((key, value) {
        print('  $key: $value');
      });
      print('');
    }

    // Demonstrate typed output usage
    final lastResult = result.results.last;
    if (lastResult.typedOutput is ThemeGenerationOutput) {
      final typedTheme = lastResult.typedOutput as ThemeGenerationOutput;
      print('🔧 Typed Theme Access:');
      typedTheme.theme.forEach((key, value) {
        print('  $key: $value');
      });
      print('  Generated at: ${typedTheme.metadata['generated_at']}');
      print('');
    }

    // Show issues by round for retry analysis
    final issuesByRound = <int, List<Issue>>{};
    for (final issue in result.allIssues) {
      issuesByRound.putIfAbsent(issue.round, () => []).add(issue);
    }

    if (issuesByRound.isNotEmpty) {
      print('📈 Issues by Retry Round:');
      issuesByRound.forEach((round, issues) {
        print('  Round $round: ${issues.length} issues');
        for (final issue in issues) {
          print('    - ${issue.severity.name}: ${issue.description}');
        }
      });
      print('');
    }

    // Show any critical issues that need attention
    final criticalIssues = result.issuesWithSeverity(IssueSeverity.critical);
    if (criticalIssues.isNotEmpty) {
      print('🚨 Critical Issues Requiring Attention:');
      for (final issue in criticalIssues) {
        print('  ${issue.description}');
        print('  Suggestions: ${issue.suggestions.join(', ')}');
        if (issue.relatedData != null) {
          print('  Related data keys: ${issue.relatedData!.keys.join(', ')}');
        }
      }
      print('');
    }

    // Export results as JSON for further processing
    print('📄 Results Summary JSON:');
    print(formatJson(result.toJson()));
  } catch (e) {
    print('❌ Flow execution failed: $e');
  }
}

/// Register typed outputs for type-safe operations
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

/// Helper function to format JSON output nicely
String formatJson(Map<String, dynamic> json) {
  // Simple JSON formatting for demo purposes
  final buffer = StringBuffer();
  buffer.writeln('{');

  json.forEach((key, value) {
    buffer.write('  "$key": ');
    if (value is Map) {
      buffer.writeln('{ ... },');
    } else if (value is List) {
      buffer.writeln('[${value.length} items],');
    } else {
      buffer.writeln('"$value",');
    }
  });

  buffer.writeln('}');
  return buffer.toString();
}

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

/// Example usage of StepConfig factory methods
void demonstrateStepConfigUsage() {
  // Different ways to configure steps

  // Step with specific audits only
  final step1Config = StepConfig(
    audits: [ColorQualityAuditFunction(), ColorDiversityAuditFunction()],
  );
  print('Step 1: ${step1Config.audits.length} audits configured');

  // Step with custom retry configuration
  final step2Config = StepConfig(
    maxRetries: 5,
    audits: [ColorQualityAuditFunction()],
  );
  print('Step 2: Max retries = ${step2Config.maxRetries}');

  // Step with custom pass/fail criteria
  final step3Config = StepConfig(
    customPassCriteria: (issues) {
      // Custom logic: fail only if there are 3+ high severity issues
      final highIssues = issues
          .where(
            (i) =>
                i.severity == IssueSeverity.high ||
                i.severity == IssueSeverity.critical,
          )
          .length;
      return highIssues < 3;
    },
    customFailureReason: (issues) =>
        'Too many high-severity issues: ${issues.length}',
  );
  print(
    'Step 3: Has custom criteria = ${step3Config.customPassCriteria != null}',
  );

  // Step with no audits
  final step4Config = StepConfig();
  print('Step 4: Has audits = ${step4Config.hasAudits}');

  print('Step config examples demonstrated successfully');
}
