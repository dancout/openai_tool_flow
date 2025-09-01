import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';

/// Specialized test output type for palette extraction
class PaletteExtractionOutput extends ToolOutput {
  final List<String> colors;
  final double confidence;

  const PaletteExtractionOutput({
    required this.colors,
    required this.confidence,
  }) : super.subclass();

  factory PaletteExtractionOutput.fromMap(Map<String, dynamic> map) {
    return PaletteExtractionOutput(
      colors: List<String>.from(map['colors'] as List),
      confidence: (map['confidence'] as num).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {'colors': colors, 'confidence': confidence};
  }
}

/// Specialized test output type for theme generation
class ThemeGenerationOutput extends ToolOutput {
  final Map<String, String> theme;
  final String category;

  const ThemeGenerationOutput({required this.theme, required this.category})
    : super.subclass();

  factory ThemeGenerationOutput.fromMap(Map<String, dynamic> map) {
    return ThemeGenerationOutput(
      theme: Map<String, String>.from(map['theme'] as Map),
      category: map['category'] as String,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {'theme': theme, 'category': category};
  }
}

/// Type-safe audit function for PaletteExtractionOutput
class PaletteQualityAudit extends AuditFunction<PaletteExtractionOutput> {
  @override
  String get name => 'palette_quality_audit';

  @override
  List<Issue> run(ToolResult<ToolOutput> result) {
    final issues = <Issue>[];

    // Type-safe access to the output
    if (result.output is! PaletteExtractionOutput) {
      return [
        Issue(
          id: 'unexpected_output_type',
          severity: IssueSeverity.critical,
          description:
              'Expected PaletteExtractionOutput but got ${result.output.runtimeType}',
          context: {
            'expected_type': 'PaletteExtractionOutput',
            'actual_type': result.output.runtimeType.toString(),
          },
          suggestions: ['Check tool registration and output creation'],
          round: 0,
        ),
      ];
    }

    final paletteOutput = result.output as PaletteExtractionOutput;
    final colors = paletteOutput.colors;

    // Check color format
    for (int i = 0; i < colors.length; i++) {
      final color = colors[i];
      if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
        issues.add(
          Issue(
            id: 'invalid_color_$i',
            severity: IssueSeverity.high,
            description: 'Color $color is not in valid hex format',
            context: {'color_index': i, 'color': color},
            suggestions: ['Use valid hex format like #FF0000'],
            round: 0,
          ),
        );
      }
    }

    // Check confidence
    if (paletteOutput.confidence < 0.5) {
      issues.add(
        Issue(
          id: 'low_confidence',
          severity: IssueSeverity.medium,
          description: 'Low confidence score: ${paletteOutput.confidence}',
          context: {'confidence': paletteOutput.confidence},
          suggestions: ['Review input quality or extraction parameters'],
          round: 0,
        ),
      );
    }

    return issues;
  }
}

/// Type-safe audit function for ThemeGenerationOutput
class ThemeValidationAudit extends AuditFunction<ThemeGenerationOutput> {
  @override
  String get name => 'theme_validation_audit';

