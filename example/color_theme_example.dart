/// Main usage example for the openai_toolflow package.
///
/// This example demonstrates how to create a color theme generation pipeline
/// that extracts colors from an image, refines them, and generates a final
/// theme. Features the new service injection architecture and enhanced step
/// configuration.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

import 'audit_functions.dart';
import 'step_configs.dart';
import 'typed_interfaces.dart';

// TODO: ColorThemeExample and Usage are kinda both showing an example of a color theme extraction. We should probably pick one and stick with it.
void main() async {
  print('🎨 Color Theme Generator Example (Round 3)');
  print('==========================================\n');

  // Register typed outputs for type safety
  registerColorThemeTypedOutputs();

  // Create configuration (in practice, this would load from environment)
  final config = OpenAIConfig(
    apiKey: 'your-api-key-here', // Load from environment in production
    defaultModel: 'gpt-4',
    defaultTemperature: 0.7,
    defaultMaxTokens: 2000,
  );

  // Create a mock service for demonstration (use real service in production)
  final mockService = MockOpenAiToolService(
    responses: {
      'extract_palette': {
        // NOTE: Some of these colors are missing the leading '#', which will
        // be taken care of by the ExampleSanitizers.paletteOutputSanitizer
        'colors': ['#FF5733', '33FF57', '3357FF', '#F333FF', '#FF33F5'],
        'confidence': 0.85,
        'image_analyzed': 'assets/sample_image.jpg',
        'metadata': {'extraction_method': 'k-means', 'processing_time': 2.3},
        'debugInfo': 'Palette extraction debug log',
      },
      'refine_colors': {
        'refined_colors': ['#E74C3C', '#2ECC71', '#3498DB', '#9B59B6'],
        'improvements_made': [
          'contrast adjustment',
          'saturation optimization',
          'accessibility compliance',
        ],
        'accessibility_scores': {
          '#E74C3C': 4.5,
          '#2ECC71': 7.2,
          '#3498DB': 6.8,
          '#9B59B6': 5.1,
        },
      },
      'generate_theme': {
        'theme': {
          'primary': '#E74C3C',
          'secondary': '#2ECC71',
          'accent': '#3498DB',
          'background': '#FFFFFF',
          'surface': '#F8F9FA',
        },
        'metadata': {
          'generated_at': DateTime.now().toIso8601String(),
          'theme_style': 'material_design',
          'accessibility_level': 'AA',
        },
      },
    },
  );

  // Create the workflow steps with enhanced configuration
  final workflow = createColorThemeWorkflow();
  final steps = workflow.values.toList();

  // Create the tool flow with the new service architecture
  final flow = ToolFlow(
    config: config,
    steps: steps,
    openAiService: mockService, // Inject mock service for testing
  );

  // Execute the flow
  try {
    print('🚀 Starting color theme generation with enhanced features...\n');

    final result = await flow.run(
      input: {
        'user_preferences': {'style': 'modern', 'mood': 'energetic'},
        'target_accessibility': 'AA',
      },
    );

    print('✅ Flow completed with enhanced result management!\n');

    // Display enhanced execution summary
    _displayExecutionSummary(result);

    // Demonstrate tool name-based retrieval
    _demonstrateToolNameRetrieval(result);

    // Display step results with forwarding information
    _displayStepResultsWithForwarding(result);

    // Display typed output usage
    _displayTypedOutputUsage(result);

    // Show issues analysis by round and forwarding
    _displayIssuesAnalysis(result);

    // Export enhanced results
    _exportEnhancedResults(result);
  } catch (e) {
    print('❌ Flow execution failed: $e');
  }
}

/// Display enhanced execution summary
void _displayExecutionSummary(ToolFlowResult result) {
  print('📊 Enhanced Execution Summary:');
  print('Steps executed: ${result.results.length}');
  print('Tools used: ${result.resultsByToolName.keys.join(', ')}');
  print('Total issues found: ${result.allIssues.length}');
  print(
    'Critical issues: ${result.issuesWithSeverity(IssueSeverity.critical).length}',
  );
  print('High issues: ${result.issuesWithSeverity(IssueSeverity.high).length}');
  print(
    'Medium issues: ${result.issuesWithSeverity(IssueSeverity.medium).length}',
  );
  print('Low issues: ${result.issuesWithSeverity(IssueSeverity.low).length}\n');
}

/// Demonstrate tool name-based result retrieval
void _demonstrateToolNameRetrieval(ToolFlowResult result) {
  print('🔍 Tool Name-Based Retrieval:');

  // Single tool retrieval
  final paletteResult = result.getResultByToolName('extract_palette');
  if (paletteResult != null) {
    print(
      '  Extract Palette: Found result with ${paletteResult.output.toMap().keys.length} output keys',
    );
  }

  // Multiple tool retrieval
  final multipleResults = result.getResultsByToolNames([
    'extract_palette',
    'refine_colors',
  ]);
  print('  Multiple tools: Retrieved ${multipleResults.length} results');

  // Results where condition
  final successfulResults = result.getResultsWhere((r) => r.issues.isEmpty);
  print('  Successful steps: ${successfulResults.length} steps had no issues');
  print('');
}

