import 'audit_function.dart';
import 'issue.dart';
import 'tool_result.dart';

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

  /// Function to sanitize/transform the input BEFORE executing the step.
  /// Takes the raw input map and previous results, returns cleaned input.
  /// Called BEFORE step execution.
  ///
  /// **When to use:** Transform data between steps, clean up field names,
  /// filter out unwanted data, or combine data from multiple previous steps.
  ///
  /// **Example:**
  /// ```dart
  /// inputSanitizer: (input, previousResults) {
  ///   final cleaned = Map<String, dynamic>.from(input);
  ///   // Remove internal fields
  ///   cleaned.removeWhere((key, value) => key.startsWith('_'));
  ///   // Add processed data from previous steps
  ///   final paletteResult = previousResults.firstWhere((r) => r.toolName == 'extract_palette');
  ///   cleaned['processed_colors'] = paletteResult.output['colors'];
  ///   return cleaned;
  /// }
  /// ```
  final Map<String, dynamic> Function(
    // TODO: This should probably take in ToolInput/StepInput instead of just an unstructured Map
    Map<String, dynamic> input,
    List<ToolResult> previousResults,
  )?
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
  outputSanitizer;

  const StepConfig({
    this.audits = const [],
    this.maxRetries,
    this.customPassCriteria,
    this.customFailureReason,
    this.stopOnFailure = true,
    this.auditOnlyFinalAttempt = false,
    // TODO(DJC): Have I been thinking about includeOutputsFrom wrong? Are we more concerned with building the input of this step from the previous output than we are with pulling forward the raw output and issues from previous steps?
    /// So, all in all, does this go away?
    this.includeOutputsFrom = const [],
    this.inputSanitizer,
    this.outputSanitizer,
  });

  /// Returns true if this step has any audits configured
  bool get hasAudits => audits.isNotEmpty;

  /// Returns true if this step should include outputs from previous steps
  bool get hasOutputInclusion => includeOutputsFrom.isNotEmpty;

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

  /// Includes outputs from previous steps based on the includeOutputsFrom configuration.
  ///
  /// This method provides a clean way to access previous step results:
  /// - int values are treated as step indexes (0-based)
  /// - String values are treated as tool names
  /// - For duplicate tool names, only the most recent result is included
  /// - All matching outputs are merged into the input with tool name prefixes
  Map<String, dynamic> buildIncludedOutputs(
    List<ToolResult> previousResults,
    Map<String, ToolResult> resultsByToolName,
  ) {
    final includedOutputs = <String, dynamic>{};

    for (final reference in includeOutputsFrom) {
      ToolResult? sourceResult;

      // Find the source result by index or tool name
      if (reference is int) {
        if (reference >= 0 && reference < previousResults.length) {
          sourceResult = previousResults[reference];
        }
      } else if (reference is String) {
        sourceResult = resultsByToolName[reference];
      }

      if (sourceResult == null) continue;

      // Include all output with tool name prefix to avoid conflicts
      for (final entry in sourceResult.output.entries) {
        // TODO: Why do we need to prepend the toolName and the key again?
        // I don't think that really adds anything to this custom data.
        // TODO: I don't think we should add the output entries key by key, but instead we should just throw the entire typedOutput.toJson() onto there, and have the sanitizeInput take care of wittling down to what we do and don't need.
        includedOutputs['${sourceResult.toolName}_${entry.key}'] = entry.value;
      }
    }

    return includedOutputs;
  }

  /// Applies input sanitization if configured.
  /// Called BEFORE step execution to clean/transform input data.
  Map<String, dynamic> sanitizeInput(
    Map<String, dynamic> rawInput,
    List<ToolResult> previousResults,
  ) {
    if (inputSanitizer == null) {
      return rawInput;
    }

    return inputSanitizer!(rawInput, previousResults);
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
    };
  }
}

/// Extension methods for working with step configurations
extension StepConfigExtension on Map<int, StepConfig> {
  /// Gets the configuration for a specific step index
  /// Returns a default configuration if none is specified
  StepConfig getConfigForStep(int stepIndex) {
    return this[stepIndex] ?? const StepConfig();
  }

  /// Checks if a specific step has any audits configured
  bool stepHasAudits(int stepIndex) {
    return getConfigForStep(stepIndex).hasAudits;
  }
}
