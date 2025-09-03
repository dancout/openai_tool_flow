import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';

/// Test output class for demonstrating generic type safety
class TestGenericOutput extends ToolOutput {
  final String message;
  
  const TestGenericOutput({
    required this.message,
    required super.round,
  }) : super.subclass();
  
  factory TestGenericOutput.fromMap(Map<String, dynamic> map, int round) {
    return TestGenericOutput(
      message: map['message'] as String,
      round: round,
    );
  }
  
  @override
  Map<String, dynamic> toMap() {
    return {'message': message};
  }
}

/// Step definition for testing generic type propagation
class TestGenericStepDefinition extends StepDefinition<TestGenericOutput> {
  @override
  String get stepName => 'test_generic';
  
  @override
  OutputSchema get outputSchema => OutputSchema(
    properties: [
      PropertyEntry.string(name: 'message', description: 'Test message'),
    ],
    required: ['message'],
  );
  
  @override
  TestGenericOutput fromMap(Map<String, dynamic> data, int round) {
    return TestGenericOutput.fromMap(data, round);
  }
}

void main() {
  group('Generic ToolCallStep Type Safety', () {
    test('should preserve generic type information at compile time', () {
      // Create a generic step using StepDefinition
      final step = ToolCallStep.fromStepDefinition<TestGenericOutput>(
        TestGenericStepDefinition(),
        model: 'gpt-4',
        inputBuilder: (results) => {'test': 'data'},
      );
      
      // Verify the step is created correctly
      expect(step.toolName, equals('test_generic'));
      expect(step.model, equals('gpt-4'));
      
      // The step should now be ToolCallStep<TestGenericOutput>
      // This is verified by the fact that the compiler accepts this assignment
      ToolCallStep<TestGenericOutput> typedStep = step;
      expect(typedStep.toolName, equals('test_generic'));
    });
    
    test('should work with explicit generic type parameters', () {
      // Test creating a step with explicit generic type
      final step = ToolCallStep<TestGenericOutput>(
        toolName: 'test_explicit',
        model: 'gpt-4',
        inputBuilder: (results) => {'test': 'explicit'},
        stepConfig: StepConfig(),
        outputSchema: OutputSchema(
          properties: [
            PropertyEntry.string(name: 'message', description: 'Test message'),
          ],
          required: ['message'],
        ),
      );
      
      expect(step.toolName, equals('test_explicit'));
      expect(step.model, equals('gpt-4'));
    });
    
    test('should maintain type safety in copyWith', () {
      final originalStep = ToolCallStep.fromStepDefinition<TestGenericOutput>(
        TestGenericStepDefinition(),
        model: 'gpt-4',
        inputBuilder: (results) => {'test': 'original'},
      );
      
      // copyWith should preserve the generic type
      final copiedStep = originalStep.copyWith(model: 'gpt-3.5');
      
      expect(copiedStep.model, equals('gpt-3.5'));
      expect(copiedStep.toolName, equals('test_generic'));
      
      // This should compile without issues due to preserved generic type
      ToolCallStep<TestGenericOutput> typedCopy = copiedStep;
      expect(typedCopy.model, equals('gpt-3.5'));
    });
  });
}