/// Display step results with forwarding information
void _displayStepResultsWithForwarding(ToolFlowResult result) {
  print('📋 Step Results with Forwarding Info:');

  for (int i = 0; i < result.results.length; i++) {
    final stepResult = result.results[i];
    print('Step ${i + 1}: ${stepResult.toolName}');
    print('  Output keys: ${stepResult.output.toMap().keys.join(', ')}');
    print('  Issues: ${stepResult.issues.length}');

    // Check for forwarded data
    final forwardedKeys = stepResult.input
        .toMap()
        .keys
        .where((key) => key.startsWith('_forwarded_') || key.contains('_'))
        .toList();

    if (forwardedKeys.isNotEmpty) {
      print('  Forwarded data: ${forwardedKeys.join(', ')}');
    }

    if (stepResult.issues.isNotEmpty) {
      for (final issue in stepResult.issues) {
        final roundInfo = issue.round > 0 ? ' (Round ${issue.round})' : '';
        print(
          '    ⚠️ ${issue.severity.name.toUpperCase()}$roundInfo: ${issue.description}',
        );

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
}

/// Display typed output usage examples
void _displayTypedOutputUsage(ToolFlowResult result) {
  print('🔧 Typed Output Usage:');

  final lastResult = result.results.last;
  // In Round 6, we use the output directly as ToolOutput
  final outputMap = lastResult.output.toMap();
  if (outputMap.containsKey('theme')) {
    print('  Theme Output:');
    final theme = outputMap['theme'] as Map<String, dynamic>?;
    if (theme != null) {
      theme.forEach((key, value) {
        print('    $key: $value');
      });
    }
    final metadata = outputMap['metadata'] as Map<String, dynamic>?;
    if (metadata != null && metadata.containsKey('generated_at')) {
      print('    Generated at: ${metadata['generated_at']}');
    }
  }
  print('');
}

/// Display issues analysis by round and forwarding
void _displayIssuesAnalysis(ToolFlowResult result) {
  if (result.allIssues.isEmpty) {
    print('🎉 No issues found in execution!\n');
    return;
  }

  // Group issues by round
  final issuesByRound = <int, List<Issue>>{};
  for (final issue in result.allIssues) {
    issuesByRound.putIfAbsent(issue.round, () => []).add(issue);
  }

  print('📈 Issues Analysis by Retry Round:');
  issuesByRound.forEach((round, issues) {
    print('  Round $round: ${issues.length} issues');
    for (final issue in issues) {
      print('    - ${issue.severity.name}: ${issue.description}');

      // Show related data if available
      if (issue.relatedData != null && issue.relatedData!.isNotEmpty) {
        final stepIndex = issue.relatedData!['step_index'];
        final auditName = issue.relatedData!['audit_name'];
        if (stepIndex != null && auditName != null) {
          print('      (Step $stepIndex, Audit: $auditName)');
        }
      }
    }
  });

  // Show critical issues that need attention
  final criticalIssues = result.issuesWithSeverity(IssueSeverity.critical);
  if (criticalIssues.isNotEmpty) {
    print('\n🚨 Critical Issues Requiring Attention:');
    for (final issue in criticalIssues) {
      print('  ${issue.description}');
      print('  Suggestions: ${issue.suggestions.join(', ')}');
    }
  }
  print('');
}

/// Export enhanced results with new features
void _exportEnhancedResults(ToolFlowResult result) {
  print('📄 Enhanced Results Export:');

  // Show final theme
  final finalOutput = result.finalOutput;
  if (finalOutput != null && finalOutput.containsKey('theme')) {
    print('🎨 Generated Theme:');
    final theme = finalOutput['theme'] as Map<String, dynamic>;
    theme.forEach((key, value) {
      print('  $key: $value');
    });
    print('');
  }

  // Summary statistics
  final stats = {
    'total_steps': result.results.length,
    'successful_steps': result.results.where((r) => r.issues.isEmpty).length,
    'total_issues': result.allIssues.length,
    'tools_used': result.resultsByToolName.keys.toList(),
    'outputs_available': result.results.isNotEmpty,
  };

  print('📊 Execution Statistics:');
  stats.forEach((key, value) {
    print('  $key: $value');
  });
  print('');

  // Tool name mapping for easy reference
  print('🗂️ Tool Name Mapping:');
  result.resultsByToolName.forEach((toolName, toolResult) {
    final stepIndex = result.results.indexOf(toolResult);
    print('  $toolName -> Step ${stepIndex + 1}');
  });
  print('');

  print('✅ Enhanced color theme generation example completed!');
}