  @override
  List<Issue> run(ToolResult<ToolOutput> result) {
    final issues = <Issue>[];

    // Type-safe access to the output
    if (result.output is! ThemeGenerationOutput) {
      return [
        Issue(
          id: 'unexpected_output_type',
          severity: IssueSeverity.critical,
          description:
              'Expected ThemeGenerationOutput but got ${result.output.runtimeType}',
          context: {
            'expected_type': 'ThemeGenerationOutput',
            'actual_type': result.output.runtimeType.toString(),
          },
          suggestions: ['Check tool registration and output creation'],
          round: 0,
        ),
      ];
    }

    final themeOutput = result.output as ThemeGenerationOutput;
    final theme = themeOutput.theme;

    // Check required theme properties
    final requiredProperties = ['primary', 'secondary', 'background'];
    for (final property in requiredProperties) {
      if (!theme.containsKey(property)) {
        issues.add(
          Issue(
            id: 'missing_property_$property',
            severity: IssueSeverity.critical,
            description: 'Missing required theme property: $property',
            context: {
              'missing_property': property,
              'available_properties': theme.keys.toList(),
            },
            suggestions: ['Add $property property to theme'],
            round: 0,
          ),
        );
      }
    }

    return issues;
  }
}

/// Mock OpenAI service that returns typed outputs
class TypedMockOpenAiService implements OpenAiToolService {
  @override
  Future<Map<String, dynamic>> executeToolCall(
    ToolCallStep step,
    ToolInput input,
  ) async {
    switch (step.toolName) {
      case 'extract_palette':
        return {
          'colors': ['#FF0000', '#00FF00', '#0000FF'],
          'confidence': 0.8,
        };
      case 'generate_theme':
        return {
          'theme': {
            'primary': '#FF0000',
            'secondary': '#00FF00',
            'background': '#FFFFFF',
          },
          'category': 'vibrant',
        };
      case 'extract_palette_invalid':
        return {
          'colors': ['invalid', '#00FF00', '#0000FF'],
          'confidence': 0.3,
        };
      case 'generate_theme_invalid':
        return {
          'theme': {
            'primary': '#FF0000',
            // Missing 'secondary' and 'background'
          },
          'category': 'incomplete',
        };
      default:
        return {'result': 'default_output'};
    }
  }
}

void main() {
  group('Per-Step Generic Typing', () {
    late TypedMockOpenAiService mockService;

    setUpAll(() {
      // Register typed outputs for the test tools
      ToolOutputRegistry.register<PaletteExtractionOutput>(
        'extract_palette',
        (data) => PaletteExtractionOutput.fromMap(data),
      );
      ToolOutputRegistry.register<PaletteExtractionOutput>(
        'extract_palette_invalid',
        (data) => PaletteExtractionOutput.fromMap(data),
      );
      ToolOutputRegistry.register<ThemeGenerationOutput>(
        'generate_theme',
        (data) => ThemeGenerationOutput.fromMap(data),
      );
      ToolOutputRegistry.register<ThemeGenerationOutput>(
        'generate_theme_invalid',
        (data) => ThemeGenerationOutput.fromMap(data),
      );
    });

    setUp(() {
      mockService = TypedMockOpenAiService();
    });

    test('should support different output types in the same flow', () async {
      final flow = ToolFlow(
        config: OpenAIConfig(apiKey: 'test-key'),
        openAiService: mockService,
        steps: [
          ToolCallStep(
            toolName: 'extract_palette',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {'image': 'test.jpg'},
            stepConfig: StepConfig(
              outputSchema: OutputSchema(
                properties: [
                  PropertyEntry.array(
                    name: 'colors',
                    items: PropertyEntry.string(name: 'color'),
                  ),
                  PropertyEntry.number(
                    name: 'confidence',
                  ),
                ],
                required: ['colors', 'confidence'],
              ),
            ),
          ),
          ToolCallStep(
            toolName: 'generate_theme',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {
              'palette': previousResults.first.output.toMap(),
            },
            buildInputsFrom: [0],
            stepConfig: StepConfig(
              outputSchema: {
                'type': 'object',
                'properties': {
                  'theme': {'type': 'object'},
                  'category': {'type': 'string'},
                },
                'required': ['theme', 'category'],
              },
            ),
          ),
        ],
      );

      final result = await flow.run();

      expect(result.results.length, equals(2));

      // Check that each result has the correct type information
      final paletteResult = result.getTypedResultByToolName('extract_palette');
      final themeResult = result.getTypedResultByToolName('generate_theme');

      expect(paletteResult, isNotNull);
      expect(themeResult, isNotNull);
      expect(paletteResult!.outputType, equals(PaletteExtractionOutput));
      expect(themeResult!.outputType, equals(ThemeGenerationOutput));

      // Verify type-safe casting works
      final typedPaletteResult = paletteResult
          .asTyped<PaletteExtractionOutput>();
      final typedThemeResult = themeResult.asTyped<ThemeGenerationOutput>();

      expect(typedPaletteResult, isNotNull);
      expect(typedThemeResult, isNotNull);
      expect(typedPaletteResult!.output.colors, contains('#FF0000'));
      expect(typedThemeResult!.output.category, equals('vibrant'));
    });

    test('should execute type-safe audits correctly', () async {
      final flow = ToolFlow(
        config: OpenAIConfig(apiKey: 'test-key'),
        openAiService: mockService,
        steps: [
          ToolCallStep(
            toolName: 'extract_palette',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {'image': 'test.jpg'},
            stepConfig: StepConfig(
              audits: [PaletteQualityAudit()],
              outputSchema: {
                'type': 'object',
                'properties': {
                  'colors': {
                    'type': 'array',
                    'items': {'type': 'string'},
                  },
                  'confidence': {'type': 'number'},
                },
                'required': ['colors', 'confidence'],
              },
            ),
          ),
          ToolCallStep(
            toolName: 'generate_theme',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {
              'palette': previousResults.first.output.toMap(),
            },
            buildInputsFrom: [0],
            stepConfig: StepConfig(
              audits: [ThemeValidationAudit()],
              outputSchema: {
                'type': 'object',
                'properties': {
                  'theme': {'type': 'object'},
                  'category': {'type': 'string'},
                },
                'required': ['theme', 'category'],
              },
            ),
          ),
        ],
      );

      final result = await flow.run();

      expect(result.results.length, equals(2));

      // Both steps should pass their audits (valid data)
      expect(result.allIssues, isEmpty);
    });

    test(
      'should handle audit failures with type-safe error reporting',
      () async {
        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test-key'),
          openAiService: mockService,
          steps: [
            ToolCallStep(
              toolName: 'extract_palette_invalid',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'image': 'test.jpg'},
              stepConfig: StepConfig(
                audits: [PaletteQualityAudit()],
                outputSchema: {
                  'type': 'object',
                  'properties': {
                    'colors': {
                      'type': 'array',
                      'items': {'type': 'string'},
                    },
                    'confidence': {'type': 'number'},
                  },
                  'required': ['colors', 'confidence'],
                },
              ),
            ),
            ToolCallStep(
              toolName: 'generate_theme_invalid',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {
                'palette': previousResults.first.output.toMap(),
              },
              buildInputsFrom: [0],
              stepConfig: StepConfig(
                audits: [ThemeValidationAudit()],
                outputSchema: {
                  'type': 'object',
                  'properties': {
                    'theme': {'type': 'object'},
                    'category': {'type': 'string'},
                  },
                  'required': ['theme', 'category'],
                },
              ),
            ),
          ],
        );

        final result = await flow.run();

        expect(result.results.length, equals(2));
        expect(result.allIssues.length, greaterThan(0));

        // Check that audit issues were properly detected
        final paletteIssues = result.results[0].issues;
        final themeIssues = result.results[1].issues;

        // Palette should have issues (invalid color format and low confidence)
        expect(paletteIssues.length, greaterThan(0));
        expect(
          paletteIssues.any((issue) => issue.id.contains('invalid_color')),
          isTrue,
        );
        expect(
          paletteIssues.any((issue) => issue.id.contains('low_confidence')),
          isTrue,
        );

        // Theme should have issues (missing properties)
        expect(themeIssues.length, greaterThan(0));
        expect(
          themeIssues.any((issue) => issue.id.contains('missing_property')),
          isTrue,
        );
      },
    );

    test('should prevent type mismatches with safe casting', () async {
      final flow = ToolFlow(
        config: OpenAIConfig(apiKey: 'test-key'),
        openAiService: mockService,
        steps: [
          ToolCallStep(
            toolName: 'extract_palette',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {'image': 'test.jpg'},
            stepConfig: StepConfig(
              outputSchema: {
                'type': 'object',
                'properties': {
                  'colors': {
                    'type': 'array',
                    'items': {'type': 'string'},
                  },
                  'confidence': {'type': 'number'},
                },
                'required': ['colors', 'confidence'],
              },
            ),
          ),
        ],
      );

      final result = await flow.run();
      final paletteResult = result.getTypedResultByToolName('extract_palette')!;

      // Safe casting should work for correct type
      final correctCast = paletteResult.asTyped<PaletteExtractionOutput>();
      expect(correctCast, isNotNull);

      // Safe casting should return null for incorrect type
      final incorrectCast = paletteResult.asTyped<ThemeGenerationOutput>();
      expect(incorrectCast, isNull);

      // Type checking should work correctly
      expect(paletteResult.hasOutputType<PaletteExtractionOutput>(), isTrue);
      expect(paletteResult.hasOutputType<ThemeGenerationOutput>(), isFalse);
    });

    test(
      'should maintain backward compatibility with existing interfaces',
      () async {
        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test-key'),
          openAiService: mockService,
          steps: [
            ToolCallStep(
              toolName: 'extract_palette',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'image': 'test.jpg'},
              stepConfig: StepConfig(
                outputSchema: {
                  'type': 'object',
                  'properties': {
                    'colors': {
                      'type': 'array',
                      'items': {'type': 'string'},
                    },
                    'confidence': {'type': 'number'},
                  },
                  'required': ['colors', 'confidence'],
                },
              ),
            ),
          ],
        );

        final result = await flow.run();

        // Old interface should still work
        expect(result.results.length, equals(1));
        expect(result.resultsByToolName['extract_palette'], isNotNull);
        expect(result.getResultByToolName('extract_palette'), isNotNull);

        // Result should be accessible as ToolResult<ToolOutput>
        final oldStyleResult = result.getResultByToolName('extract_palette')!;
        expect(oldStyleResult.toolName, equals('extract_palette'));
        expect(
          oldStyleResult.output.toMap(),
          containsPair('colors', ['#FF0000', '#00FF00', '#0000FF']),
        );
      },
    );
  });
}
