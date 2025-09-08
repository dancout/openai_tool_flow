# openai_toolflow

A structured way to sequentially call OpenAI tool functions, passing outputs from previous steps as inputs to subsequent steps with strong typing, retry logic, auditing, and token tracking.

## Features

- **Sequential Tool Execution**: Chain OpenAI tool calls where each step's output becomes the next step's input
- **Strong Typing**: All step inputs and outputs are strongly typed with schema validation
- **Configurable Retries**: Retry failed steps with configurable attempt limits per step
- **Audit System**: Validate step outputs with custom audit functions and issue severity levels
- **Token Usage Tracking**: Monitor and aggregate token usage across all steps and retries
- **Flexible Input Building**: Compose step inputs from any combination of previous step outputs
- **Data Sanitization**: Clean and transform data between steps with input/output sanitizers
- **Mock Support**: Built-in mock service injection for testing workflows

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  openai_toolflow: ^0.1.0
```

Then run:

```bash
dart pub get
```

## Quick Start

Here's a simple example that generates a color palette and then creates a design system:

```dart
import 'package:openai_toolflow/openai_toolflow.dart';

void main() async {
  // Configure OpenAI API
  final config = OpenAIConfig(
    apiKey: 'your-openai-api-key',
    defaultModel: 'gpt-4',
  );

  // Define the workflow steps
  final steps = [
    ToolCallStep.fromStepDefinition(
      SeedColorGenerationStepDefinition(),
      stepConfig: StepConfig(maxRetries: 2),
      inputBuilder: (previousResults) => {
        'user_preferences': {'style': 'modern', 'mood': 'professional'},
        'target_accessibility': 'AA'
      },
    ),
    ToolCallStep.fromStepDefinition(
      DesignSystemStepDefinition(),
      stepConfig: StepConfig(
        maxRetries: 2,
        inputSanitizer: (input) {
          // Transform seed colors for design system input
          final sanitized = Map<String, dynamic>.from(input);
          if (input.containsKey('seed_colors')) {
            sanitized['base_colors'] = input['seed_colors'];
          }
          return sanitized;
        },
      ),
      // No inputBuilder specified - uses previous step's output by default
    ),
  ];

  // Create and run the workflow
  final toolFlow = ToolFlow(
    config: config,
    steps: steps,
  );

  final result = await toolFlow.run(input: {
    'brand_context': 'enterprise software platform'
  });

  // Access results
  print('Generated ${result.finalResults.length} steps');
  print('Total tokens used: ${result.tokenUsage.totalTokens}');
  
  // Get specific step results
  final designColors = result.finalResults[1].output.toMap();
  print('Design system colors: ${designColors['system_colors']}');
}
```

## Core Components

### ToolFlow

The main orchestrator that executes your workflow steps sequentially:

```dart
final toolFlow = ToolFlow(
  config: OpenAIConfig(apiKey: 'your-key'),
  steps: [step1, step2, step3],
  openAiService: customService, // Optional: inject custom/mock service
);

