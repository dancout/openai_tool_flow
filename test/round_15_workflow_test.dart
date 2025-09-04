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



    test('new output classes can be instantiated correctly', () {
      // Test SeedColorGenerationOutput
      final seedOutput = SeedColorGenerationOutput(
        seedColors: ['#2563EB', '#7C3AED', '#059669'],
        designStyle: 'modern',
        mood: 'professional',
        confidence: 0.92,
        round: 1,
      );
      expect(seedOutput.seedColors.length, equals(3));
      expect(SeedColorGenerationOutput.stepName, equals('generate_seed_colors'));

      // Test DesignSystemColorOutput
      final systemOutput = DesignSystemColorOutput(
        systemColors: {
          'primary': '#2563EB',
          'secondary': '#7C3AED',
          'surface': '#F8FAFC',
          'text': '#1E293B',
          'warning': '#F59E0B',
          'error': '#EF4444',
        },
        round: 1,
      );
      expect(systemOutput.systemColors.length, equals(6));
      expect(DesignSystemColorOutput.stepName, equals('generate_design_system_colors'));

      // Test FullColorSuiteOutput
      final suiteOutput = FullColorSuiteOutput(
        colorSuite: {
          'primaryText': '#1E293B',
          'primaryBackground': '#FFFFFF',
          'primaryButton': '#2563EB',
        },
        round: 1,
      );
      expect(suiteOutput.colorSuite.length, equals(3));
      expect(FullColorSuiteOutput.stepName, equals('generate_full_color_suite'));
    });

    test('input validation works for new input classes', () {
      // Test SeedColorGenerationInput validation
      final seedInput = SeedColorGenerationInput(
        designStyle: '',
        mood: 'professional',
        colorCount: 0,
      );
      final seedValidationIssues = seedInput.validate();
      expect(seedValidationIssues.length, greaterThan(0));
      expect(seedValidationIssues.any((issue) => issue.contains('design_style')), isTrue);
      expect(seedValidationIssues.any((issue) => issue.contains('color_count')), isTrue);

      // Test DesignSystemColorInput validation
      final systemInput = DesignSystemColorInput(
        seedColors: ['invalid_color'],
        systemColorCount: 0,
      );
      final systemValidationIssues = systemInput.validate();
      expect(systemValidationIssues.length, greaterThan(0));
      expect(systemValidationIssues.any((issue) => issue.contains('Invalid seed color')), isTrue);
      expect(systemValidationIssues.any((issue) => issue.contains('system_color_count')), isTrue);

      // Test FullColorSuiteInput validation
      final suiteInput = FullColorSuiteInput(
        systemColors: {'primary': 'invalid_color'},
        suiteColorCount: 0,
      );
      final suiteValidationIssues = suiteInput.validate();
      expect(suiteValidationIssues.length, greaterThan(0));
      expect(suiteValidationIssues.any((issue) => issue.contains('Invalid system color')), isTrue);
      expect(suiteValidationIssues.any((issue) => issue.contains('suite_color_count')), isTrue);
    });

    test('step definitions return correct schemas', () {
      final seedStepDef = SeedColorGenerationStepDefinition();
      final systemStepDef = DesignSystemColorStepDefinition();
      final suiteStepDef = FullColorSuiteStepDefinition();

      expect(seedStepDef.stepName, equals('generate_seed_colors'));
      expect(systemStepDef.stepName, equals('generate_design_system_colors'));
      expect(suiteStepDef.stepName, equals('generate_full_color_suite'));

      // Check that schemas have required properties
      final seedSchema = seedStepDef.outputSchema;
      expect(seedSchema.required, contains('seed_colors'));
      expect(seedSchema.required, contains('confidence'));

      final systemSchema = systemStepDef.outputSchema;
      expect(systemSchema.required, contains('system_colors'));

      final suiteSchema = suiteStepDef.outputSchema;
      expect(suiteSchema.required, contains('color_suite'));
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
      final designSystemInput = designSystemStep.inputBuilder([mockSeedResult]);
      expect(designSystemInput['seed_colors'], isNotNull);
      expect(designSystemInput['seed_colors'], contains('#2563EB'));

      // Test full suite input building
      final fullSuiteStep = workflow['generate_full_color_suite']!;
      final fullSuiteInput = fullSuiteStep.inputBuilder([mockSystemResult]);
      expect(fullSuiteInput['system_colors'], isNotNull);
      expect(fullSuiteInput['system_colors']['primary'], equals('#2563EB'));
    });
  });
}