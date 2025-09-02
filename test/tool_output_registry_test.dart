/// Tests for ToolOutputRegistry functionality
library;

import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';

class TestOutput extends ToolOutput {
  final String message;

  const TestOutput(this.message, {required super.round}) : super.subclass();

  factory TestOutput.fromMap(Map<String, dynamic> map, int round) {
    return TestOutput(map['message'] as String, round: round);
  }

  @override
  Map<String, dynamic> toMap() => {'_round': round, 'message': message};
}

void main() {
  group('ToolOutputRegistry', () {
    group('create', () {
      test('should throw when no creator is registered', () {
        expect(
          () => ToolOutputRegistry.create(
            toolName: 'unregistered_tool',
            data: {'test': 'data'},
            round: 0,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                'No typed output creator registered for tool: unregistered_tool',
              ),
            ),
          ),
        );
      });

      test('should return ToolOutput when creator is registered', () {
        ToolOutputRegistry.register(
          'test_tool_create',
          (data, round) => TestOutput.fromMap(data, round),
        );

        final result = ToolOutputRegistry.create(
          toolName: 'test_tool_create',
          data: {'message': 'hello'},
          round: 2,
        );

        expect(result, isA<TestOutput>());
        expect((result as TestOutput).message, equals('hello'));
        expect(result.round, equals(2));
      });
    });

    group('getOutputType', () {
      test('should throw when no output type is registered', () {
        expect(
          () => ToolOutputRegistry.getOutputType('unregistered_tool'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('No output type registered for tool: unregistered_tool'),
            ),
          ),
        );
      });

      test('should return Type when output type is registered', () {
        ToolOutputRegistry.register(
          'test_tool_type',
          (data, round) => TestOutput.fromMap(data, round),
        );

        final result = ToolOutputRegistry.getOutputType('test_tool_type');
        expect(result, equals(TestOutput));
      });
    });

    group('hasTypedOutput', () {
      test('should return false for unregistered tool', () {
        expect(
          ToolOutputRegistry.hasTypedOutput('unregistered_tool'),
          isFalse,
        );
      });

      test('should return true for registered tool', () {
        ToolOutputRegistry.register(
          'registered_tool',
          (data, round) => TestOutput.fromMap(data, round),
        );

        expect(
          ToolOutputRegistry.hasTypedOutput('registered_tool'),
          isTrue,
        );
      });
    });

    group('hasOutputType', () {
      test('should return true for matching output type', () {
        ToolOutputRegistry.register(
          'typed_tool',
          (data, round) => TestOutput.fromMap(data, round),
        );

        expect(
          ToolOutputRegistry.hasOutputType<TestOutput>('typed_tool'),
          isTrue,
        );
      });

      test('should return false for non-matching output type', () {
        ToolOutputRegistry.register(
          'typed_tool_2',
          (data, round) => TestOutput.fromMap(data, round),
        );

        expect(
          ToolOutputRegistry.hasOutputType<ToolOutput>('typed_tool_2'),
          isFalse,
        );
      });
    });

    group('registeredTools', () {
      test('should return list of registered tool names', () {
        final initialCount = ToolOutputRegistry.registeredTools.length;
        
        ToolOutputRegistry.register(
          'list_test_tool',
          (data, round) => TestOutput.fromMap(data, round),
        );

        expect(
          ToolOutputRegistry.registeredTools.length,
          equals(initialCount + 1),
        );
        expect(
          ToolOutputRegistry.registeredTools,
          contains('list_test_tool'),
        );
      });
    });

    group('registeredOutputTypes', () {
      test('should return map of registered output types', () {
        ToolOutputRegistry.register(
          'output_types_test',
          (data, round) => TestOutput.fromMap(data, round),
        );

        final outputTypes = ToolOutputRegistry.registeredOutputTypes;
        expect(outputTypes['output_types_test'], equals(TestOutput));
      });
    });
  });
}