import 'package:test/test.dart';

import '../example/typed_interfaces.dart';

void main() {
  group('Professional Color Workflow Typed Interfaces', () {
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
      expect(
        SeedColorGenerationOutput.stepName,
        equals('generate_seed_colors'),
      );

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
      expect(
        DesignSystemColorOutput.stepName,
        equals('generate_design_system_colors'),
      );

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
      expect(
        FullColorSuiteOutput.stepName,
        equals('generate_full_color_suite'),
      );
    });

    test('input validation works for new input classes', () {
      // Test SeedColorGenerationInput validation
      final seedInput = SeedColorGenerationInput(
        designStyle: '',
        mood: 'professional',
        colorCount: 0,
        userPreferences: {},
      );
      final seedValidationIssues = seedInput.validate();
      expect(seedValidationIssues.length, greaterThan(0));
      expect(
        seedValidationIssues.any((issue) => issue.contains('design_style')),
        isTrue,
      );
      expect(
        seedValidationIssues.any((issue) => issue.contains('color_count')),
        isTrue,
      );

      // Test DesignSystemColorInput validation
      final systemInput = DesignSystemColorInput(
        seedColors: ['invalid_color'],
        targetAccessibility: 'AA',
      );
      final systemValidationIssues = systemInput.validate();
      expect(systemValidationIssues.length, greaterThan(0));
      expect(
        systemValidationIssues.any(
          (issue) => issue.contains('Invalid seed color'),
        ),
        isTrue,
      );

      // Test FullColorSuiteInput validation
      final suiteInput = FullColorSuiteInput(
        systemColors: {'primary': 'invalid_color'},
        brandPersonality: 'professional',
      );
      final suiteValidationIssues = suiteInput.validate();
      expect(suiteValidationIssues.length, greaterThan(0));
      expect(
        suiteValidationIssues.any(
          (issue) => issue.contains('Invalid system color'),
        ),
        isTrue,
      );
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

    test('fromMap functions throw exceptions for missing required fields', () {
      // Test SeedColorGenerationInput throws for missing fields
      expect(
        () => SeedColorGenerationInput.fromMap({}),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => SeedColorGenerationInput.fromMap({'design_style': 'modern'}),
        throwsA(isA<ArgumentError>()),
      );

      // Test DesignSystemColorInput throws for missing fields
      expect(
        () => DesignSystemColorInput.fromMap({}),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => DesignSystemColorInput.fromMap({
          'seed_colors': ['#FF0000'],
        }),
        throwsA(isA<ArgumentError>()),
      );

      // Test FullColorSuiteInput throws for missing fields
      expect(
        () => FullColorSuiteInput.fromMap({}),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => FullColorSuiteInput.fromMap({
          'system_colors': {'primary': '#FF0000'},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('output schemas include system message templates', () {
      final seedSchema = SeedColorGenerationOutput.getOutputSchema();
      expect(seedSchema.systemMessageTemplate, isNotNull);
      expect(seedSchema.systemMessageTemplate!, contains('color theorist'));

      final systemSchema = DesignSystemColorOutput.getOutputSchema();
      expect(systemSchema.systemMessageTemplate, isNotNull);
      expect(systemSchema.systemMessageTemplate!, contains('UX designer'));

      final suiteSchema = FullColorSuiteOutput.getOutputSchema();
      expect(suiteSchema.systemMessageTemplate, isNotNull);
      expect(
        suiteSchema.systemMessageTemplate!,
        contains('design systems architect'),
      );
    });
  });
}
