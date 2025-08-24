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
  _registerTypedOutputs();

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

  // Create step configurations with different audits per step
  final stepConfigs = {
    // Step 0: Palette extraction - run diversity audit only
    0: StepConfig.withAudits([diversityAudit]),
    
    // Step 1: Color refinement - run format audit with custom retry logic
    1: StepConfig(
      audits: [colorFormatAudit],
      maxRetries: 5, // Override default retries for this step
      customPassCriteria: (issues) {
        // Custom criteria: pass if no medium or higher issues
        return !issues.any((issue) => 
          issue.severity == IssueSeverity.medium ||
          issue.severity == IssueSeverity.high ||
          issue.severity == IssueSeverity.critical
        );
      },
    ),
    
    // Step 2: Theme generation - no audits, but don't stop flow on failure
    2: StepConfig(
      audits: [],
      stopOnFailure: false, // Continue even if this step fails
    ),
  };

  // Create the tool flow with strongly-typed inputs
  final flow = ToolFlow(
    config: config,
    steps: [
      // Step 1: Extract base colors from image
      ToolCallStep(
        toolName: 'extract_palette',
        model: 'gpt-4',
        params: PaletteExtractionInput(
          imagePath: 'assets/sample_image.jpg',
          maxColors: 8,
          minSaturation: 0.3,
          userPreferences: {
            'style': 'modern',
            'mood': 'energetic',
          },
        ).toMap(),
        maxRetries: 3,
      ),
      
      // Step 2: Refine the extracted colors
      ToolCallStep(
        toolName: 'refine_colors',
        model: 'gpt-4',
        params: ColorRefinementInput(
          colors: [], // Will be populated from previous step
          enhanceContrast: true,
          targetAccessibility: 'AA',
        ).toMap(),
        maxRetries: 2,
      ),
      
      // Step 3: Generate final theme
      ToolCallStep(
        toolName: 'generate_theme',
        model: 'gpt-4',
        params: {
          'theme_type': 'material_design',
          'include_variants': true,
        },
        maxRetries: 1,
      ),
    ],
    stepConfigs: stepConfigs,
  );

  // Execute the flow
  try {
    print('🚀 Starting color theme generation...\n');
    
    final result = await flow.run(input: {
      'user_preferences': {
        'style': 'modern',
        'mood': 'energetic',
      },
    });

    print('✅ Flow completed!\n');
    
    // Display results with enhanced information
    print('📊 Execution Summary:');
    print('Steps executed: ${result.results.length}');
    print('Total issues found: ${result.allIssues.length}');
    print('Critical issues: ${result.issuesWithSeverity(IssueSeverity.critical).length}');
    print('High issues: ${result.issuesWithSeverity(IssueSeverity.high).length}');
    print('Medium issues: ${result.issuesWithSeverity(IssueSeverity.medium).length}');
    print('Low issues: ${result.issuesWithSeverity(IssueSeverity.low).length}\n');

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
          print('    ⚠️ ${issue.severity.name.toUpperCase()}$roundInfo: ${issue.description}');
          
          // Show ColorQualityIssue specific information
          if (issue is ColorQualityIssue) {
            print('      🎨 Problematic color: ${issue.problematicColor}');
            print('      📊 Quality score: ${issue.qualityScore.toStringAsFixed(2)}');
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
void _registerTypedOutputs() {
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
  final step1Config = StepConfig.withAudits([
    ColorQualityAuditFunction(),
    ColorDiversityAuditFunction(),
  ]);
  print('Step 1: ${step1Config.audits.length} audits configured');
  
  // Step with custom retry configuration
  final step2Config = StepConfig.withRetries(
    maxRetries: 5,
    audits: [ColorQualityAuditFunction()],
  );
  print('Step 2: Max retries = ${step2Config.maxRetries}');
  
  // Step with custom pass/fail criteria
  final step3Config = StepConfig.withCustomCriteria(
    passedCriteria: (issues) {
      // Custom logic: fail only if there are 3+ high severity issues
      final highIssues = issues.where((i) => 
        i.severity == IssueSeverity.high || 
        i.severity == IssueSeverity.critical
      ).length;
      return highIssues < 3;
    },
    failureReason: (issues) => 'Too many high-severity issues: ${issues.length}',
  );
  print('Step 3: Has custom criteria = ${step3Config.customPassCriteria != null}');
  
  // Step with no audits
  final step4Config = StepConfig.noAudits();
  print('Step 4: Has audits = ${step4Config.hasAudits}');
  
  print('Step config examples demonstrated successfully');
}