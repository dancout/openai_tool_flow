/// Configuration examples and utilities for the color theme generator.
///
/// This file demonstrates various ways to configure steps, audits, and
/// forwarding patterns for complex workflows.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

import 'audit_functions.dart';
import 'typed_interfaces.dart';

/// Example step configurations for different scenarios
class ExampleStepConfigs {
  /// Basic configuration with simple audit
  static StepConfig get basicAuditConfig {
    return StepConfig(
      audits: [ColorQualityAuditFunction()],
      outputSchema: OutputSchema(
        properties: [
          PropertyEntry.array(
            name: 'colors',
            items: PropertyEntry.string(name: 'color'),
            description: 'Array of hex color codes',
          ),
          PropertyEntry.number(
            name: 'confidence',
            minimum: 0.0,
            maximum: 1.0,
            description: 'Confidence score for the extraction',
          ),
        ],
        required: ['colors', 'confidence'],
      ),
    );
  }

  /// Configuration with custom retry logic
  static StepConfig get customRetryConfig {
    return StepConfig(
      audits: [ColorQualityAuditFunction()],
      maxRetries: 5,
      customPassCriteria: (issues) {
        // Custom criteria: pass if no medium or higher issues
        return !issues.any(
          (issue) =>
              issue.severity == IssueSeverity.medium ||
              issue.severity == IssueSeverity.high ||
              issue.severity == IssueSeverity.critical,
        );
      },
      outputSchema: OutputSchema(
        properties: [
          PropertyEntry.array(
            name: 'colors',
            items: PropertyEntry.string(name: 'color'),
            description: 'Array of hex color codes',
          ),
          PropertyEntry.number(
            name: 'confidence',
            minimum: 0.0,
            maximum: 1.0,
            description: 'Confidence score for the extraction',
          ),
        ],
        required: ['colors', 'confidence'],
      ),
    );
  }

  /// Configuration that forwards issues from previous steps
  static StepConfig forwardingIssuesConfig(List<int> stepIndexes) {
    return StepConfig(
      audits: [ColorQualityAuditFunction()],
      // TODO: Related to how we can easily pull previous outputs/issues forward automatically for the user so they don't have to parse it.
      // This could be a tuple or new object with a bool that represents if we should include that step's issues in the final tool call.
      // That way, the user doesn't have to worry about how to parse it.
      // Or they could even have the option to override the issue parser for that step if they'd like.
      includeOutputsFrom: stepIndexes,
      outputSchema: OutputSchema(
        properties: [
          PropertyEntry.array(
            name: 'colors',
            items: PropertyEntry.string(name: 'color'),
            description: 'Array of hex color codes',
          ),
          PropertyEntry.number(
            name: 'confidence',
            minimum: 0.0,
            maximum: 1.0,
            description: 'Confidence score for the extraction',
          ),
        ],
        required: ['colors', 'confidence'],
      ),
    );
  }

  /// Configuration that forwards specific outputs
  static StepConfig forwardingOutputConfig(String toolName) {
    return StepConfig(
      includeOutputsFrom: [toolName],
      outputSchema: OutputSchema(
        properties: [
          PropertyEntry.array(
            name: 'colors',
            items: PropertyEntry.string(name: 'color'),
            description: 'Array of hex color codes',
          ),
          PropertyEntry.number(
            name: 'confidence',
            minimum: 0.0,
            maximum: 1.0,
            description: 'Confidence score for the extraction',
          ),
        ],
        required: ['colors', 'confidence'],
      ),
    );
  }

  /// Configuration with output sanitization
  static StepConfig sanitizingConfig(
    Map<String, dynamic> Function(Map<String, dynamic>) outputSanitizer,
  ) {
    return StepConfig(
      outputSanitizer: outputSanitizer,
      outputSchema: OutputSchema(
        properties: [
          PropertyEntry.array(
            name: 'colors',
            items: PropertyEntry.string(name: 'color'),
            description: 'Array of hex color codes',
          ),
          PropertyEntry.number(
            name: 'confidence',
            minimum: 0.0,
            maximum: 1.0,
            description: 'Confidence score for the extraction',
          ),
        ],
        required: ['colors', 'confidence'],
      ),
    );
  }


}

