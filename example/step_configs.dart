/// Professional color workflow configuration and utilities.
///
/// This file demonstrates the 3-step professional color generation workflow
/// with expert-guided system messages and comprehensive color output.
/// 
/// Professional workflow steps:
/// 1. Generate seed colors with color theory expertise
/// 2. Generate design system colors with UX design expertise  
/// 3. Generate full color suite with design systems architecture expertise
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


}

/// Creates the professional color workflow configuration
Map<String, ToolCallStep> createProfessionalColorWorkflow() {
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


