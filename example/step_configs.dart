/// Configuration examples and utilities for the color theme generator.
///
/// This file demonstrates various ways to configure steps, audits, and
/// forwarding patterns for complex workflows.
/// 
/// Updated for Round 15: Redesigned workflow with 3-step process:
/// 1. Generate seed colors
/// 2. Generate design system colors 
/// 3. Generate full color suite
library;

import 'package:openai_toolflow/openai_toolflow.dart';

import 'audit_functions.dart';
import 'typed_interfaces.dart';

/// Example output sanitizers for cleaning data between steps
class ExampleSanitizers {
  /// Sanitizes seed color output for design system input
  static Map<String, dynamic> seedToDesignSystemInputSanitizer(
    Map<String, dynamic> input,
  ) {
    final sanitized = <String, dynamic>{};

    // Extract seed colors and pass forward
    if (input.containsKey('seed_colors')) {
      sanitized['seed_colors'] = input['seed_colors'];
    }

    // Add context from previous step
    if (input.containsKey('design_style')) {
      sanitized['design_context'] = input['design_style'];
    }
    if (input.containsKey('mood')) {
      sanitized['mood_context'] = input['mood'];
    }

    // Add other input data
    sanitized.addAll(input);
    return sanitized;
  }

  /// Sanitizes design system output for full suite input
  static Map<String, dynamic> designSystemToFullSuiteInputSanitizer(
    Map<String, dynamic> input,
  ) {
    final sanitized = <String, dynamic>{};

    // Extract system colors and pass forward
    if (input.containsKey('system_colors')) {
      sanitized['system_colors'] = input['system_colors'];
    }

    // Include accessibility context if available
    if (input.containsKey('accessibility_scores')) {
      sanitized['accessibility_context'] = input['accessibility_scores'];
    }

    // Include design principles context
    if (input.containsKey('design_principles')) {
      sanitized['design_principles_context'] = input['design_principles'];
    }

    sanitized.addAll(input);
    return sanitized;
  }

  /// Legacy sanitizer maintained for backward compatibility
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

  /// Legacy sanitizer maintained for backward compatibility
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

