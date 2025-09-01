import 'audit_function.dart';
import 'issue.dart';
import 'output_schema.dart';
import 'typed_interfaces.dart';

/// Configuration for a specific step in a tool flow.
///
/// Allows different audit configurations and retry criteria per step.
/// Provides a clean interface for including outputs from previous steps.
class StepConfig {
  /// Audit functions to run for this specific step
  final List<AuditFunction> audits;

  /// Maximum number of retry attempts for this step
  /// Overrides the default from ToolCallStep if provided
  final int? maxRetries;

  /// Custom pass/fail criteria function for this step
  /// If provided, this will be used instead of individual audit criteria
  final bool Function(List<Issue>)? customPassCriteria;

  /// Custom failure reason function for this step
  /// If provided, this will be used to generate failure messages
  final String Function(List<Issue>)? customFailureReason;

  /// Whether to stop the entire flow if this step fails after all retries
  /// Defaults to true for backward compatibility
  final bool stopOnFailure;

  /// Whether to run audits on retry attempts or only on the final attempt
  /// Defaults to false (run audits on every attempt)
  final bool auditOnlyFinalAttempt;

  /// Simple list of steps to include outputs from.
  /// Can be int (step index) or String (tool name).
  ///
  /// **Usage Examples:**
  /// ```dart
  /// // Include outputs from step 0 and any step with tool name 'extract_palette'
  /// includeOutputsFrom: [0, 'extract_palette']
  ///
  /// // Include outputs from steps 1 and 2
  /// includeOutputsFrom: [1, 2]
  ///
  /// // Include outputs from 'refine_colors' tool (most recent if duplicates)
  /// includeOutputsFrom: ['refine_colors']
  /// ```
  ///
  /// **How it works:**
  /// - int values: References step by index (0-based)
  /// - String values: References step by tool name (most recent if duplicates)
  /// - All matching outputs are merged into input with `toolName_key` prefix
  /// - For example, if 'extract_palette' outputs `{'colors': [...]}`,
  ///   it becomes `{'extract_palette_colors': [...]}` in the receiving step
  final List<dynamic> includeOutputsFrom;

  /// Function to sanitize or transform the input before executing the step.
  ///
  /// This function receives the result of the `inputBuilder` step as its input,
  /// allowing you to clean, filter, or standardize the input data before the main
  /// step execution. Typical use cases include transforming data between steps,
  /// cleaning up field names, filtering out unwanted data, or standardizing the
  /// input format.
  ///
  /// Called before step execution.
  ///
  /// Example usage:
  /// ```dart
  /// inputSanitizer: (input) {
  ///   final cleaned = Map<String, dynamic>.from(input);
  ///   // Remove internal fields
  ///   cleaned.removeWhere((key, value) => key.startsWith('_'));
  ///   return cleaned;
  /// }
  /// ```
  final Map<String, dynamic> Function(Map<String, dynamic> input)?
  inputSanitizer;

  /// Function to sanitize/transform the output AFTER executing the step.
  /// Takes the raw output map and returns cleaned output.
  /// Called AFTER step execution.
  ///
  /// **When to use:** Clean up model responses, normalize data formats,
  /// remove sensitive information, or ensure consistent output structure.
  ///
  /// **Example:**
  /// ```dart
  /// outputSanitizer: (output) {
  ///   final cleaned = Map<String, dynamic>.from(output);
  ///   // Ensure colors are properly formatted
  ///   if (cleaned['colors'] is List) {
  ///     cleaned['colors'] = (cleaned['colors'] as List)
  ///         .where((color) => RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color))
  ///         .toList();
  ///   }
  ///   return cleaned;
  /// }
  /// ```
  final Map<String, dynamic> Function(Map<String, dynamic> output)?
  // TODO: Is there any way to force the `output` input (lol) to conform to a specific schema?
  /// Also, we need to enforce the output of this function to conform to that same schema.
  /// Not sure if we can be extending ToolOutput or a Schema or something.
  outputSanitizer;

  /// Schema definition for the expected tool output.
  /// This defines the structure that OpenAI tool calls should conform to.
  ///
  /// **When to use:** Define the exact output structure you expect from the tool call,
  /// ensuring type safety and consistent data formats.
  ///
  /// **Example:**
  /// ```dart
  /// outputSchema: OutputSchema(
  ///   properties: {
  ///     'colors': PropertyEntry(
  ///       type: 'array',
  ///       items: PropertyEntry(type: 'string'),
  ///       description: 'Array of hex color codes',
  ///     ),
  ///     'confidence': PropertyEntry(
  ///       type: 'number',
  ///       minimum: 0.0,
  ///       maximum: 1.0,
  ///       description: 'Confidence score for the extraction',
  ///     ),
  ///   },
  ///   required: ['colors', 'confidence'],
  /// )
  /// ```
  final OutputSchema? outputSchema;

