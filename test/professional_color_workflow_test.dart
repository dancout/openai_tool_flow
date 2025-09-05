/// Test for the professional color workflow implementation
import 'package:test/test.dart';
import 'package:openai_toolflow/openai_toolflow.dart';

import '../example/step_configs.dart';
import '../example/typed_interfaces.dart';

void main() {
  group('Professional Color Workflow Tests', () {
    test('professional workflow has 3 steps with correct step names', () {
      final workflow = createProfessionalColorWorkflow();
      
      expect(workflow.length, equals(3));
      expect(workflow.keys, contains('generate_seed_colors'));
      expect(workflow.keys, contains('generate_design_system_colors'));
      expect(workflow.keys, contains('generate_full_color_suite'));
    });

    test('all steps have maxRetries set to 3', () {
      final workflow = createProfessionalColorWorkflow();
      
      for (final step in workflow.values) {
        expect(step.stepConfig.maxRetries, equals(3), 
               reason: 'Step ${step.toolName} should have maxRetries=3');
      }
    });

    test('workflow steps build correct inputs from previous results', () {
      // Create mock previous results for testing input builders
      final mockSeedResult = TypedToolResult.fromWithType(
        ToolResult(
          toolName: 'generate_seed_colors',
          input: ToolInput.fromMap({}),
          output: SeedColorGenerationOutput(
            seedColors: ['#2563EB', '#7C3AED', '#059669'],
            designStyle: 'modern',
            mood: 'professional',
            confidence: 0.92,
            round: 1,
          ),
          issues: [],
        ),
        SeedColorGenerationOutput,
      );

      final mockSystemResult = TypedToolResult.fromWithType(
        ToolResult(
          toolName: 'generate_design_system_colors',
          input: ToolInput.fromMap({}),
          output: DesignSystemColorOutput(
            systemColors: {
              'primary': '#2563EB',
              'secondary': '#7C3AED',
              'surface': '#F8FAFC',
              'text': '#1E293B',
              'warning': '#F59E0B',
              'error': '#EF4444',
            },
            round: 1,
          ),
          issues: [],
        ),
        DesignSystemColorOutput,
      );

      final workflow = createProfessionalColorWorkflow();
      
      // Test design system input building
      final designSystemStep = workflow['generate_design_system_colors']!;
      final designSystemInput = designSystemStep.inputBuilder?.call([mockSeedResult]) ?? {};
      expect(designSystemInput['seed_colors'], isNotNull);
      expect(designSystemInput['seed_colors'], contains('#2563EB'));

      // Test full suite input building
      final fullSuiteStep = workflow['generate_full_color_suite']!;
      final fullSuiteInput = fullSuiteStep.inputBuilder?.call([mockSystemResult]) ?? {};
      expect(fullSuiteInput['system_colors'], isNotNull);
      expect(fullSuiteInput['system_colors']['primary'], equals('#2563EB'));
    });
  });
}