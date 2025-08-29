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
      outputSchema: {
        'type': 'object',
        'properties': {
          'colors': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Array of hex color codes',
          },
          'confidence': {
            'type': 'number',
            'minimum': 0.0,
            'maximum': 1.0,
            'description': 'Confidence score for the extraction',
          },
        },
        'required': ['colors', 'confidence'],
      },
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
      outputSchema: {
        'type': 'object',
        'properties': {
          'colors': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Array of hex color codes',
          },
          'confidence': {
            'type': 'number',
            'minimum': 0.0,
            'maximum': 1.0,
            'description': 'Confidence score for the extraction',
          },
        },
        'required': ['colors', 'confidence'],
      },
    );
  }

  /// Configuration that forwards issues from previous steps
  static StepConfig forwardingIssuesConfig(List<int> stepIndexes) {
    return StepConfig(
      audits: [ColorQualityAuditFunction()],
      includeOutputsFrom: stepIndexes,
      outputSchema: {
        'type': 'object',
        'properties': {
          'colors': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Array of hex color codes',
          },
          'confidence': {
            'type': 'number',
            'minimum': 0.0,
            'maximum': 1.0,
            'description': 'Confidence score for the extraction',
          },
        },
        'required': ['colors', 'confidence'],
      },
    );
  }

  /// Configuration that forwards specific outputs
  static StepConfig forwardingOutputConfig(String toolName) {
    return StepConfig(
      includeOutputsFrom: [toolName],
      outputSchema: {
        'type': 'object',
        'properties': {
          'colors': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Array of hex color codes',
          },
          'confidence': {
            'type': 'number',
            'minimum': 0.0,
            'maximum': 1.0,
            'description': 'Confidence score for the extraction',
          },
        },
        'required': ['colors', 'confidence'],
      },
    );
  }

  /// Configuration with output sanitization
  static StepConfig sanitizingConfig(
    Map<String, dynamic> Function(Map<String, dynamic>) outputSanitizer,
  ) {
    return StepConfig(
      outputSanitizer: outputSanitizer,
      outputSchema: {
        'type': 'object',
        'properties': {
          'colors': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Array of hex color codes',
          },
          'confidence': {
            'type': 'number',
            'minimum': 0.0,
            'maximum': 1.0,
            'description': 'Confidence score for the extraction',
          },
        },
        'required': ['colors', 'confidence'],
      },
    );
  }

  /// Configuration that doesn't stop flow on failure
  static StepConfig get nonBlockingConfig {
    return StepConfig(
      audits: [ColorDiversityAuditFunction()],
      stopOnFailure: false,
      outputSchema: {
        'type': 'object',
        'properties': {
          'diversityScore': {'type': 'number'},
          'colors': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': ['diversityScore', 'colors'],
      },
    );
  }
}

/// Example output sanitizers for cleaning data between steps
class ExampleSanitizers {
  /// Sanitizes color palette output for refinement input
  static Map<String, dynamic> paletteToRefinementInputSanitizer({
    required Map<String, dynamic> input,
    required List<ToolResult> previousResults,
  }) {
    final sanitized = <String, dynamic>{};

    // Find the palette extraction result
    final paletteResult =
        previousResults.where((r) => r.toolName == 'extract_palette').isNotEmpty
        ? previousResults.where((r) => r.toolName == 'extract_palette').first
        : null;

    if (paletteResult != null) {
      final colors = paletteResult.output.toMap()['colors'] as List?;
      if (colors != null) {
        // Ensure colors are in the right format
        final cleanColors = colors
            .cast<String>()
            .where((color) => RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color))
            .take(8) // Limit to 8 colors max
            .toList();

        sanitized['colors'] = cleanColors;

        // Add confidence as context
        final confidence =
            paletteResult.output.toMap()['confidence'] as double?;
        if (confidence != null) {
          sanitized['source_confidence'] = confidence;
        }
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
      sanitized['colors'] = colors
          .cast<String>()
          .where((color) => RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color))
          .toList();
    }

