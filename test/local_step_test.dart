import 'package:openai_toolflow/openai_toolflow.dart';
import 'package:test/test.dart';

/// Test output for local step
class ColorVariationOutput extends ToolOutput {
  final String baseColor;
  final List<String> variations;

  const ColorVariationOutput({
    required this.baseColor,
    required this.variations,
    required super.round,
  }) : super.subclass();

  @override
  Map<String, dynamic> toMap() => {
        '_round': round,
        'base_color': baseColor,
        'variations': variations,
      };

  factory ColorVariationOutput.fromMap(Map<String, dynamic> map, int round) {
    return ColorVariationOutput(
      baseColor: map['base_color'] as String? ?? '',
      variations: List<String>.from(map['variations'] ?? []),
      round: round,
    );
  }
}

/// Test step definition for local computation
class ColorVariationStepDefinition extends LocalStepDefinition<ColorVariationOutput> {
  @override
  String get stepName => 'generate_color_variations';

  @override
  OutputSchema get outputSchema => OutputSchema(
        properties: [
          PropertyEntry.string(name: 'base_color'),
          PropertyEntry.array(
            name: 'variations',
            items: PropertyType.string,
          ),
        ],
      );

  @override
  ColorVariationOutput fromMap(Map<String, dynamic> data, int round) {
    return ColorVariationOutput.fromMap(data, round);
  }

  @override
  Future<Map<String, dynamic>> computeFunction(Map<String, dynamic> input) async {
    // Extract base color from input
    final baseColor = input['color'] as String? ?? '#FF0000';
    
    // Generate variations by adjusting hex values
    final variations = _generateColorVariations(baseColor);
    
    return {
      'base_color': baseColor,
      'variations': variations,
    };
  }

  List<String> _generateColorVariations(String hexColor) {
    // Simple color variation logic for testing
    // Remove # if present
    final hex = hexColor.replaceAll('#', '');
    
    // Parse RGB values
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);
    
    // Generate 3 variations with proper clamping
    return [
      _rgbToHex((r * 0.8).clamp(0, 255).round(), (g * 0.8).clamp(0, 255).round(), (b * 0.8).clamp(0, 255).round()), // Darker
      _rgbToHex((r * 1.2).clamp(0, 255).round(), (g * 1.2).clamp(0, 255).round(), (b * 1.2).clamp(0, 255).round()), // Lighter
      _rgbToHex(r, (g * 0.9).clamp(0, 255).round(), (b * 1.1).clamp(0, 255).round()), // Adjusted
    ];
  }

  String _rgbToHex(int r, int g, int b) {
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }
}

/// Audit to validate color variations
class ColorVariationAudit extends AuditFunction<ColorVariationOutput> {
  @override
  String get name => 'color_variation_audit';

  @override
  List<Issue> run(ColorVariationOutput output) {
    final issues = <Issue>[];

    if (output.variations.length < 3) {
      issues.add(Issue(
        id: 'insufficient_variations',
        severity: IssueSeverity.critical,
        description: 'Expected at least 3 color variations, got ${output.variations.length}',
        context: {'expected': 3, 'actual': output.variations.length},
        suggestions: ['Ensure computation generates enough variations'],
        round: output.round,
      ));
    }

    // Validate hex color format
    final hexPattern = RegExp(r'^#[0-9A-F]{6}$');
    for (final color in output.variations) {
      if (!hexPattern.hasMatch(color)) {
        issues.add(Issue(
          id: 'invalid_hex_format',
          severity: IssueSeverity.high,
          description: 'Invalid hex color format: $color',
          context: {'color': color},
          suggestions: ['Ensure colors are in #RRGGBB format'],
          round: output.round,
        ));
      }
    }

    return issues;
  }

  @override
  bool passedCriteria(List<Issue> issues) {
    return !issues.any((issue) => issue.severity == IssueSeverity.critical);
  }
}

