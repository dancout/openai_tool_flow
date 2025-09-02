/// Configuration examples and utilities for the color theme generator.
///
/// This file demonstrates various ways to configure steps, audits, and
/// forwarding patterns for complex workflows.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

import 'audit_functions.dart';
import 'typed_interfaces.dart';

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

/// Helper function to create a complete workflow configuration
Map<String, ToolCallStep> createColorThemeWorkflow() {
  // Define step definitions
  final paletteStep = PaletteExtractionStepDefinition();
  final refinementStep = ColorRefinementStepDefinition();
  final themeStep = ThemeGenerationStepDefinition();

  // Define audit functions
  final colorFormatAudit = ColorQualityAuditFunction();
  final diversityAudit = ColorDiversityAuditFunction(
    minimumColors: 4,
    weightedThreshold: 3.0,
  );

  return {
    paletteStep.stepName: ToolCallStep.fromStepDefinition(
      paletteStep,
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
      ),
    ),

    refinementStep.stepName: ToolCallStep.fromStepDefinition(
      refinementStep,
      model: 'gpt-4',
      inputBuilder: (previousResults) {
        // Extract colors and confidence from previous palette step
        final paletteResult =
            previousResults
                .where((r) => r.toolName == paletteStep.stepName)
                .isNotEmpty
            ? previousResults
                  .where((r) => r.toolName == paletteStep.stepName)
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
        // TODO: Related to how we can easily pull previous outputs/issues forward automatically for the user so they don't have to parse it.
        // This could be a tuple or new object with a bool that represents if we should include that step's issues in the final tool call.
        // That way, the user doesn't have to worry about how to parse it.
        // Or they could even have the option to override the issue parser for that step if they'd like.
        includeOutputsFrom: [paletteStep.stepName],
        // TODO: We could also include a "severity level" or similar name that specifies to include issues above a certain severity.
        /// That way, if there are a ton of low priority issues but 1 or 2 criticals, we may only be interested in the criticals and don't want token bloat.
        inputSanitizer: ExampleSanitizers.paletteToRefinementInputSanitizer,
        customPassCriteria: (issues) {
          return !issues.any(
            (issue) =>
                issue.severity == IssueSeverity.medium ||
                issue.severity == IssueSeverity.high ||
                issue.severity == IssueSeverity.critical,
          );
        },
      ),
    ),

    themeStep.stepName: ToolCallStep.fromStepDefinition(
      themeStep,
      model: 'gpt-4',
      inputBuilder: (previousResults) {
        // Extract refined colors from previous refinement step
        final refinementResult =
            previousResults
                .where((r) => r.toolName == refinementStep.stepName)
                .isNotEmpty
            ? previousResults
                  .where((r) => r.toolName == refinementStep.stepName)
                  .first
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
        includeOutputsFrom: [refinementStep.stepName],
        inputSanitizer: ExampleSanitizers.refinementToThemeInputSanitizer,
      ),
    ),
  };
}
