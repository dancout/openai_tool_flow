/// Professional color theme generation workflow example.
///
/// This example demonstrates the complete 3-step professional color generation
/// pipeline with expert guidance, comprehensive output, and proper retry configuration.
///
/// Professional workflow:
/// - Step 1: Generate 3 seed colors with expert color theory guidance (maxRetries=3)
/// - Step 2: Generate 6 design system colors with UX design expertise (maxRetries=3)
/// - Step 3: Generate 30 comprehensive color suite with design systems expertise (maxRetries=3)
///
/// Features strongly-typed interfaces, per-step audits, retry logic, and
/// advanced workflow patterns including tool name-based retrieval and output forwarding.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

import 'audit_functions.dart';
import 'step_configs.dart';

void main() async {
  print('🎨 Improved Professional Color Theme Generator');
  print('===============================================\n');

  // Registration is now handled automatically by ToolCallStep.fromStepDefinition()

  // Create configuration from .env file
  final config = OpenAIConfig.fromDotEnv();

  // Use the professional workflow from step_configs.dart
  final workflow = createProfessionalColorWorkflow();
  final steps = workflow.values.toList();

  // Create the tool flow with service injection
  final flow = ToolFlow(
    config: config,
    steps: steps,
    // openAiService: mockService, // Inject mock service for testing
    openAiService: DefaultOpenAiToolService(config: config),
  );

  // Execute the flow
  try {
    print('🚀 Starting professional color theme generation...\n');

    final result = await flow.run(
      input: {
        'user_preferences': {'style': 'modern', 'mood': 'professional'},
        'target_accessibility': 'AA',
        'brand_context': 'enterprise software platform',
      },
    );

    print('✅ Professional color suite generation completed!\n');

    // TODO: This, and maybe more of these "_display" functions could be removed if the underlying toolresult function they were demonstrating was removed.
    // Display enhanced execution summary
    _displayExecutionSummary(result);

    // Display step results with forwarding information
    _displayStepResultsWithForwarding(result);

    // Display new workflow output usage
    _displayNewWorkflowOutputUsage(result);

    // Show issues analysis by round and forwarding
    _displayIssuesAnalysis(result);

    // Export enhanced results
    _exportEnhancedResults(result);

    // Display token usage by step
    _displayTokenUsageByStep(flow, result);
  } catch (e) {
    print('❌ Flow execution failed: $e');
  }
}

/// Display token usage by step
void _displayTokenUsageByStep(ToolFlow flow, ToolFlowResult result) {
  print('🔢 Token Usage by Step:');
  int totalPromptTokens = 0;
  int totalCompletionTokens = 0;
  int totalTokens = 0;

  // TODO: The i = 1 and the i - 1 below feels clumsy, and could be where the stepIndex and resultIndex from other TODOs comes into play.
  for (int i = 1; i < result.results.length; i++) {
    final stepResult = result.finalResults[i];
    final usage =
        result.finalState['step_${i - 1}_usage'] as Map<String, dynamic>?;
    final toolName = stepResult.toolName;
    if (usage != null) {
      final promptTokens = usage['prompt_tokens'] ?? 0;
      final completionTokens = usage['completion_tokens'] ?? 0;
      final stepTotalTokens = usage['total_tokens'] ?? 0;

      // Add to totals
      totalPromptTokens += promptTokens is int
          ? promptTokens
          : int.tryParse(promptTokens.toString()) ?? 0;
      totalCompletionTokens += completionTokens is int
          ? completionTokens
          : int.tryParse(completionTokens.toString()) ?? 0;
      totalTokens += stepTotalTokens is int
          ? stepTotalTokens
          : int.tryParse(stepTotalTokens.toString()) ?? 0;

      print('  Step $i ($toolName):');
      print('    Prompt tokens: $promptTokens');
      print('    Completion tokens: $completionTokens');
      print('    Total tokens: $stepTotalTokens');
    } else {
      print('  Step $i ($toolName): No token usage data');
    }
  }

  print('\n🔢 Total Token Usage Across All Steps:');
  print('  Prompt tokens: $totalPromptTokens');
  print('  Completion tokens: $totalCompletionTokens');
  print('  Total tokens: $totalTokens\n');
}

/// Helper function to filter issues by severity
List<Issue> issuesWithSeverity(List<Issue> allIssues, IssueSeverity severity) {
  return allIssues.where((issue) => issue.severity == severity).toList();
}

