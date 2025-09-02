/// Tests for StepDefinition functionality and automatic registration
library;

import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';

/// Test output class
class TestStepOutput extends ToolOutput {
  static const String stepName = 'test_step';
  
  final String message;

  const TestStepOutput(this.message, {required super.round}) : super.subclass();

  factory TestStepOutput.fromMap(Map<String, dynamic> map, int round) {
    return TestStepOutput(map['message'] as String, round: round);
  }

  @override
  Map<String, dynamic> toMap() => {'_round': round, 'message': message};

  static OutputSchema getOutputSchema() {
    return OutputSchema(
      properties: [
        PropertyEntry.string(
          name: 'message',
          description: 'A test message',
        ),
      ],
      required: ['message'],
    );
  }
}

/// Test step definition
class TestStepDefinition extends StepDefinition<TestStepOutput> {
  @override
  String get stepName => TestStepOutput.stepName;
  
  @override
  OutputSchema get outputSchema => TestStepOutput.getOutputSchema();
  
  @override
  TestStepOutput fromMap(Map<String, dynamic> data, int round) =>
      TestStepOutput.fromMap(data, round);
}

void main() {
  group('StepDefinition', () {
    late TestStepDefinition stepDef;

    setUp(() {
      stepDef = TestStepDefinition();
    });

    test('should provide step name from static constant', () {
      expect(stepDef.stepName, equals('test_step'));
      expect(stepDef.stepName, equals(TestStepOutput.stepName));
    });

    test('should provide output schema', () {
      final schema = stepDef.outputSchema;
      expect(schema.properties, hasLength(1));
      expect(schema.properties.first.name, equals('message'));
      expect(schema.required, contains('message'));
    });

    test('should create typed output from map data', () {
      final output = stepDef.fromMap({'message': 'test'}, 1);
      expect(output, isA<TestStepOutput>());
      expect(output.message, equals('test'));
      expect(output.round, equals(1));
    });

    test('should provide correct output type', () {
      expect(stepDef.outputType, equals(TestStepOutput));
    });
  });

  group('ToolOutputRegistry.registerStepDefinition', () {
    late TestStepDefinition stepDef;

    setUp(() {
      stepDef = TestStepDefinition();
    });

    test('should automatically register step definition', () {
      // Before registration, should not be registered
      expect(
        ToolOutputRegistry.hasTypedOutput(stepDef.stepName),
        isFalse,
      );

      // Register using step definition
      ToolOutputRegistry.registerStepDefinition(stepDef);

      // After registration, should be registered
      expect(
        ToolOutputRegistry.hasTypedOutput(stepDef.stepName),
        isTrue,
      );

      // Should be able to create output
      final output = ToolOutputRegistry.create(
        toolName: stepDef.stepName,
        data: {'message': 'test'},
        round: 0,
      );

      expect(output, isA<TestStepOutput>());
      expect((output as TestStepOutput).message, equals('test'));
    });

    test('should register correct output type', () {
      ToolOutputRegistry.registerStepDefinition(stepDef);

      expect(
        ToolOutputRegistry.getOutputType(stepDef.stepName),
        equals(TestStepOutput),
      );

      expect(
        ToolOutputRegistry.hasOutputType<TestStepOutput>(stepDef.stepName),
        isTrue,
      );
    });
  });

  group('ToolCallStep.fromStepDefinition', () {
    late TestStepDefinition stepDef;

    setUp(() {
      stepDef = TestStepDefinition();
    });

    test('should create ToolCallStep with correct configuration', () {
      final step = ToolCallStep.fromStepDefinition(
        stepDef,
        model: 'gpt-4',
        inputBuilder: (results) => {'input': 'test'},
      );

      expect(step.toolName, equals(stepDef.stepName));
      expect(step.model, equals('gpt-4'));
      expect(step.stepConfig.outputSchema, equals(stepDef.outputSchema));
    });

    test('should automatically register step definition during creation', () {
      // Ensure not registered initially
      expect(
        ToolOutputRegistry.hasTypedOutput(stepDef.stepName),
        isFalse,
      );

      // Create step using step definition
      ToolCallStep.fromStepDefinition(
        stepDef,
        model: 'gpt-4',
        inputBuilder: (results) => {'input': 'test'},
      );

      // Should now be registered
      expect(
        ToolOutputRegistry.hasTypedOutput(stepDef.stepName),
        isTrue,
      );
    });

    test('should pass through StepConfig parameters correctly', () {
      final step = ToolCallStep.fromStepDefinition(
        stepDef,
        model: 'gpt-4',
        inputBuilder: (results) => {'input': 'test'},
        stepMaxRetries: 5,
        stopOnFailure: false,
        includeOutputsFrom: ['previous_step'],
      );

      expect(step.stepConfig.getEffectiveMaxRetries(3), equals(5));
      expect(step.stepConfig.stopOnFailure, isFalse);
      expect(step.stepConfig.includeOutputsFrom, contains('previous_step'));
    });
  });

  group('Error detection', () {
    test('should catch missing registration at runtime', () {
      // Attempt to create output for unregistered tool
      expect(
        () => ToolOutputRegistry.create(
          toolName: 'missing_step',
          data: {'test': 'data'},
          round: 0,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No typed output creator registered for tool: missing_step'),
          ),
        ),
      );
    });

    test('should catch missing output type at runtime', () {
      // Attempt to get output type for unregistered tool
      expect(
        () => ToolOutputRegistry.getOutputType('missing_step'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No output type registered for tool: missing_step'),
          ),
        ),
      );
    });

    test('should detect incorrect step name usage', () {
      final stepDef = TestStepDefinition();
      ToolOutputRegistry.registerStepDefinition(stepDef);

      // This should work
      expect(
        ToolOutputRegistry.hasTypedOutput(stepDef.stepName),
        isTrue,
      );

      // This should fail (typo in step name)
      expect(
        ToolOutputRegistry.hasTypedOutput('test_stepp'), // typo
        isFalse,
      );
    });
  });
}