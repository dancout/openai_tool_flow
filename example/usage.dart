/// Example usage of the openai_toolflow package.
///
/// This example demonstrates how to create a color theme generation pipeline
/// that extracts colors from an image, refines them, and generates a final theme.
/// Features strongly-typed interfaces, per-step audits, and retry logic.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

import 'audit_functions.dart';
import 'typed_interfaces.dart';

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
      inputBuilder: (previousResults) {
        // Build the raw input
        // Note: This is the first step, so there are no previousResults to pull
        // from, which is why we are building an input and then converting it to
        // a map.
        final rawInput = PaletteExtractionInput(
          imagePath: 'assets/sample_image.jpg',
          maxColors: 8,
          minSaturation: 0.3,
          userPreferences: {'style': 'modern', 'mood': 'energetic'},
        ).toMap();
        // Add debugInfo for sanitizer demonstration
        return rawInput;
      },
      stepConfig: StepConfig(
        audits: [diversityAudit],
        maxRetries: 3,
        inputSanitizer: (input) {
          final sanitized = Map<String, dynamic>.from(input);
          // Remove unnecessary metadata to avoid token bloat
          sanitized.remove('metadata');
          return sanitized;
        },
        // TODO: It would be great if we could define these more programatically.
        /// Maybe even for the example we could have them be on the output type as --> output schema?
        /// Like PaletteExtractionOutput.outputSchema?
        outputSchema: OutputSchema(
          properties: {
            'colors': PropertyEntry(
              type: 'array',
              itemsType: PropertyEntry(type: 'string'),
              description: 'Extracted color hex codes',
            ),
            'confidence': PropertyEntry(
              type: 'number',
              description: 'Confidence score for extraction',
            ),
            'image_analyzed': PropertyEntry(
              type: 'string',
              description: 'Path to analyzed image',
            ),
            'metadata': PropertyEntry(
              type: 'object',
              description: 'Extraction metadata',
            ),
          },
          required: ['colors', 'confidence', 'image_analyzed'],
        ),
      ),
    ),

    // Step 2: Refine the extracted colors
    ToolCallStep(
      toolName: 'refine_colors',
      model: 'gpt-4',
      buildInputsFrom: ['extract_palette'],
      inputBuilder: (previousResults) {
        // Now we can dynamically build input based on actual previous results!
        final paletteResult = previousResults.first;
        final extractedColors =
            paletteResult.output.toMap()['colors'] as List<String>;

        return ColorRefinementInput(
          colors: extractedColors, // Populated from previous step!
          enhanceContrast: true,
          targetAccessibility: 'AA',
        ).toMap();
      },
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
        outputSchema: OutputSchema(
          properties: {
            'refined_colors': PropertyEntry(
              type: 'array',
              itemsType: PropertyEntry(type: 'string'),
              description: 'Refined color hex codes',
            ),
            'improvements_made': PropertyEntry(
              type: 'array',
              itemsType: PropertyEntry(type: 'string'),
              description: 'List of improvements applied',
            ),
          },
          required: ['refined_colors'],
        ),
      ),
    ),

    // Step 3: Generate final theme using refined colors
    ToolCallStep(
      toolName: 'generate_theme',
      model: 'gpt-4',
      buildInputsFrom: [
        'refine_colors',
      ], // Use refined colors from previous step
      inputBuilder: (previousResults) {
        // Extract refined colors from the previous step
        final refinementResult = previousResults.first;
        final refinedColors =
            refinementResult.output.toMap()['refined_colors'] as List<String>;

        return {'theme_type': 'material_design', 'base_colors': refinedColors};
      },
      stepConfig: StepConfig(
        audits: [],
        maxRetries: 1,
        stopOnFailure: false, // Continue even if this step fails
        outputSchema: OutputSchema(
          properties: {
            'theme': PropertyEntry(
              type: 'object',
              description: 'Generated theme object',
            ),
            'metadata': PropertyEntry(
              type: 'object',
              description: 'Theme generation metadata',
            ),
          },
          required: ['theme'],
        ),
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
      print('  Output keys: ${stepResult.output.toMap().keys.join(', ')}');
      print('  Issues: ${stepResult.issues.length}');

      // Show typed output information
      print('  Typed output type: ${stepResult.output.runtimeType}');

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
    if (lastResult.output is ThemeGenerationOutput) {
      final typedTheme = lastResult.output as ThemeGenerationOutput;
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

/// Example concrete implementation for theme generation output
class ThemeGenerationOutput extends ToolOutput {
  final Map<String, String> theme;
  final Map<String, dynamic> metadata;

  const ThemeGenerationOutput({required this.theme, this.metadata = const {}})
    : super.subclass();

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