void main() {
  group('LocalStep', () {
    setUp(() {
      // Clear registry before each test
      ToolOutputRegistry.clearRegistry();
    });

    test('should create LocalStep with required parameters', () {
      final stepDef = ColorVariationStepDefinition();
      final step = LocalStep.fromStepDefinition(stepDef);

      expect(step.toolName, equals('generate_color_variations'));
      expect(step.outputSchema, isNotNull);
      expect(step.computeFunction, isNotNull);
    });

    test('should execute local computation without LLM calls', () async {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      final stepDef = ColorVariationStepDefinition();
      final step = LocalStep.fromStepDefinition(stepDef);

      final toolFlow = ToolFlow(
        config: config,
        steps: [step],
      );

      final result = await toolFlow.run(
        input: {'color': '#FF5733'},
      );

      // Verify step executed
      expect(result.finalResults.length, equals(2)); // Initial + 1 step
      
      final stepResult = result.finalResults[1];
      final output = stepResult.asTyped<ColorVariationOutput>().output;
      
      expect(output.baseColor, equals('#FF5733'));
      expect(output.variations.length, equals(3));
      
      // Verify zero token usage
      expect(stepResult.tokenUsage.totalTokens, equals(0));
      expect(stepResult.tokenUsage.promptTokens, equals(0));
      expect(stepResult.tokenUsage.completionTokens, equals(0));
    });

    test('should support audits on local step outputs', () async {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      final stepDef = ColorVariationStepDefinition();
      final step = LocalStep.fromStepDefinition(
        stepDef,
        stepConfig: StepConfig(
          audits: [ColorVariationAudit()],
        ),
      );

      final toolFlow = ToolFlow(
        config: config,
        steps: [step],
      );

      final result = await toolFlow.run(
        input: {'color': '#FF5733'},
      );

      // Verify step passed audits
      expect(result.finalResults[1].passesCriteria, isTrue);
      expect(result.passesCriteria, isTrue);
    });

    test('should support retries on audit failures', () async {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      // Create a step definition that fails audits initially
      final failingStepDef = _FailingColorVariationStepDefinition();
      final step = LocalStep.fromStepDefinition(
        failingStepDef,
        stepConfig: StepConfig(
          maxRetries: 2,
          audits: [ColorVariationAudit()],
        ),
      );

      final toolFlow = ToolFlow(
        config: config,
        steps: [step],
      );

      final result = await toolFlow.run(
        input: {'color': '#FF5733'},
      );

      // Should have multiple attempts
      expect(result.results[1].length, greaterThan(1)); // Multiple attempts
      
      // Final result should fail (our failing step never succeeds)
      expect(result.finalResults[1].passesCriteria, isFalse);
    });

    test('should support input builders with local steps', () async {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      final stepDef = ColorVariationStepDefinition();
      final step = LocalStep.fromStepDefinition(
        stepDef,
        inputBuilder: (previousResults) {
          // Transform input from previous step
          return {
            'color': '#00FF00', // Override with green
          };
        },
      );

      final toolFlow = ToolFlow(
        config: config,
        steps: [step],
      );

      final result = await toolFlow.run(
        input: {'color': '#FF5733'},
      );

      final output = result.finalResults[1].asTyped<ColorVariationOutput>().output;
      
      // Should use the overridden color from input builder
      expect(output.baseColor, equals('#00FF00'));
    });

    test('should support output sanitization', () async {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      final stepDef = ColorVariationStepDefinition();
      final step = LocalStep.fromStepDefinition(
        stepDef,
        stepConfig: StepConfig(
          outputSanitizer: (output) {
            // Transform variations in sanitizer
            final variations = output['variations'] as List<String>? ?? [];
            return {
              ...output,
              // Add suffix to each variation to prove sanitizer ran
              'variations': variations.map((v) => '$v-sanitized').toList(),
            };
          },
        ),
      );

      final toolFlow = ToolFlow(
        config: config,
        steps: [step],
      );

      final result = await toolFlow.run(
        input: {'color': '#FF5733'},
      );

      final output = result.finalResults[1].asTyped<ColorVariationOutput>().output;
      
      // Should have the -sanitized suffix added by sanitizer
      expect(output.variations[0], endsWith('-sanitized'));
      expect(output.variations[1], endsWith('-sanitized'));
      expect(output.variations[2], endsWith('-sanitized'));
    });

    test('should work in mixed workflow with ToolCallStep', () async {
      // This test verifies that LocalStep and ToolCallStep can be used together
      // We'll use a mock service for the ToolCallStep
      
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      // Register a simple tool output type
      ToolOutputRegistry.register<SimpleToolOutput>(
        'simple_tool',
        (data, round) => SimpleToolOutput.fromMap(data, round),
      );

      final mockService = _MockOpenAiService();
      
      final toolCallStep = ToolCallStep(
        toolName: 'simple_tool',
        outputSchema: OutputSchema(
          properties: [PropertyEntry.string(name: 'result')],
        ),
        stepConfig: StepConfig(),
      );

      final localStepDef = ColorVariationStepDefinition();
      final localStep = LocalStep.fromStepDefinition(localStepDef);

      final toolFlow = ToolFlow(
        config: config,
        steps: [toolCallStep, localStep],
        openAiService: mockService,
      );

      final result = await toolFlow.run(
        input: {'color': '#FF5733'},
      );

      // Should have 3 results: initial + tool call + local step
      expect(result.finalResults.length, equals(3));
      
      // First step should have token usage (mocked)
      expect(result.finalResults[1].tokenUsage.totalTokens, greaterThan(0));
      
      // Second step (local) should have zero token usage
      expect(result.finalResults[2].tokenUsage.totalTokens, equals(0));
    });

    test('should track zero token usage across flow', () async {
      final config = OpenAIConfig(
        apiKey: 'test-key',
        defaultModel: 'gpt-4',
      );

      final stepDef = ColorVariationStepDefinition();
      final step = LocalStep.fromStepDefinition(stepDef);

      final toolFlow = ToolFlow(
        config: config,
        steps: [step],
      );

      final result = await toolFlow.run(
        input: {'color': '#FF5733'},
      );

      // Check token usage in final state
      final tokenUsage = result.finalState['token_usage'] as Map<String, dynamic>?;
      expect(tokenUsage, isNotNull);
      expect(tokenUsage!['total_tokens'], equals(0));
      expect(tokenUsage['total_prompt_tokens'], equals(0));
      expect(tokenUsage['total_completion_tokens'], equals(0));
    });
  });
}

