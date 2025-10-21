/// Display utilities for the professional color theme generator example.
///
/// This file contains all the display and formatting functions used to show
/// the results of the color theme generation workflow. These functions are
/// extracted from the main usage example to keep it focused on the core
/// package functionality.
library;

import 'package:openai_toolflow/openai_toolflow.dart';

/// Display token usage by step
void displayTokenUsageByStep(ToolFlow flow, ToolFlowResult result) {
  print('🔢 Token Usage by Step:');
  int totalPromptTokens = 0;
  int totalCompletionTokens = 0;
  int totalTokens = 0;

  // Skip initial input (index 0) and iterate through actual step results
  for (
    int stepIndex = 0;
    stepIndex < result.finalResults.length - 1;
    stepIndex++
  ) {
    final stepResult =
        result.finalResults[stepIndex + 1]; // +1 to skip initial input
    final toolName = stepResult.toolName;
    final tokenUsage = stepResult.tokenUsage;
    final promptTokens = tokenUsage.promptTokens;
    final completionTokens = tokenUsage.completionTokens;
    final stepTotalTokens = tokenUsage.totalTokens;

    // Add to totals
    totalPromptTokens += promptTokens;
    totalCompletionTokens += completionTokens;
    totalTokens += stepTotalTokens;

    print('  Step ${stepIndex + 1} ($toolName):');
    print('    Prompt tokens: $promptTokens');
    print('    Completion tokens: $completionTokens');
    print('    Total tokens: $stepTotalTokens');
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
void displayExecutionSummary(ToolFlowResult result) {
  print('📊 Enhanced Execution Summary:');
  print('Successful ToolFlowResult: ${result.passesCriteria}');
  print('Steps executed: ${result.results.length}');
  print(
    'Tools used: ${result.finalResults.map((r) => r.toolName).toSet().join(', ')}\n',
  );
}

/// Display professional workflow output usage examples
void displayWorkflowOutputUsage(ToolFlowResult result) {
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
void displayIssuesAnalysis(ToolFlowResult result) {
  if (result.allIssues.isEmpty) {
    print('🎉 No issues found in execution!\n');
    return;
  }

  // Group issues by round
  final issuesByRound = <int, List<Issue>>{};
  for (final issue in result.allIssues) {
    issuesByRound.putIfAbsent(issue.round, () => []).add(issue);
  }

  print('📈 Issues Analysis:');
  // Calculate total retries used across all steps
  int totalRetriesUsed = 0;
  for (final stepAttempts in result.results) {
    if (stepAttempts.length > 1) {
      // More than 1 attempt means retries occurred
      final retriesForStep =
          stepAttempts.length - 1; // Subtract 1 for initial attempt
      totalRetriesUsed += retriesForStep;
    }
  }
  print('\nTotal retries used: $totalRetriesUsed');

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

  // Group issues by step index (from relatedData['step_index'])
  final issuesByStep = <int, List<Issue>>{};
  for (final issue in result.allIssues) {
    final stepIndex = issue.relatedData?['step_index'];
    if (stepIndex != null) {
      issuesByStep.putIfAbsent(stepIndex, () => []).add(issue);
    } else {
      // If no step_index, group under -1 (unknown)
      issuesByStep.putIfAbsent(-1, () => []).add(issue);
    }
  }

  print('Issues by Step:');
  issuesByStep.forEach((step, issues) {
    final stepLabel = step >= 0 ? 'Step ${step + 1}' : 'Unknown Step';
    print('  $stepLabel: ${issues.length} issues');
    for (final issue in issues) {
      print('    - ${issue.severity.name}: ${issue.description}');
      // Show round and audit name if available
      final auditName = issue.relatedData?['audit_name'];
      if (issue.round > 0 || auditName != null) {
        final roundInfo = 'Round ${issue.round}';
        final auditInfo = auditName != null ? 'Audit: $auditName' : '';
        final details = [
          roundInfo,
          auditInfo,
        ].where((s) => s.isNotEmpty).join(', ');
        print('      ($details)');
      }
    }
  });
}
