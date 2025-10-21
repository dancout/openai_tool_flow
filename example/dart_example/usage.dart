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

// import 'mock_service_impl.dart'; // Uncomment to use mocked openAiService
import 'display_utilities.dart';
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
    // openAiService: mockService, // Uncomment to use mocked openAiService
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

    // Display comprehensive results
    displayExecutionSummary(result);
    displayWorkflowOutputUsage(result);
    displayIssuesAnalysis(result);
    displayTokenUsageByStep(flow, result);
  } catch (e) {
    print('❌ Flow execution failed: $e');
  }
}