/// Example output sanitizers for cleaning data between steps
class ExampleSanitizers {
  /// Sanitizes color palette output for refinement input
  static Map<String, dynamic> paletteToRefinementInputSanitizer(
    Map<String, dynamic> input,
  ) {
    final sanitized = <String, dynamic>{};

    // Remove extra metadata or debug fields if present
    sanitized.addAll(input);
    sanitized.remove('metadata');
    sanitized.remove('debugInfo');

    // Add confidence as context if present
    if (input.containsKey('confidence')) {
      final confidence = input['confidence'] as double?;
      if (confidence != null) {
        sanitized['source_confidence'] = confidence;
      }
    }

    // Include other input data
    sanitized.addAll(input);
    return sanitized;
  }

  /// Sanitizes output after color palette extraction
  static Map<String, dynamic> paletteOutputSanitizer(
    Map<String, dynamic> output,
  ) {
    final sanitized = Map<String, dynamic>.from(output);

    // Ensure colors are properly formatted
    final colors = sanitized['colors'] as List?;
    if (colors != null) {
      final cleanColors = colors
          .cast<String>()
          .map((color) {
            // If already a valid hex code with hashtag, keep as is
            if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
              return color;
            }
            // If it's a 6-digit hex string without hashtag, add hashtag
            if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(color)) {
              return '#$color';
            }
            // Otherwise, skip
            return null;
          })
          .whereType<String>()
          .toList();
      sanitized['colors'] = cleanColors;
    }

    return sanitized;
  }

  /// Sanitizes refinement input for theme generation
  static Map<String, dynamic> refinementToThemeInputSanitizer(
    Map<String, dynamic> input,
  ) {
    final sanitized = Map<String, dynamic>.from(input);

    // If base_colors is present, take up to 4 and set primary_color
    if (sanitized.containsKey('base_colors')) {
      final refinedColors = sanitized['base_colors'] as List?;
      if (refinedColors != null && refinedColors.isNotEmpty) {
        sanitized['base_colors'] = refinedColors.take(4).toList();
        sanitized['primary_color'] = refinedColors.first;
      }
    }

    return sanitized;
  }
}

/// Example issue filters for selective forwarding
class ExampleIssueFilters {
  /// Only forward critical and high severity issues
  static bool criticalAndHighOnly(Issue issue) {
    return issue.severity == IssueSeverity.critical ||
        issue.severity == IssueSeverity.high;
  }

  /// Only forward issues that mention specific keywords
  static bool Function(Issue) keywordFilter(List<String> keywords) {
    return (Issue issue) {
      final description = issue.description.toLowerCase();
      return keywords.any(
        (keyword) => description.contains(keyword.toLowerCase()),
      );
    };
  }

  /// Only forward recent issues (from the last round)
  static bool recentIssuesOnly(Issue issue) {
    return issue.round >= 0; // Adjust based on current round
  }

  /// Filter by issue ID pattern
  static bool Function(Issue) idPatternFilter(RegExp pattern) {
    return (Issue issue) => pattern.hasMatch(issue.id);
  }
}

