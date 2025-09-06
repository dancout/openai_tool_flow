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

  factory SeedColorGenerationTestOutput.fromMap(
    Map<String, dynamic> map,
    int round,
  ) {
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

  factory ColorSuiteGenerationTestOutput.fromMap(
    Map<String, dynamic> map,
    int round,
  ) {
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
class SeedColorQualityAudit
    extends AuditFunction<SeedColorGenerationTestOutput> {
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

    return issues;
  }
}

/// Type-safe audit function for ColorSuiteGenerationTestOutput
class ColorSuiteValidationAudit
    extends AuditFunction<ColorSuiteGenerationTestOutput> {
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
  Future<ToolCallResponse> executeToolCall(
    ToolCallStep step,
    ToolInput input, {
    List<ToolResult> includedResults = const [],
  }) async {
    Map<String, dynamic> output;
    switch (step.toolName) {
      case 'generate_seed_colors':
        output = {
          'colors': ['#FF0000', '#00FF00', '#0000FF'],
          'confidence': 0.8,
        };
        break;
      case 'generate_color_suite':
        output = {
          'color_suite': {
            'primary': '#FF0000',
            'secondary': '#00FF00',
            'background': '#FFFFFF',
          },
          'category': 'vibrant',
        };
        break;
      case 'generate_seed_colors_invalid':
        output = {
          'colors': ['invalid', '#00FF00', '#0000FF'],
          'confidence': 0.3,
        };
        break;
      case 'generate_color_suite_invalid':
        output = {
          'color_suite': {
            'primary': '#FF0000',
            // Missing 'secondary' and 'background'
          },
          'category': 'incomplete',
        };
        break;
      default:
        output = {'result': 'default_output'};
    }

    return ToolCallResponse(
      output: output,
      usage: {
        'prompt_tokens': 100,
        'completion_tokens': 50,
        'total_tokens': 150,
        'prompt_tokens_details': {'cached_tokens': 0, 'audio_tokens': 0},
        'completion_tokens_details': {
          'reasoning_tokens': 0,
          'audio_tokens': 0,
          'accepted_prediction_tokens': 0,
          'rejected_prediction_tokens': 0,
        },
      },
    );
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
            ),
            stepConfig: StepConfig(),
          ),
          ToolCallStep(
            toolName: 'generate_color_suite',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {
              'palette': previousResults.first.output.toMap(),
            },
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.object(
                  name: 'theme',
                  properties: [
                    PropertyEntry.string(name: 'primary'),
                    PropertyEntry.string(name: 'secondary'),
                    PropertyEntry.string(name: 'background'),
                  ],
                ),
                PropertyEntry.string(name: 'category'),
              ],
            ),
            stepConfig: StepConfig(),
          ),
        ],
      );

      final result = await flow.run(input: {'test': 'data'});

      expect(result.results.length, equals(3)); // initial input + 2 tool steps

      // Check that each result has the correct type information
      final seedResult = result.results.firstWhere(
        (r) => r.toolName == 'generate_seed_colors',
      );
      final suiteResult = result.results.firstWhere(
        (r) => r.toolName == 'generate_color_suite',
      );

      expect(seedResult, isNotNull);
      expect(suiteResult, isNotNull);
      expect(seedResult.outputType, equals(SeedColorGenerationTestOutput));
      expect(suiteResult.outputType, equals(ColorSuiteGenerationTestOutput));

      // Verify type-safe casting works
      final typedSeedResult = seedResult
          .asTyped<SeedColorGenerationTestOutput>();
      final typedSuiteResult = suiteResult
          .asTyped<ColorSuiteGenerationTestOutput>();

      expect(typedSeedResult, isNotNull);
      expect(typedSuiteResult, isNotNull);
      expect(typedSeedResult.output.colors, contains('#FF0000'));
    });

    test('should execute type-safe audits correctly', () async {
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
            ),
            stepConfig: StepConfig(audits: [SeedColorQualityAudit()]),
          ),
          ToolCallStep(
            toolName: 'generate_color_suite',
            model: 'gpt-4',
            inputBuilder: (previousResults) => {
              'palette': previousResults.first.output.toMap(),
            },
            outputSchema: OutputSchema(
              properties: [
                PropertyEntry.object(
                  name: 'theme',
                  properties: [
                    PropertyEntry.string(name: 'primary'),
                    PropertyEntry.string(name: 'secondary'),
                    PropertyEntry.string(name: 'background'),
                  ],
                ),
                PropertyEntry.string(name: 'category'),
              ],
            ),
            stepConfig: StepConfig(audits: [ColorSuiteValidationAudit()]),
          ),
        ],
      );

      final result = await flow.run(input: {'test': 'data'});

      expect(result.results.length, equals(3)); // initial input + 2 tool steps

      // Check that audits ran and produced no issues for valid outputs
      final seedIssues = result.results[1].issues; // First tool step (index 1)
      final suiteIssues =
          result.results[2].issues; // Second tool step (index 2)

      expect(seedIssues, isEmpty);
      expect(suiteIssues, isEmpty);

      // Check that audit functions were type-safe
      final seedResult = result.results.firstWhere(
        (r) => r.toolName == 'generate_seed_colors',
      );
      final suiteResult = result.results.firstWhere(
        (r) => r.toolName == 'generate_color_suite',
      );

      expect(seedResult, isNotNull);
      expect(suiteResult, isNotNull);

      // Type-safe audit: should not throw and should return empty issues
      final audit1 = SeedColorQualityAudit();
      final audit2 = ColorSuiteValidationAudit();

      final audit1Issues = audit1.run(
        seedResult.asTyped<SeedColorGenerationTestOutput>(),
      );
      final audit2Issues = audit2.run(
        suiteResult.asTyped<ColorSuiteGenerationTestOutput>(),
      );

      expect(audit1Issues, isEmpty);
      expect(audit2Issues, isEmpty);
    });

    test(
      'should handle audit failures with type-safe error reporting',
      () async {
        final flow = ToolFlow(
          config: OpenAIConfig(apiKey: 'test-key', baseUrl: 'http://localhost'),
          openAiService: mockService,
          steps: [
            ToolCallStep(
              toolName: 'generate_seed_colors_invalid',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'style': 'modern'},
              outputSchema: OutputSchema(
                properties: [
                  PropertyEntry.array(
                    name: 'colors',
                    items: PropertyType.string,
                  ),
                  PropertyEntry.number(name: 'confidence'),
                ],
              ),
              stepConfig: StepConfig(audits: [SeedColorQualityAudit()]),
            ),
            ToolCallStep(
              toolName: 'generate_color_suite_invalid',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {
                'palette': previousResults.first.output.toMap(),
              },
              outputSchema: OutputSchema(
                properties: [
                  PropertyEntry.object(
                    name: 'theme',
                    properties: [
                      PropertyEntry.string(name: 'primary'),
                      PropertyEntry.string(name: 'secondary'),
                      PropertyEntry.string(name: 'background'),
                    ],
                  ),
                  PropertyEntry.string(name: 'category'),
                ],
              ),
              stepConfig: StepConfig(audits: [ColorSuiteValidationAudit()]),
            ),
          ],
        );

        final result = await flow.run(input: {'test': 'data'});

        expect(
          result.results.length,
          equals(3),
        ); // initial input + 2 tool steps

        // Check that audits ran and produced issues for invalid outputs
        final seedIssues = result.results[1].issues; // First tool step
        final suiteIssues = result.results[2].issues; // Second tool step

        expect(seedIssues, isNotEmpty);
        expect(
          seedIssues.any((issue) => issue.id.startsWith('invalid_color_')),
          isTrue,
        );

        expect(suiteIssues, isNotEmpty);
        expect(
          suiteIssues.any((issue) => issue.id.startsWith('missing_property_')),
          isTrue,
        );

        // Type-safe audit: should report issues for invalid outputs
        final seedResult = result.results.firstWhere(
          (r) => r.toolName == 'generate_seed_colors_invalid',
        );
        final suiteResult = result.results.firstWhere(
          (r) => r.toolName == 'generate_color_suite_invalid',
        );

        expect(seedResult, isNotNull);
        expect(suiteResult, isNotNull);

        final audit1 = SeedColorQualityAudit();
        final audit2 = ColorSuiteValidationAudit();

        final audit1Issues = audit1.run(
          seedResult.asTyped<SeedColorGenerationTestOutput>(),
        );
        final audit2Issues = audit2.run(
          suiteResult.asTyped<ColorSuiteGenerationTestOutput>(),
        );

        expect(audit1Issues, isNotEmpty);
        expect(
          audit1Issues.any((issue) => issue.id.startsWith('invalid_color_')),
          isTrue,
        );

        expect(audit2Issues, isNotEmpty);
        expect(
          audit2Issues.any((issue) => issue.id.startsWith('missing_property_')),
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
              toolName: 'generate_seed_colors',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {'style': 'modern'},
              outputSchema: OutputSchema(
                properties: [
                  PropertyEntry.array(
                    name: 'colors',
                    items: PropertyType.string,
                  ),
                  PropertyEntry.number(name: 'confidence'),
                ],
              ),
              stepConfig: StepConfig(),
            ),
            ToolCallStep(
              toolName: 'generate_color_suite',
              model: 'gpt-4',
              inputBuilder: (previousResults) => {
                'palette': previousResults.first.output.toMap(),
              },
              outputSchema: OutputSchema(
                properties: [
                  PropertyEntry.object(
                    name: 'theme',
                    properties: [
                      PropertyEntry.string(name: 'primary'),
                      PropertyEntry.string(name: 'secondary'),
                      PropertyEntry.string(name: 'background'),
                    ],
                  ),
                  PropertyEntry.string(name: 'category'),
                ],
              ),
              stepConfig: StepConfig(),
            ),
          ],
        );

        final result = await flow.run(input: {'test': 'data'});

        final seedResult = result.results.firstWhere(
          (r) => r.toolName == 'generate_seed_colors',
        );
        final suiteResult = result.results.firstWhere(
          (r) => r.toolName == 'generate_color_suite',
        );

        expect(seedResult, isNotNull);
        expect(suiteResult, isNotNull);

        // Safe cast: correct type
        final typedSeed = seedResult.asTyped<SeedColorGenerationTestOutput>();
        expect(typedSeed, isNotNull);

        // Safe cast: incorrect type returns null
        expect(
          () => seedResult.asTyped<ColorSuiteGenerationTestOutput>(),
          throwsA(isA<Exception>()),
        );

        // Unsafe cast: throws if type is wrong
        expect(
          () => suiteResult.asTyped<SeedColorGenerationTestOutput>(),
          throwsA(isA<Exception>()),
        );

        // Unsafe cast: correct type does not throw
        expect(
          () => suiteResult.asTyped<ColorSuiteGenerationTestOutput>(),
          returnsNormally,
        );
      },
    );
  });
}
