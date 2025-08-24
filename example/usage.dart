/// Example usage of the openai_toolflow package.
/// 
/// This example demonstrates how to create a color theme generation pipeline
/// that extracts colors from an image, refines them, and generates a final theme.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

void main() async {
  print('🎨 Color Theme Generator Example');
  print('=================================\n');

  // Create configuration (in practice, this would load from environment or .env)
  final config = OpenAIConfig(
    apiKey: 'your-api-key-here', // In practice: load from environment
    defaultModel: 'gpt-4',
    defaultTemperature: 0.7,
    defaultMaxTokens: 2000,
  );

  // Define audit functions
  final colorFormatAudit = SimpleAuditFunction(
    name: 'color_format_audit',
    auditFunction: (result) {
      final issues = <Issue>[];
      
      // Check if colors are in valid hex format
      final colors = result.output['colors'] as List?;
      if (colors != null) {
        for (int i = 0; i < colors.length; i++) {
          final color = colors[i] as String;
          if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
            issues.add(Issue(
              id: 'invalid_color_format_$i',
              severity: IssueSeverity.medium,
              description: 'Color $color is not in valid hex format',
              context: {
                'color_index': i,
                'color_value': color,
                'expected_format': '#RRGGBB',
              },
              suggestions: ['Convert to valid hex format'],
            ));
          }
        }
      }
      
      return issues;
    },
  );

  final diversityAudit = SimpleAuditFunction(
    name: 'color_diversity_audit',
    auditFunction: (result) {
      final issues = <Issue>[];
      
      // Check if we have enough colors
      final colors = result.output['colors'] as List?;
      if (colors == null || colors.length < 3) {
        issues.add(Issue(
          id: 'insufficient_colors',
          severity: IssueSeverity.high,
          description: 'Not enough colors extracted for a diverse palette',
          context: {
            'colors_found': colors?.length ?? 0,
            'minimum_required': 3,
          },
          suggestions: [
            'Adjust extraction parameters',
            'Try a different image with more color variety',
          ],
        ));
      }
      
      return issues;
    },
  );

  // Create the tool flow
  final flow = ToolFlow(
    config: config,
    steps: [
      // Step 1: Extract base colors from image
      ToolCallStep(
        toolName: 'extract_palette',
        model: 'gpt-4',
        params: {
          'max_colors': 8,
          'min_saturation': 0.3,
        },
      ),
      
      // Step 2: Refine the extracted colors
      ToolCallStep(
        toolName: 'refine_colors',
        model: 'gpt-4',
        params: {
          'enhance_contrast': true,
          'target_accessibility': 'AA',
        },
      ),
      
      // Step 3: Generate final theme
      ToolCallStep(
        toolName: 'generate_theme',
        model: 'gpt-4',
        params: {
          'theme_type': 'material_design',
          'include_variants': true,
        },
      ),
    ],
    audits: [colorFormatAudit, diversityAudit],
  );

  // Execute the flow
  try {
    print('🚀 Starting color theme generation...\n');
    
    final result = await flow.run(input: {
      'imagePath': 'assets/sample_image.jpg',
      'user_preferences': {
        'style': 'modern',
        'mood': 'energetic',
      },
    });

    print('✅ Flow completed successfully!\n');
    
    // Display results
    print('📊 Execution Summary:');
    print('Steps executed: ${result.results.length}');
    print('Issues found: ${result.allIssues.length}');
    print('Has critical issues: ${result.issuesWithSeverity(IssueSeverity.critical).isNotEmpty}\n');

    // Show step results
    for (int i = 0; i < result.results.length; i++) {
      final stepResult = result.results[i];
      print('Step ${i + 1}: ${stepResult.toolName}');
      print('  Output keys: ${stepResult.output.keys.join(', ')}');
      print('  Issues: ${stepResult.issues.length}');
      
      if (stepResult.issues.isNotEmpty) {
        for (final issue in stepResult.issues) {
          print('    ⚠️ ${issue.severity.name.toUpperCase()}: ${issue.description}');
        }
      }
      print('');
    }

    // Show final theme if available
    final finalOutput = result.finalOutput;
    if (finalOutput != null && finalOutput.containsKey('theme')) {
      print('🎨 Generated Theme:');
      final theme = finalOutput['theme'] as Map<String, dynamic>;
      theme.forEach((key, value) {
        print('  $key: $value');
      });
      print('');
    }

    // Show any issues that need attention
    final criticalIssues = result.issuesWithSeverity(IssueSeverity.critical);
    if (criticalIssues.isNotEmpty) {
      print('🚨 Critical Issues Requiring Attention:');
      for (final issue in criticalIssues) {
        print('  ${issue.description}');
        print('  Suggestions: ${issue.suggestions.join(', ')}');
      }
      print('');
    }

    // Export results as JSON for further processing
    print('📄 Full Results JSON:');
    print(formatJson(result.toJson()));
    
  } catch (e) {
    print('❌ Flow execution failed: $e');
  }
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

/// Example of extending the Issue class for custom audit needs
class ColorQualityIssue extends Issue {
  /// The color that caused the issue
  final String problematicColor;
  
  /// Quality score (0.0 to 1.0)
  final double qualityScore;

  ColorQualityIssue({
    required super.id,
    required super.severity,
    required super.description,
    required super.context,
    required super.suggestions,
    required this.problematicColor,
    required this.qualityScore,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['problematicColor'] = problematicColor;
    json['qualityScore'] = qualityScore;
    return json;
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