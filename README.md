# openai_toolflow

TODO: LOOK AT THIS!
check out https://pub.dev/packages/dartantic_ai and see if that is too similar to what you are doing for this to be worthwhile to pursue.

`openai_toolflow` is a Dart package for orchestrating **OpenAI tool calls with audits**.  
It allows developers to define a pipeline of tool calls (functions executed through OpenAI models) where:

- Each tool call can pass structured outputs or issues to later steps.
- Audit functions (implemented by your app) can generate issues, which feed back into the pipeline.
- Model parameters (tokens, temperature, etc.) can be customized per call.
- State is managed internally: no need for the super project to track intermediate results.
- All data structures (`ToolResult`, `Issue`) are **strict but extensible classes**.  
  You can extend them in your own project, and the pipeline will continue to forward them by serializing with `toJson()`.

This package is designed to be generic and extensible, so you can define your own tools and audits, then chain them together declaratively.

## Package Purpose

This repository is intended to be published as a package on [pub.dev](https://pub.dev/) for use in other Dart/Flutter projects.

**Note:** Audit function definitions and similar responsibilities are delegated to the super (importing) project, not this package.

---

## Features
- Structured tool call execution
- Strict but extensible classes for tool results and audit issues
- Configurable OpenAI model parameters
- Abstract audit hooks for domain-specific validations
- Internal state handling across tool calls
- All results and issues are serialized and forwarded with `toJson()`
- Ready for Flutter and Dart backends

---

## Type-Safe Step Configuration

`openai_toolflow` provides a **StepDefinition pattern** for type-safe tool configuration that eliminates error-prone string usage and automates registration:

### Step Definitions

Define step metadata in centralized classes that encapsulate:
- Static step name constants
- Output schema definitions  
- Type-safe factory methods
- Automatic registration

```dart
class PaletteExtractionStepDefinition extends StepDefinition<PaletteExtractionOutput> {
  @override
  String get stepName => PaletteExtractionOutput.stepName;
  
  @override
  OutputSchema get outputSchema => PaletteExtractionOutput.getOutputSchema();
  
  @override
  PaletteExtractionOutput fromMap(Map<String, dynamic> data, int round) =>
      PaletteExtractionOutput.fromMap(data, round);
}
```

### Automatic Registration

Use `ToolCallStep.fromStepDefinition()` for automatic registration and type safety:

```dart
final paletteStep = PaletteExtractionStepDefinition();

final workflow = {
  paletteStep.stepName: ToolCallStep.fromStepDefinition(
    paletteStep,
    model: 'gpt-4',
    inputBuilder: (previousResults) => {'imagePath': 'assets/image.jpg'},
    // StepConfig is automatically created with correct output schema
    // ToolOutputRegistry registration happens automatically
  ),
};
```

### Benefits

- **Compile-time safety**: Use `PaletteExtractionOutput.stepName` instead of error-prone strings
- **Automatic registration**: No need to manually call `ToolOutputRegistry.register()`
- **Single source of truth**: All step metadata centralized in one place
- **IDE support**: Full autocomplete and refactoring support

---

## Example: Color Theme Generator


Below is a pseudocode example showing how you might use `openai_toolflow` to generate a color theme from an image. This is intended as a starting point for development and can be adapted to your needs.

```dart
// Pseudocode: Color Theme Generator Flow

final flow = ToolFlow(
    config: OpenAIConfig(
        apiKey: 'YOUR_OPENAI_API_KEY',
        defaultModel: 'gpt-4.1',
    ),
    steps: [
        ToolCallStep(
            toolName: 'extract_palette',
            model: 'gpt-5',
            params: {
                'max_colors': 8,
            },
        ),
        AuditStep(
            auditName: 'palette_quality_check',
            // Custom audit logic to ensure palette meets requirements
        ),
        ToolCallStep(
            toolName: 'propose_base_colors',
            model: 'gpt-5',
            params: {
                'palette_type': 'material',
            },
        ),
        AuditStep(
            auditName: 'base_color_audit',
            // Custom audit logic for base colors
        ),
        ToolCallStep(
            toolName: 'expand_families',
            model: 'gpt-4.1',
            params: {
                'family_count': 5,
            },
        ),
    ],
);

final result = await flow.run(input: {
    'imagePath': 'assets/myimage.png',
});

print(result.toJson());
```

You can extend `ToolResult` and `Issue` classes to include custom fields for your application.  
Audit steps can be implemented to validate outputs and inject issues back into the flow.
```dart