  const StepConfig({
    this.audits = const [],
    this.maxRetries,
    this.customPassCriteria,
    this.customFailureReason,
    this.stopOnFailure = true,
    this.auditOnlyFinalAttempt = false,
    this.includeOutputsFrom = const [],
    this.inputSanitizer,
    this.outputSanitizer,
    this.outputSchema,
  });

  /// Gets the effective output schema for this step
  /// If outputSchema is provided, uses it. Otherwise, tries to derive from ToolOutput registry
  OutputSchema getEffectiveOutputSchema(String toolName) {
    // If explicit schema is provided, use it
    if (outputSchema != null) {
      return outputSchema!;
    }
    
    // Try to get schema from ToolOutput registry
    if (ToolOutputRegistry.hasTypedOutput(toolName)) {
      // For registered tools, we could attempt to create a sample instance
      // and derive schema from it, but this is complex without knowing constructor parameters
      // For now, return a generic schema - this could be enhanced later
      return const OutputSchema(
        properties: {
          'result': PropertyEntry(
            type: 'object',
            description: 'Tool output result',
          ),
        },
        required: ['result'],
      );
    }
    
    // Default fallback schema
    return const OutputSchema(
      properties: {
        'data': PropertyEntry(
          type: 'object',
          description: 'Generic tool output data',
        ),
      },
      required: [],
    );
  }

  /// Returns true if this step has any audits configured
  bool get hasAudits => audits.isNotEmpty;
  /// Returns true if this step should include outputs from previous steps
  bool
  // TODO: Does this belong on the ToolCallStep directly?
  get hasOutputInclusion => includeOutputsFrom.isNotEmpty;

  /// Returns true if this step has input sanitization configured
  bool get hasInputSanitizer => inputSanitizer != null;

  /// Returns true if this step has output sanitization configured
  bool get hasOutputSanitizer => outputSanitizer != null;

  /// Returns the effective max retries for this step
  /// Uses the override if provided, otherwise falls back to default
  int getEffectiveMaxRetries(int defaultMaxRetries) {
    return maxRetries ?? defaultMaxRetries;
  }

  /// Determines if the criteria are met for the given issues
  /// Uses custom criteria if provided, otherwise delegates to audit functions
  bool passedCriteria(List<Issue> issues) {
    if (customPassCriteria != null) {
      return customPassCriteria!(issues);
    }

    // If no custom criteria, check all audit functions
    for (final audit in audits) {
      if (!audit.passedCriteria(issues)) {
        return false;
      }
    }

    return true;
  }

  /// Gets the failure reason for the given issues
  /// Uses custom failure reason if provided, otherwise delegates to audit functions
  String getFailureReason(List<Issue> issues) {
    if (customFailureReason != null) {
      return customFailureReason!(issues);
    }

    // Collect failure reasons from audit functions that failed
    final failureReasons = <String>[];
    for (final audit in audits) {
      if (!audit.passedCriteria(issues)) {
        failureReasons.add('${audit.name}: ${audit.getFailureReason(issues)}');
      }
    }

    return failureReasons.isNotEmpty
        ? failureReasons.join('; ')
        : 'Step criteria not met';
  }

  /// Applies input sanitization if configured.
  /// Called BEFORE step execution to clean/transform input data.
  Map<String, dynamic> sanitizeInput(Map<String, dynamic> rawInput) {
    if (inputSanitizer == null) {
      return rawInput;
    }
    return inputSanitizer!(rawInput);
  }

  /// Applies output sanitization if configured.
  /// Called AFTER step execution to clean/transform output data.
  Map<String, dynamic> sanitizeOutput(Map<String, dynamic> rawOutput) {
    if (outputSanitizer == null) {
      return rawOutput;
    }

    return outputSanitizer!(rawOutput);
  }

  /// Creates a StepConfig from JSON
  factory StepConfig.fromJson(Map<String, dynamic> json) {
    return StepConfig(
      // Note: Audit functions cannot be serialized, would need a registry
      audits: const [],
      maxRetries: json['maxRetries'] as int?,
      stopOnFailure: json['stopOnFailure'] as bool? ?? true,
      auditOnlyFinalAttempt: json['auditOnlyFinalAttempt'] as bool? ?? false,
      // Note: Functions cannot be serialized
      includeOutputsFrom:
          json['includeOutputsFrom'] as List<dynamic>? ?? const [],
      outputSchema: json['outputSchema'] != null 
          ? OutputSchema.fromMap(json['outputSchema'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Converts to JSON (limited due to function serialization constraints)
  Map<String, dynamic> toJson() {
    return {
      'maxRetries': maxRetries,
      'stopOnFailure': stopOnFailure,
      'auditOnlyFinalAttempt': auditOnlyFinalAttempt,
      'hasAudits': hasAudits,
      'hasOutputInclusion': hasOutputInclusion,
      'hasInputSanitizer': hasInputSanitizer,
      'hasOutputSanitizer': hasOutputSanitizer,
      'includeOutputsFrom': includeOutputsFrom,
      'outputSchema': outputSchema?.toMap(),
    };
  }
}
