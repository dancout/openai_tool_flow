/// Tests for ToolOutput class functionality
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
  group('ToolOutput', () {
    group('round parameter', () {
      test('should require round parameter in constructor', () {
        const output = TestOutput('test message', round: 5);
        expect(output.round, equals(5));
        expect(output.message, equals('test message'));
      });

      test('should include round in toMap output', () {
        const output = TestOutput('test message', round: 3);
        final map = output.toMap();

        expect(map['_round'], equals(3));
        expect(map['message'], equals('test message'));
      });

      test('should handle round in fromMap factory', () {
        final output = TestOutput.fromMap({'message': 'from map'}, 7);

        expect(output.round, equals(7));
        expect(output.message, equals('from map'));
      });
    });

    group('direct usage', () {
      test('should support direct ToolOutput usage with data', () {
        final output = ToolOutput({'key': 'value'}, round: 1);
        
        expect(output.round, equals(1));
        
        final map = output.toMap();
        expect(map['_round'], equals(1));
        expect(map['key'], equals('value'));
      });

      test('should support fromMap factory for direct usage', () {
        final output = ToolOutput.fromMap({'data': 'test'}, round: 2);
        
        expect(output.round, equals(2));
        
        final map = output.toMap();
        expect(map['_round'], equals(2));
        expect(map['data'], equals('test'));
      });
    });

    group('subclass usage', () {
      test('should throw if subclass does not override toMap', () {
        final output = BadSubclassOutput(round: 1);
        
        expect(
          () => output.toMap(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('should work correctly when subclass overrides toMap', () {
        const output = TestOutput('test', round: 4);
        
        final map = output.toMap();
        expect(map['_round'], equals(4));
        expect(map['message'], equals('test'));
      });
    });

    group('equality', () {
      test('should be equal when round and data match', () {
        const output1 = TestOutput('same', round: 1);
        const output2 = TestOutput('same', round: 1);
        
        expect(output1, equals(output2));
        expect(output1.hashCode, equals(output2.hashCode));
      });

      test('should not be equal when round differs', () {
        const output1 = TestOutput('same', round: 1);
        const output2 = TestOutput('same', round: 2);
        
        expect(output1, isNot(equals(output2)));
      });

      test('should not be equal when data differs', () {
        const output1 = TestOutput('different1', round: 1);
        const output2 = TestOutput('different2', round: 1);
        
        expect(output1, isNot(equals(output2)));
      });
    });
  });
}

/// Test class that doesn't override toMap (should throw)
class BadSubclassOutput extends ToolOutput {
  const BadSubclassOutput({required super.round}) : super.subclass();
}