/// Helper function to create a complete workflow configuration
Map<String, ToolCallStep> createColorThemeWorkflow() {
  // Define audit functions
  final colorFormatAudit = ColorQualityAuditFunction();
  final diversityAudit = ColorDiversityAuditFunction(
    minimumColors: 4,
    weightedThreshold: 3.0,
  );

  return {
    'extract_palette': ToolCallStep(
      toolName: 'extract_palette',
      model: 'gpt-4',
      inputBuilder: (previousResults) {
        final input = PaletteExtractionInput(
          imagePath: 'assets/sample_image.jpg',
          maxColors: 8,
          minSaturation: 0.3,
          userPreferences: {'style': 'modern', 'mood': 'energetic'},
        ).toMap();
        input['debugInfo'] = {
          'timestamp': DateTime.now().toIso8601String(),
          'message': 'Palette extraction debug log',
        };
        return input;
      },
      stepConfig: StepConfig(
        audits: [diversityAudit],
        maxRetries: 3,
        outputSanitizer: ExampleSanitizers.paletteOutputSanitizer,
        outputSchema: OutputSchema(
          properties: [
            PropertyEntry.array(
              name: 'colors',
              items: PropertyEntry.string(name: 'color'),
              description: 'Extracted palette colors',
            ),
            PropertyEntry.number(
              name: 'diversityScore',
              description: 'Score for color diversity',
            ),
          ],
          required: ['colors', 'diversityScore'],
        ),
      ),
    ),

    'refine_colors': ToolCallStep(
      toolName: 'refine_colors',
      model: 'gpt-4',
      inputBuilder: (previousResults) {
        // Extract colors and confidence from previous palette step
        final paletteResult =
            previousResults
                .where((r) => r.toolName == 'extract_palette')
                .isNotEmpty
            ? previousResults
                  .where((r) => r.toolName == 'extract_palette')
                  .first
            : null;

        final extractedColors = paletteResult?.output.toMap()['colors'] ?? [];
        final confidence =
            paletteResult?.output.toMap()['confidence'] as double?;

        final input = ColorRefinementInput(
          colors: extractedColors.cast<String>(),
          enhanceContrast: true,
          targetAccessibility: 'AA',
        ).toMap();

        // Add confidence to input for sanitizer
        if (confidence != null) {
          input['confidence'] = confidence;
        }

        return input;
      },
      stepConfig: StepConfig(
        audits: [colorFormatAudit],
        maxRetries: 5,
        includeOutputsFrom: ['extract_palette'],
        inputSanitizer: ExampleSanitizers.paletteToRefinementInputSanitizer,
        customPassCriteria: (issues) {
          return !issues.any(
            (issue) =>
                issue.severity == IssueSeverity.medium ||
                issue.severity == IssueSeverity.high ||
                issue.severity == IssueSeverity.critical,
          );
        },
        outputSchema: OutputSchema(
          properties: [
            PropertyEntry.array(
              name: 'colors',
              items: PropertyEntry.string(name: 'color'),
              description: 'Refined color list',
            ),
            PropertyEntry.boolean(
              name: 'contrastEnhanced',
              description: 'Whether contrast was enhanced',
            ),
          ],
          required: ['colors', 'contrastEnhanced'],
        ),
      ),
    ),

    'generate_theme': ToolCallStep(
      toolName: 'generate_theme',
      model: 'gpt-4',
      inputBuilder: (previousResults) {
        // Extract refined colors from previous refinement step
        final refinementResult =
            previousResults
                .where((r) => r.toolName == 'refine_colors')
                .isNotEmpty
            ? previousResults.where((r) => r.toolName == 'refine_colors').first
            : null;

        List<dynamic> baseColors = [];
        if (refinementResult != null) {
          final refinedColors =
              refinementResult.output.toMap()['refined_colors'] as List?;
          if (refinedColors != null && refinedColors.isNotEmpty) {
            baseColors = refinedColors.take(4).toList();
          }
        }

        return {
          'theme_type': 'material_design',
          if (baseColors.isNotEmpty) 'base_colors': baseColors,
          if (baseColors.isNotEmpty) 'primary_color': baseColors.first,
        };
      },
      stepConfig: StepConfig(
        audits: [],
        stopOnFailure: false,
        includeOutputsFrom: ['refine_colors'],
        inputSanitizer: ExampleSanitizers.refinementToThemeInputSanitizer,
        outputSchema: OutputSchema(
          properties: [
            PropertyEntry.object(
              name: 'theme',
              description: 'Generated theme object',
            ),
          ],
          required: ['theme'],
        ),
      ),
    ),
  };
}