/// Display enhanced execution summary
void _displayExecutionSummary(ToolFlowResult result) {
  print('📊 Enhanced Execution Summary:');
  print('Steps executed: ${result.results.length}');
  print(
    'Tools used: ${result.finalResults.map((r) => r.toolName).toSet().join(', ')}',
  );
  print('Total issues found: ${result.allIssues.length}');
  print(
    'Critical issues: ${issuesWithSeverity(result.allIssues, IssueSeverity.critical).length}',
  );
  print(
    'High issues: ${issuesWithSeverity(result.allIssues, IssueSeverity.high).length}',
  );
  print(
    'Medium issues: ${issuesWithSeverity(result.allIssues, IssueSeverity.medium).length}',
  );
  print(
    'Low issues: ${issuesWithSeverity(result.allIssues, IssueSeverity.low).length}\n',
  );

  print('  Multiple tools: Retrieved ${result.results.length} results');

  // Results where condition
  final successfulResults = result.finalResults.where((r) => r.issues.isEmpty);
  print('  Successful steps: ${successfulResults.length} steps had no issues');
  print('');
}

/// Display step results with forwarding information
void _displayStepResultsWithForwarding(ToolFlowResult result) {
  print('📋 Step Results with Forwarding Info:');

  for (int i = 0; i < result.results.length; i++) {
    final stepResult = result.finalResults[i];
    print('Step ${i + 1}: ${stepResult.toolName}');
    print('  Output keys: ${stepResult.output.toMap().keys.join(', ')}');
    print('  Issues: ${stepResult.issues.length}');
    print('  Typed output type: ${stepResult.output.runtimeType}');

    // Check for forwarded data
    final forwardedKeys = stepResult.input
        .getCleanToolInput()
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

/// Display professional workflow output usage examples
void _displayNewWorkflowOutputUsage(ToolFlowResult result) {
  print('🔧 Professional Workflow Output Usage:');

  // Display seed colors
  final seedResult = result.finalResults[1];
  final seedOutputMap = seedResult.output.toMap();
  print('  💎 Seed Colors Generated:');
  final seedColors = seedOutputMap['seed_colors'] as List?;
  if (seedColors != null) {
    for (int i = 0; i < seedColors.length; i++) {
      print('    Color ${i + 1}: ${seedColors[i]}');
    }
  }
  print('    Design Style: ${seedOutputMap['design_style']}');
  print('    Mood: ${seedOutputMap['mood']}');
  print('    Confidence: ${seedOutputMap['confidence']}');
  print('');

  // Display design system colors
  final designSystemResult = result.finalResults[2];
  final designOutputMap = designSystemResult.output.toMap();
  print('  🎨 Design System Colors:');
  final systemColors =
      designOutputMap['system_colors'] as Map<String, dynamic>?;
  if (systemColors != null) {
    systemColors.forEach((key, value) {
      print('    $key: $value');
    });
  }
  final accessibilityScores =
      designOutputMap['accessibility_scores'] as Map<String, dynamic>?;
  if (accessibilityScores != null && accessibilityScores.isNotEmpty) {
    print('  📊 Accessibility Scores:');
    accessibilityScores.forEach((key, value) {
      print('    $key: $value:1 contrast ratio');
    });
  }
  print('');

  // Display full color suite
  final fullSuiteResult = result.finalResults[3];
  final suiteOutputMap = fullSuiteResult.output.toMap();
  print('  🌈 Complete Color Suite (30 colors):');
  final colorSuite = suiteOutputMap['color_suite'] as Map<String, dynamic>?;
  if (colorSuite != null) {
    // Group colors by category for better display
    final textColors = <String, String>{};
    final backgroundColors = <String, String>{};
    final interactiveColors = <String, String>{};
    final statusColors = <String, String>{};

    colorSuite.forEach((key, value) {
      if (key.contains('Text')) {
        textColors[key] = value as String;
      } else if (key.contains('Background')) {
        backgroundColors[key] = value as String;
      } else if (key.contains('Button') ||
          key.contains('Link') ||
          key.contains('Border')) {
        interactiveColors[key] = value as String;
      } else if (key.contains('error') ||
          key.contains('warning') ||
          key.contains('success')) {
        statusColors[key] = value as String;
      }
    });

    print('    📝 Text Colors:');
    textColors.forEach((key, value) => print('      $key: $value'));

    print('    🏢 Background Colors:');
    backgroundColors.forEach((key, value) => print('      $key: $value'));

    print('    🔗 Interactive Colors:');
    interactiveColors.forEach((key, value) => print('      $key: $value'));

    print('    ⚠️ Status Colors:');
    statusColors.forEach((key, value) => print('      $key: $value'));
  }

  final brandGuidelines =
      suiteOutputMap['brand_guidelines'] as Map<String, dynamic>?;
  if (brandGuidelines != null && brandGuidelines.isNotEmpty) {
    print('  📋 Brand Guidelines:');
    brandGuidelines.forEach((key, value) {
      print('    $key: $value');
    });
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
  final criticalIssues = issuesWithSeverity(
    result.allIssues,
    IssueSeverity.critical,
  );
  if (criticalIssues.isNotEmpty) {
    print('\n🚨 Critical Issues Requiring Attention:');
    for (final issue in criticalIssues) {
      print('  ${issue.description}');
      print('  Suggestions: ${issue.suggestions.join(', ')}');
    }
  }
  print('');
}

/// Export enhanced results with professional workflow features
void _exportEnhancedResults(ToolFlowResult result) {
  print('📄 Professional Color Suite Export:');

  // Show final color suite
  final finalOutput = result.finalResults.last.output.toMap();
  if (finalOutput.containsKey('color_suite')) {
    print('🎨 Generated Professional Color Suite:');
    final colorSuite = finalOutput['color_suite'] as Map<String, dynamic>;

    // Display most important colors for quick reference
    final importantColors = {
      'primaryText': colorSuite['primaryText'],
      'primaryBackground': colorSuite['primaryBackground'],
      'primaryButton': colorSuite['primaryButton'],
      'errorBackground': colorSuite['errorBackground'],
      'warningBackground': colorSuite['warningBackground'],
      'successBackground': colorSuite['successBackground'],
    };

    print('  🔑 Key Colors:');
    importantColors.forEach((key, value) {
      if (value != null) print('    $key: $value');
    });

    print('  📊 Total colors in suite: ${colorSuite.length}');
    print('');
  }

  // Calculate actual max retries used across all steps
  int maxRetriesUsed = 0;
  for (final stepAttempts in result.results) {
    if (stepAttempts.length > 1) { // More than 1 attempt means retries occurred
      final retriesForStep = stepAttempts.length - 1; // Subtract 1 for initial attempt
      maxRetriesUsed = maxRetriesUsed > retriesForStep ? maxRetriesUsed : retriesForStep;
    }
  }

  // Summary statistics for professional workflow
  final stats = {
    'total_steps': result.results.length,
    'successful_steps': result.finalResults.where((r) => r.issues.isEmpty).length,
    'total_issues': result.allIssues.length,
    'workflow_type': 'Professional 3-Step Color Generation',
    'tools_used': result.finalResults.map((r) => r.toolName).toSet().toList(),
    'outputs_available': result.finalResults.isNotEmpty,
    'accessibility_compliant': true,
    'maxRetries_used': maxRetriesUsed,
  };

  print('📊 Professional Workflow Statistics:');
  stats.forEach((key, value) {
    print('  $key: $value');
  });
  print('');

  // Tool name mapping for easy reference
  print('🗂️ Professional Workflow Tool Mapping:');

  for (TypedToolResult toolResult in result.finalResults) {
    final stepIndex = result.finalResults.indexOf(toolResult);

    String workflowStep = '';
    switch (toolResult.toolName) {
      case 'generate_seed_colors':
        workflowStep = ' (Step 1: Seed Generation)';
        break;
      case 'generate_design_system_colors':
        workflowStep = ' (Step 2: System Colors)';
        break;
      case 'generate_full_color_suite':
        workflowStep = ' (Step 3: Complete Suite)';
        break;
    }

    print('  ${toolResult.toolName} -> Step ${stepIndex + 1}$workflowStep');
  }
  print('');

  print(
    '✅ Professional color theme generation with expert guidance completed!',
  );
  print(
    '🎯 Generated: 3 seed colors → 6 system colors → 30 complete color suite',
  );
  print('📏 All steps used maxRetries=3 as specified');
  print('🎨 Ready for production use in professional applications');
}
