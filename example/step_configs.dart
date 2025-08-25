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
    );
  }

  /// Configuration that forwards issues from previous steps
  static StepConfig forwardingIssuesConfig(List<int> stepIndexes) {
    return StepConfig(
      audits: [ColorQualityAuditFunction()],
      forwardingConfigs: stepIndexes
          .map((index) => ForwardingConfig.issuesOnly(index))
          .toList(),
    );
  }

  /// Configuration that forwards specific outputs
  static StepConfig forwardingOutputConfig(String toolName, List<String> keys) {
    return StepConfig(
      forwardingConfigs: [
        ForwardingConfig.outputOnly(toolName, outputKeys: keys),
      ],
    );
  }

  /// Configuration with output sanitization
  static StepConfig sanitizingConfig(
    Map<String, dynamic> Function(List<ToolResult>) sanitizer,
  ) {
    return StepConfig(
      outputSanitizer: sanitizer,
    );
  }

  /// Configuration that doesn't stop flow on failure
  static StepConfig get nonBlockingConfig {
    return StepConfig(
      audits: [ColorDiversityAuditFunction()],
      stopOnFailure: false,
    );
  }
}

/// Example output sanitizers for cleaning data between steps
class ExampleSanitizers {
  /// Sanitizes color palette output for refinement input
  static Map<String, dynamic> paletteToRefinementSanitizer(
    List<ToolResult> previousResults,
  ) {
    final sanitized = <String, dynamic>{};

    // Find the palette extraction result
    final paletteResult = previousResults
        .where((r) => r.toolName == 'extract_palette')
        .firstOrNull;

    if (paletteResult != null) {
      final colors = paletteResult.output['colors'] as List?;
      if (colors != null) {
        // Ensure colors are in the right format
        final cleanColors = colors
            .cast<String>()
            .where((color) => RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color))
            .take(8) // Limit to 8 colors max
            .toList();

        sanitized['colors'] = cleanColors;
        
        // Add confidence as context
        final confidence = paletteResult.output['confidence'] as double?;
        if (confidence != null) {
          sanitized['source_confidence'] = confidence;
        }
      }
    }

    return sanitized;
  }

  /// Sanitizes refinement output for theme generation
  static Map<String, dynamic> refinementToThemeSanitizer(
    List<ToolResult> previousResults,
  ) {
    final sanitized = <String, dynamic>{};

    // Get refined colors
    final refinementResult = previousResults
        .where((r) => r.toolName == 'refine_colors')
        .firstOrNull;

    if (refinementResult != null) {
      final refinedColors = refinementResult.output['refined_colors'] as List?;
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
  static Map<String, dynamic> genericSanitizer(
    List<ToolResult> previousResults,
  ) {
    final sanitized = <String, dynamic>{};

    for (final result in previousResults) {
      // Add non-internal output fields with tool name prefix
      for (final entry in result.output.entries) {
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
      return keywords.any((keyword) => description.contains(keyword.toLowerCase()));
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
    print('  Has Forwarding: ${config.hasForwarding}');
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
      params: PaletteExtractionInput(
        imagePath: 'assets/sample_image.jpg',
        maxColors: 8,
        minSaturation: 0.3,
        userPreferences: {'style': 'modern', 'mood': 'energetic'},
      ).toMap(),
      stepConfig: StepConfig(
        audits: [diversityAudit],
        maxRetries: 3,
      ),
    ),

    'refine_colors': ToolCallStep(
      toolName: 'refine_colors',
      model: 'gpt-4',
      params: ColorRefinementInput(
        colors: [], // Will be populated from previous step
        enhanceContrast: true,
        targetAccessibility: 'AA',
      ).toMap(),
      stepConfig: StepConfig(
        audits: [colorFormatAudit],
        maxRetries: 5,
        forwardingConfigs: [
          ForwardingConfig.outputOnly('extract_palette', outputKeys: ['colors']),
        ],
        outputSanitizer: ExampleSanitizers.paletteToRefinementSanitizer,
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

    'generate_theme': ToolCallStep(
      toolName: 'generate_theme',
      model: 'gpt-4',
      params: {'theme_type': 'material_design', 'include_variants': true},
      stepConfig: StepConfig(
        audits: [],
        stopOnFailure: false,
        forwardingConfigs: [
          ForwardingConfig.outputOnly('refine_colors', outputKeys: ['refined_colors']),
          ForwardingConfig.issuesOnly(
            'extract_palette',
            issueFilter: ExampleIssueFilters.criticalAndHighOnly,
          ),
        ],
        outputSanitizer: ExampleSanitizers.refinementToThemeSanitizer,
      ),
    ),
  };
}