  /// Legacy sanitizer maintained for backward compatibility
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

/// Helper function to create the new comprehensive workflow configuration
Map<String, ToolCallStep> createImprovedColorThemeWorkflow() {
  // Define new step definitions
  final seedStep = SeedColorGenerationStepDefinition();
  final designSystemStep = DesignSystemColorStepDefinition();
  final fullSuiteStep = FullColorSuiteStepDefinition();

  // Define audit functions
  final colorFormatAudit = ColorQualityAuditFunction();
  final diversityAudit = ColorDiversityAuditFunction(
    minimumColors: 3,
    weightedThreshold: 2.5,
  );

  return {
    seedStep.stepName: ToolCallStep.fromStepDefinition(
      seedStep,
      model: 'gpt-4',
      inputBuilder: (previousResults) {
        final input = SeedColorGenerationInput(
          designStyle: 'modern',
          mood: 'professional',
          colorCount: 3,
          userPreferences: {'target_audience': 'business professionals'},
        ).toMap();
        return input;
      },
      stepConfig: StepConfig(
        audits: [diversityAudit],
        maxRetries: 3, // Explicitly set to 3 as required
      ),
    ),

    designSystemStep.stepName: ToolCallStep.fromStepDefinition(
      designSystemStep,
      model: 'gpt-4',
      inputBuilder: (previousResults) {
        // Extract seed colors from previous step
        final seedResult = previousResults
            .where((result) => result.hasOutputType<SeedColorGenerationOutput>())
            .first
            .asTyped<SeedColorGenerationOutput>();

        final input = DesignSystemColorInput(
          seedColors: seedResult.output.seedColors,
          targetAccessibility: 'AA',
          systemColorCount: 6,
          colorCategories: [
            'primary',
            'secondary', 
            'surface',
            'text',
            'warning',
            'error'
          ],
        ).toMap();

        return input;
      },
      buildInputsFrom: [seedStep.stepName],
      includeResultsInToolcall: [seedStep.stepName],
      stepConfig: StepConfig(
        issuesSeverityFilter: IssueSeverity.medium,
        audits: [colorFormatAudit],
        maxRetries: 3, // Explicitly set to 3 as required
        inputSanitizer: ExampleSanitizers.seedToDesignSystemInputSanitizer,
      ),
    ),

    fullSuiteStep.stepName: ToolCallStep.fromStepDefinition(
      fullSuiteStep,
      model: 'gpt-4',
      inputBuilder: (previousResults) {
        // Extract system colors from previous step
        final designSystemResult = previousResults
            .where((result) => result.hasOutputType<DesignSystemColorOutput>())
            .first
            .asTyped<DesignSystemColorOutput>();

        final input = FullColorSuiteInput(
          systemColors: designSystemResult.output.systemColors,
          suiteColorCount: 30,
          colorVariants: [
            'primaryText',
            'secondaryText',
            'interactiveText',
            'mutedText',
            'disabledText',
            'primaryBackground',
            'secondaryBackground',
            'surfaceBackground',
            'cardBackground',
            'overlayBackground',
            'hoverBackground',
            'errorBackground',
            'warningBackground',
            'successBackground',
            'infoBackground',
            'primaryBorder',
            'secondaryBorder',
            'focusBorder',
            'errorBorder',
            'warningBorder',
            'primaryButton',
            'secondaryButton',
            'disabledButton',
            'primaryLink',
            'visitedLink',
            'primaryIcon',
            'secondaryIcon',
            'warningIcon',
            'errorIcon',
            'successIcon'
          ],
          brandPersonality: 'professional',
        ).toMap();

        return input;
      },
      buildInputsFrom: [designSystemStep.stepName],
      includeResultsInToolcall: [designSystemStep.stepName],
      stepConfig: StepConfig(
        audits: [],
        stopOnFailure: false,
        maxRetries: 3, // Explicitly set to 3 as required
        inputSanitizer: ExampleSanitizers.designSystemToFullSuiteInputSanitizer,
      ),
    ),
  };
}

/// Legacy helper function maintained for backward compatibility
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
        final paletteResult = previousResults
            .where((result) => result.hasOutputType<PaletteExtractionOutput>())
            .first
            .asTyped<PaletteExtractionOutput>();

        final extractedColors = paletteResult.output.colors;
        final confidence = paletteResult.output.confidence;

        final input = ColorRefinementInput(
          colors: extractedColors.cast<String>(),
          confidence: confidence,
          enhanceContrast: true,
          targetAccessibility: 'AA',
        ).toMap();

        // Add metadata to input for inputSanitizer to remove later
        input['metadata'] = {
          'timestamp': DateTime.now().toIso8601String(),
          'message': 'Color refinement debug log',
        };

        return input;
      },
      // TODO: Should we consider just pulling ALL previous results forward and remove the need for buildInputsFrom?
      buildInputsFrom: [paletteStep.stepName],
      includeResultsInToolcall: [paletteStep.stepName],
      stepConfig: StepConfig(
        issuesSeverityFilter: IssueSeverity.medium,
        audits: [colorFormatAudit],
        maxRetries: 3, // Updated to match requirement
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
        final refinementResult = previousResults
            .where((result) => result.hasOutputType<ColorRefinementOutput>())
            .first
            .asTyped<ColorRefinementOutput>();

        List<String> baseColors = [];
        final refinedColors = refinementResult.output.refinedColors;
        if (refinedColors.isNotEmpty) {
          baseColors = refinedColors.take(4).toList();
        }

        return {
          'theme_type': 'material_design',
          if (baseColors.isNotEmpty) 'base_colors': baseColors,
          if (baseColors.isNotEmpty) 'primary_color': baseColors.first,
        };
      },
      buildInputsFrom: [refinementStep.stepName],
      includeResultsInToolcall: [refinementStep.stepName],
      stepConfig: StepConfig(
        audits: [],
        stopOnFailure: false,
        maxRetries: 3, // Explicitly set to 3 as required
        inputSanitizer: ExampleSanitizers.refinementToThemeInputSanitizer,
      ),
    ),
  };
}
