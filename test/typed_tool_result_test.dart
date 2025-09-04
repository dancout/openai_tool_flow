import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';

/// Specialized test output type for seed color generation testing
class SeedColorGenerationTestOutput extends ToolOutput {
  final List<String> colors;
  final double confidence;

  const SeedColorGenerationTestOutput({
    required this.colors,
    required this.confidence,
    required super.round,
  }) : super.subclass();

  factory SeedColorGenerationTestOutput.fromMap(Map<String, dynamic> map, int round) {
    return SeedColorGenerationTestOutput(
      colors: List<String>.from(map['colors'] as List),
      confidence: (map['confidence'] as num).toDouble(),
      round: round,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {'colors': colors, 'confidence': confidence};
  }
}

/// Specialized test output type for color suite generation testing
class ColorSuiteGenerationTestOutput extends ToolOutput {
  final Map<String, String> colorSuite;
  final String category;

  const ColorSuiteGenerationTestOutput({
    required this.colorSuite,
    required this.category,
    required super.round,
  }) : super.subclass();

  factory ColorSuiteGenerationTestOutput.fromMap(Map<String, dynamic> map, int round) {
    return ColorSuiteGenerationTestOutput(
      colorSuite: Map<String, String>.from(map['color_suite'] as Map),
      category: map['category'] as String,
      round: round,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {'color_suite': colorSuite, 'category': category};
  }
}

/// Type-safe audit function for SeedColorGenerationTestOutput
class SeedColorQualityAudit extends AuditFunction<SeedColorGenerationTestOutput> {
  @override
  String get name => 'seed_color_quality_audit';