/// Failing step definition for testing retries
class _FailingColorVariationStepDefinition extends LocalStepDefinition<ColorVariationOutput> {
  @override
  String get stepName => 'failing_color_variations';

  @override
  OutputSchema get outputSchema => OutputSchema(
        properties: [
          PropertyEntry.string(name: 'base_color'),
          PropertyEntry.array(
            name: 'variations',
            items: PropertyType.string,
          ),
        ],
      );

  @override
  ColorVariationOutput fromMap(Map<String, dynamic> data, int round) {
    return ColorVariationOutput.fromMap(data, round);
  }

  @override
  Future<Map<String, dynamic>> computeFunction(Map<String, dynamic> input) async {
    // Always return insufficient variations to fail audit
    return {
      'base_color': '#FF0000',
      'variations': ['#CC0000'], // Only 1 variation, needs 3
    };
  }
}

/// Simple tool output for mixed workflow test
class SimpleToolOutput extends ToolOutput {
  final String result;

  const SimpleToolOutput({
    required this.result,
    required super.round,
  }) : super.subclass();

  @override
  Map<String, dynamic> toMap() => {
        '_round': round,
        'result': result,
      };

  factory SimpleToolOutput.fromMap(Map<String, dynamic> map, int round) {
    return SimpleToolOutput(
      result: map['result'] as String? ?? '',
      round: round,
    );
  }
}

/// Mock OpenAI service for testing
class _MockOpenAiService implements OpenAiToolService {
  @override
  Future<ToolCallResponse> executeToolCall(
    ToolCallStep step,
    ToolInput input, {
    List<ToolResult>? includedResults,
    List<ToolResult>? currentStepRetries,
  }) async {
    // Return a mock response
    return ToolCallResponse(
      output: {
        'result': 'mock result',
        'color': '#FF5733',
      },
      usage: {
        'prompt_tokens': 10,
        'completion_tokens': 20,
        'total_tokens': 30,
      },
    );
  }
}