    return sanitized;
  }

  /// Sanitizes refinement output for theme generation
  static Map<String, dynamic> refinementToThemeInputSanitizer({
    required Map<String, dynamic> input,
    required List<ToolResult> previousResults,
  }) {
    final sanitized = Map<String, dynamic>.from(input);

    // Get refined colors
    final refinementResult =
        previousResults.where((r) => r.toolName == 'refine_colors').isNotEmpty
        ? previousResults.where((r) => r.toolName == 'refine_colors').first
        : null;

    if (refinementResult != null) {
      final refinedColors =
          refinementResult.output.toMap()['refined_colors'] as List?;
      if (refinedColors != null && refinedColors.isNotEmpty) {
        sanitized['base_colors'] = refinedColors.take(4).toList();

        // Set primary color
        if (refinedColors.isNotEmpty) {
          sanitized['primary_color'] = refinedColors.first;
        }
      }
    }

    return sanitized;
  }

  /// Generic sanitizer that removes internal fields and formats data
  static Map<String, dynamic> genericInputSanitizer({
    required Map<String, dynamic> input,
    required List<ToolResult> previousResults,
  }) {
    final sanitized = Map<String, dynamic>.from(input);

    for (final result in previousResults) {
      // Add non-internal output fields with tool name prefix
      for (final entry in result.output.toMap().entries) {
        if (!entry.key.startsWith('_')) {
          sanitized['${result.toolName}_${entry.key}'] = entry.value;
        }
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

/// Demonstrates different step configuration patterns
void demonstrateStepConfigUsage() {
  print('🔧 Step Configuration Examples');
  print('==============================\n');

  // Different ways to configure steps
  final configs = {
    'Basic Audit': ExampleStepConfigs.basicAuditConfig,
    'Custom Retry': ExampleStepConfigs.customRetryConfig,
    'Forwarding Issues': ExampleStepConfigs.forwardingIssuesConfig([0, 1]),
    'Non-blocking': ExampleStepConfigs.nonBlockingConfig,
  };

  configs.forEach((name, config) {
    print('$name Configuration:');
    print('  Audits: ${config.audits.length}');
    print('  Max Retries: ${config.maxRetries ?? 'default'}');
    print('  Has Output Inclusion: ${config.hasOutputInclusion}');
    print('  Stop on Failure: ${config.stopOnFailure}');
    print('  Has Custom Criteria: ${config.customPassCriteria != null}');
    print('');
  });

  print('✅ Step configuration examples completed\n');
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
      inputBuilder: (previousResults) => PaletteExtractionInput(
        imagePath: 'assets/sample_image.jpg',
        maxColors: 8,
        minSaturation: 0.3,
        userPreferences: {'style': 'modern', 'mood': 'energetic'},
      ).toMap(),
      stepConfig: StepConfig(
        audits: [diversityAudit],
        maxRetries: 3,
        outputSchema: {
          'type': 'object',
          'properties': {
            'colors': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Extracted palette colors',
            },
            'diversityScore': {
              'type': 'number',
              'description': 'Score for color diversity',
            },
          },
          'required': ['colors', 'diversityScore'],
        },
      ),
    ),

    'refine_colors': ToolCallStep(
      toolName: 'refine_colors',
      model: 'gpt-4',
      inputBuilder: (previousResults) {
        // Extract colors from previous palette step
        final paletteResult =
            previousResults
                .where((r) => r.toolName == 'extract_palette')
                .isNotEmpty
            ? previousResults
                  .where((r) => r.toolName == 'extract_palette')
                  .first
            : null;

        final extractedColors = paletteResult?.output.toMap()['colors'] ?? [];

        return ColorRefinementInput(
          colors: extractedColors.cast<String>(),
          enhanceContrast: true,
          targetAccessibility: 'AA',
        ).toMap();
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
        outputSchema: {
          'type': 'object',
          'properties': {
            'colors': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Refined color list',
            },
            'contrastEnhanced': {
              'type': 'boolean',
              'description': 'Whether contrast was enhanced',
            },
          },
          'required': ['colors', 'contrastEnhanced'],
        },
      ),
    ),

    'generate_theme': ToolCallStep(
      toolName: 'generate_theme',
      model: 'gpt-4',
      inputBuilder: (previousResults) => {
        'theme_type': 'material_design',
        'include_variants': true,
      },
      stepConfig: StepConfig(
        audits: [],
        stopOnFailure: false,
        includeOutputsFrom: ['refine_colors'],
        inputSanitizer: ExampleSanitizers.refinementToThemeInputSanitizer,
        outputSchema: {
          'type': 'object',
          'properties': {
            'theme': {
              'type': 'object',
              'description': 'Generated theme object',
            },
            'variants': {
              'type': 'array',
              'items': {'type': 'object'},
              'description': 'Theme variants',
            },
          },
          'required': ['theme', 'variants'],
        },
      ),
    ),
  };
}
