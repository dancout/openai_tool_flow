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

Here's a simple example that generates a feature pitch and then creates a marketing plan, using strongly-typed outputs and concrete step definitions:

```dart
import 'package:openai_toolflow/openai_toolflow.dart';

// Step 1: Generate feature pitch
class FeaturePitchOutput extends ToolOutput {
  final String name;
  final String tagline;
  final String valueProp;

  FeaturePitchOutput({
    required this.name,
    required this.tagline,
    required this.valueProp,
    required super.round,
  }) : super.subclass();

  @override
  Map<String, dynamic> toMap() => {
    'name': name,
    'tagline': tagline,
    'value_prop': valueProp,
    '_round': round,
  };

  factory FeaturePitchOutput.fromMap(Map<String, dynamic> map, int round) {
    return FeaturePitchOutput(
      name: map['name'] ?? '',
      tagline: map['tagline'] ?? '',
      valueProp: map['value_prop'] ?? '',
      round: round,
    );
  }
}

// Step 2: Generate marketing plan 
class MarketingPlanOutput extends ToolOutput {
  final String blogPostTitle;
  final String emailCampaignBody;
  final List<String> socialMediaPosts;

  MarketingPlanOutput({
    required this.blogPostTitle,
    required this.emailCampaignBody,
    required this.socialMediaPosts,
    required int round,
  }) : super.subclass(round: round);

  @override
  Map<String, dynamic> toMap() => {
    'blog_post_title': blogPostTitle,
    'email_campaign_body': emailCampaignBody,
    'social_media_posts': socialMediaPosts,
    '_round': round,
  };

  factory MarketingPlanOutput.fromMap(Map<String, dynamic> map, int round) {
    return MarketingPlanOutput(
      blogPostTitle: map['blog_post_title'] ?? '',
      emailCampaignBody: map['email_campaign_body'] ?? '',
      socialMediaPosts: List<String>.from(map['social_media_posts'] ?? []),
      round: round,
    );
  }
}

class FeaturePitchStepDefinition extends StepDefinition {
  @override
  ToolOutput fromMap(Map<String, dynamic> data, int round) {
    return FeaturePitchOutput.fromMap(data, round);
  }

  @override
  OutputSchema get outputSchema => OutputSchema(
    properties: [
      PropertyEntry.string(name: 'name'),
      PropertyEntry.string(name: 'tagline'),
      PropertyEntry.string(name: 'value_prop'),
    ],
  );

  @override
  String get stepName => 'generate_feature_pitch';
}

class MarketingPlanStepDefinition extends StepDefinition {
  @override
  ToolOutput fromMap(Map<String, dynamic> data, int round) {
    return MarketingPlanOutput.fromMap(data, round);
  }

  @override
  OutputSchema get outputSchema => OutputSchema(
    properties: [
      PropertyEntry.string(name: 'blog_post_title'),
      PropertyEntry.string(name: 'email_campaign_body'),
      PropertyEntry.array(
        name: 'social_media_posts',
        items: PropertyType.string,
      ),
    ],
  );

  @override
  String get stepName => 'generate_marketing_plan';
}

void main() async {
  final config = OpenAIConfig(
    apiKey: 'your-openai-api-key',
    defaultModel: 'gpt-4',
  );

  final steps = [
    ToolCallStep.fromStepDefinition(FeaturePitchStepDefinition()),
    ToolCallStep.fromStepDefinition(MarketingPlanStepDefinition()),
  ];

  final toolFlow = ToolFlow(config: config, steps: steps);

  final result = await toolFlow.run(
    input: {'product_category': 'project management tool'},
  );

  final encoder = JsonEncoder.withIndent('  ');
  print('Feature Pitch:');
  final featurePitch = result.finalResults[1]
      .asTyped<FeaturePitchOutput>()
      .output;
  print('Feature Pitch: ${encoder.convert(featurePitch.toMap())}\n');

  final marketingPlan = result.finalResults[2]
      .asTyped<MarketingPlanOutput>()
      .output;
  print('Marketing Plan: ${encoder.convert(marketingPlan.toMap())}');
}
```

## Core Components

### ToolFlow

The main orchestrator that executes your workflow steps sequentially:

```dart
final toolFlow = ToolFlow(
  config: OpenAIConfig(apiKey: 'your-key'),
  steps: [step1, step2, step3],
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
inputBuilder: (previousResults) => previousResults.last.toMap(),
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

**Output Sanitizer**: Cleans step outputs after execution. This is important to ensure your output matches the user's expectation and maintains data quality:

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
    
    if (colors == null || colors.length < 3) {
      issues.add(Issue(
        id: 'insufficient_colors',
        severity: IssueSeverity.critical,
        description: 'Not enough colors generated - need at least 3 colors',
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