final result = await toolFlow.run(input: {'initial': 'data'});
```

### ToolCallStep

Defines individual steps in your workflow:

```dart
final step = ToolCallStep.fromStepDefinition(
  MyStepDefinition(),
  model: 'gpt-4',                    // Optional: override default model
  stepConfig: StepConfig(            // Optional: step-specific configuration
    maxRetries: 3,
    audits: [myAuditFunction],
  ),
  inputBuilder: (previousResults) => { // Optional: compose input from previous steps
    'data': previousResults[0].output.toMap()['key'],
    'context': previousResults[1].output.toMap()['context'],
  },
);
```

### StepConfig

Configures individual step behavior:

```dart
final stepConfig = StepConfig(
  maxRetries: 3,                    // Retry attempts for this step
  audits: [colorValidationAudit],   // Custom validation functions
  stopOnFailure: true,              // Stop workflow if step fails
  
  // Data transformation functions
  inputSanitizer: (input) => cleanInput(input),
  outputSanitizer: (output) => cleanOutput(output),
  
  // Custom validation
  customPassCriteria: (issues) => issues.isEmpty,
  issuesSeverityFilter: IssueSeverity.high,
);
```

## Advanced Configuration

### Input Building Strategies

**Default behavior** (no `inputBuilder`): Use the previous step's output directly.

**Custom input building**: Compose inputs from multiple previous steps:

```dart
inputBuilder: (previousResults) => {
  'seed_colors': previousResults[0].output.toMap()['colors'],
  'user_feedback': previousResults[1].output.toMap()['feedback'],
  'constraints': {'accessibility': 'AA'},
}
```

### Data Sanitization

**Input Sanitizer**: Transforms data after `inputBuilder` but before step execution:

```dart
inputSanitizer: (input) {
  final cleaned = Map<String, dynamic>.from(input);
  // Remove internal fields
  cleaned.removeWhere((key, value) => key.startsWith('_'));
  return cleaned;
}
```

**Output Sanitizer**: Cleans step outputs after execution:

```dart
outputSanitizer: (output) {
  final cleaned = Map<String, dynamic>.from(output);
  // Ensure proper color format
  if (cleaned['colors'] is List) {
    cleaned['colors'] = (cleaned['colors'] as List)
        .where((color) => RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color))
        .toList();
  }
  return cleaned;
}
```

### Audit Functions

Create custom validation logic with configurable severity levels:

```dart
class ColorValidationAudit extends AuditFunction {
  @override
  String get auditName => 'color_validation';

  @override
  Future<List<Issue>> performAudit(Map<String, dynamic> output, int round) async {
    final issues = <Issue>[];
    final colors = output['colors'] as List?;
    
    if (colors == null || colors.isEmpty) {
      issues.add(Issue(
        id: 'missing_colors',
        severity: IssueSeverity.critical,
        description: 'No colors generated',
        suggestions: ['Retry with different parameters'],
        round: round,
      ));
    }
    
    return issues;
  }

  @override
  bool passedCriteria(List<Issue> issues) => 
      !issues.any((issue) => issue.severity == IssueSeverity.critical);
}
```

### Token Usage Tracking

Monitor API usage across your entire workflow:

```dart
final result = await toolFlow.run(input: data);

print('Token usage summary:');
print('  Total tokens: ${result.tokenUsage.totalTokens}');
print('  Prompt tokens: ${result.tokenUsage.promptTokens}');
print('  Completion tokens: ${result.tokenUsage.completionTokens}');

// Per-step token usage
for (int i = 0; i < result.finalResults.length; i++) {
  final stepTokens = result.finalResults[i].tokenUsage;
  print('  Step $i tokens: ${stepTokens.totalTokens}');
}
```

### Testing with Mock Services

Inject mock responses for testing:

```dart
final mockService = MockOpenAiToolService(
  responses: {
    'generate_colors': {
      'colors': ['#FF0000', '#00FF00', '#0000FF'],
      'confidence': 0.95,
    },
    'create_palette': {
      'palette': {
        'primary': '#FF0000',
        'secondary': '#00FF00',
        'accent': '#0000FF',
      }
    },
  },
);

final toolFlow = ToolFlow(
  config: config,
  steps: steps,
  openAiService: mockService, // Use mock instead of real API
);
```

## Issue Management

Issues are generated by audit functions and can be filtered by severity:

- `IssueSeverity.low`: Informational issues
- `IssueSeverity.medium`: Warnings that don't block execution  
- `IssueSeverity.high`: Significant issues that may cause retries
- `IssueSeverity.critical`: Blocking issues that fail the step

Configure issue filtering per step:

```dart
StepConfig(
  issuesSeverityFilter: IssueSeverity.high, // Include high and critical issues only
  customPassCriteria: (issues) => 
      !issues.any((issue) => issue.severity == IssueSeverity.critical),
)
```

## Error Handling and Retries

Steps automatically retry on failure with exponential backoff:

```dart
StepConfig(
  maxRetries: 3,              // Retry up to 3 times
  stopOnFailure: false,       // Continue to next step even if this fails
  customFailureReason: (issues) => 
      'Failed due to: ${issues.map((e) => e.description).join(', ')}',
)
```

## API Reference

For complete API documentation, see the [API reference](https://pub.dev/documentation/openai_toolflow/latest/).

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