  @override
  List<Issue> run(ToolResult<ToolOutput> result) {
    final issues = <Issue>[];

    // Type-safe access to the output
    if (result.output is! SeedColorGenerationTestOutput) {
      return [
        Issue(
          id: 'unexpected_output_type',
          severity: IssueSeverity.critical,
          description:
              'Expected SeedColorGenerationTestOutput but got ${result.output.runtimeType}',
          context: {
            'expected_type': 'SeedColorGenerationTestOutput',
            'actual_type': result.output.runtimeType.toString(),
          },
          suggestions: ['Check tool registration and output creation'],
          round: 0,
        ),
      ];
    }

    final seedOutput = result.output as SeedColorGenerationTestOutput;
    final colors = seedOutput.colors;

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

/// Type-safe audit function for ColorSuiteGenerationTestOutput
class ColorSuiteValidationAudit extends AuditFunction<ColorSuiteGenerationTestOutput> {
  @override
  String get name => 'color_suite_validation_audit';

  @override
  List<Issue> run(ToolResult<ToolOutput> result) {
    final issues = <Issue>[];

    // Type-safe access to the output
    if (result.output is! ColorSuiteGenerationTestOutput) {
      return [
        Issue(
          id: 'unexpected_output_type',
          severity: IssueSeverity.critical,
          description:
              'Expected ColorSuiteGenerationTestOutput but got ${result.output.runtimeType}',
          context: {
            'expected_type': 'ColorSuiteGenerationTestOutput',
            'actual_type': result.output.runtimeType.toString(),
          },
          suggestions: ['Check tool registration and output creation'],
          round: 0,
        ),
      ];
    }

    final suiteOutput = result.output as ColorSuiteGenerationTestOutput;
    final colorSuite = suiteOutput.colorSuite;

    // Check required color suite properties
    final requiredProperties = ['primary', 'secondary', 'background'];
    for (final property in requiredProperties) {
      if (!colorSuite.containsKey(property)) {
        issues.add(
          Issue(
            id: 'missing_property_$property',
            severity: IssueSeverity.critical,
            description: 'Missing required color suite property: $property',
            context: {
              'missing_property': property,
              'available_properties': colorSuite.keys.toList(),
            },
            suggestions: ['Add $property property to color suite'],
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
    ToolInput input, {
    List<ToolResult> includedResults = const [],
  }) async {
    switch (step.toolName) {
      case 'generate_seed_colors':
        return {
          'colors': ['#FF0000', '#00FF00', '#0000FF'],
          'confidence': 0.8,
        };
      case 'generate_color_suite':
        return {
          'color_suite': {
            'primary': '#FF0000',
            'secondary': '#00FF00',
            'background': '#FFFFFF',
          },
          'category': 'vibrant',
        };
      case 'generate_seed_colors_invalid':
        return {
          'colors': ['invalid', '#00FF00', '#0000FF'],
          'confidence': 0.3,
        };
      case 'generate_color_suite_invalid':
        return {
          'color_suite': {
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
      ToolOutputRegistry.register<SeedColorGenerationTestOutput>(
        'generate_seed_colors',
        (data, round) => SeedColorGenerationTestOutput.fromMap(data, round),
      );
      ToolOutputRegistry.register<SeedColorGenerationTestOutput>(
        'generate_seed_colors_invalid',
        (data, round) => SeedColorGenerationTestOutput.fromMap(data, round),
      );
      ToolOutputRegistry.register<ColorSuiteGenerationTestOutput>(
        'generate_color_suite',
        (data, round) => ColorSuiteGenerationTestOutput.fromMap(data, round),
      );
      ToolOutputRegistry.register<ColorSuiteGenerationTestOutput>(
        'generate_color_suite_invalid',
        (data, round) => ColorSuiteGenerationTestOutput.fromMap(data, round),
      );
    });

    setUp(() {
      mockService = TypedMockOpenAiService();
    });

    test('should support different output types in the same flow', () async {
      final flow = ToolFlow(
        config: OpenAIConfig(apiKey: 'test-key', baseUrl: 'http://localhost'),
        openAiService: mockService,
        steps: [
          ToolCallStep(
            toolName: 'generate_seed_colors',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {'style': 'modern'},
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.array(name: 'colors', items: PropertyType.string),
                PropertyEntry.number(name: 'confidence'),
              ],
              required: ['colors', 'confidence'],
            ),
            stepConfig: StepConfig(),
          ),
          ToolCallStep(
            toolName: 'generate_color_suite',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {
              'palette': previousResults.first.output.toMap(),
            },
            buildInputsFrom: [0],
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.object(name: 'theme'),
                PropertyEntry.string(name: 'category'),
              ],
              required: ['theme', 'category'],
            ),
            stepConfig: StepConfig(),
          ),
        ],
      );

      final result = await flow.run();

      expect(result.results.length, equals(2));

      // Check that each result has the correct type information
      final seedResult = result.getTypedResultByToolName('generate_seed_colors');
      final suiteResult = result.getTypedResultByToolName('generate_color_suite');

      expect(seedResult, isNotNull);
      expect(suiteResult, isNotNull);
      expect(seedResult!.outputType, equals(SeedColorGenerationTestOutput));
      expect(suiteResult!.outputType, equals(ColorSuiteGenerationTestOutput));

      // Verify type-safe casting works
      final typedSeedResult = seedResult
          .asTyped<SeedColorGenerationTestOutput>();
      final typedSuiteResult = suiteResult.asTyped<ColorSuiteGenerationTestOutput>();

      expect(typedSeedResult, isNotNull);
      expect(typedSuiteResult, isNotNull);
      expect(typedSeedResult.output.colors, contains('#FF0000'));
      expect(typedThemeResult.output.category, equals('vibrant'));
    });

    test('should execute type-safe audits correctly', () async {
      final flow = ToolFlow(
        config: OpenAIConfig(apiKey: 'test-key', baseUrl: 'http://localhost'),
        openAiService: mockService,
        steps: [
          ToolCallStep(
            toolName: 'extract_palette',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {'image': 'test.jpg'},
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.array(name: 'colors', items: PropertyType.string),
                PropertyEntry.number(name: 'confidence'),
              ],
              required: ['colors', 'confidence'],
            ),
            stepConfig: StepConfig(audits: [PaletteQualityAudit()]),
          ),
          ToolCallStep(
            toolName: 'generate_theme',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {
              'palette': previousResults.first.output.toMap(),
            },
            buildInputsFrom: [0],
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.object(name: 'theme'),
                PropertyEntry.string(name: 'category'),
              ],
              required: ['theme', 'category'],
            ),
            stepConfig: StepConfig(audits: [ThemeValidationAudit()]),
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
          config: OpenAIConfig(apiKey: 'test-key', baseUrl: 'http://localhost'),
          openAiService: mockService,
          steps: [
            ToolCallStep(
              toolName: 'extract_palette_invalid',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'image': 'test.jpg'},
              outputSchema: OutputSchema(
                properties: [
                  PropertyEntry.array(
                    name: 'colors',
                    items: PropertyType.string,
                  ),
                  PropertyEntry.number(name: 'confidence'),
                ],
                required: ['colors', 'confidence'],
              ),
              stepConfig: StepConfig(audits: [PaletteQualityAudit()]),
            ),
            ToolCallStep(
              toolName: 'generate_theme_invalid',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {
                'palette': previousResults.first.output.toMap(),
              },
              buildInputsFrom: [0],
              outputSchema: OutputSchema(
                properties: [
                  PropertyEntry.object(name: 'theme'),
                  PropertyEntry.string(name: 'category'),
                ],
                required: ['theme', 'category'],
              ),
              stepConfig: StepConfig(audits: [ThemeValidationAudit()]),
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

    test(
      'should prevent type mismatches with safe casting and throw on incorrect cast',
      () async {
        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test-key', baseUrl: 'http://localhost'),
          openAiService: mockService,
          steps: [
            ToolCallStep(
              toolName: 'extract_palette',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'image': 'test.jpg'},
              outputSchema: OutputSchema(
                properties: [
                  PropertyEntry.array(
                    name: 'colors',
                    items: PropertyType.string,
                  ),
                  PropertyEntry.number(name: 'confidence'),
                ],
                required: ['colors', 'confidence'],
              ),
              stepConfig: StepConfig(),
            ),
          ],
        );

        final result = await flow.run();
        final paletteResult = result.getTypedResultByToolName(
          'extract_palette',
        )!;

        // Safe casting should work for correct type
        final correctCast = paletteResult.asTyped<PaletteExtractionOutput>();
        expect(correctCast, isNotNull);

        // Type checking should work correctly
        expect(paletteResult.hasOutputType<PaletteExtractionOutput>(), isTrue);
        expect(paletteResult.hasOutputType<ThemeGenerationOutput>(), isFalse);

        // Should throw when forcibly casting to incorrect type
        expect(
          () => paletteResult.asTyped<ThemeGenerationOutput>(),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'should maintain backward compatibility with existing interfaces',
      () async {
        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test-key', baseUrl: 'http://localhost'),
          openAiService: mockService,
          steps: [
            ToolCallStep(
              toolName: 'extract_palette',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'image': 'test.jpg'},
              outputSchema: OutputSchema(
                properties: [
                  PropertyEntry.array(
                    name: 'colors',
                    items: PropertyType.string,
                  ),
                  PropertyEntry.number(name: 'confidence'),
                ],
                required: ['colors', 'confidence'],
              ),
              stepConfig: StepConfig(),
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
