import 'audit_function.dart';
import 'issue.dart';

/// Configuration for a specific step in a tool flow.
///
/// Allows different audit configurations and retry criteria per step.
/// Provides a clean interface for including outputs from previous steps.
class StepConfig {
  /// Audit functions to run for this specific step
  final List<AuditFunction> audits;

  /// Maximum number of retry attempts for this step
  /// Overrides the default from ToolCallStep if provided
  final int maxRetries;

  /// Custom pass/fail criteria function for this step
  /// If provided, this will be used instead of individual audit criteria
  final bool Function(List<Issue>)? customPassCriteria;

  /// Custom failure reason function for this step
  /// If provided, this will be used to generate failure messages
  final String Function(List<Issue>)? customFailureReason;

  /// Whether to stop the entire flow if this step fails after all retries
  /// Defaults to true for backward compatibility
  final bool stopOnFailure;

  /// List of steps results to include ToolOutputs and their associated issues from in the OpenAI tool call.
  /// Can be int (step index) or String (tool name).
  ///
  /// **Usage Examples:**
  /// ```dart
  /// // Include results from step 0 and any step with tool name 'extract_palette'
  /// includeResultsInToolcall: [0, 'extract_palette']
  ///
  /// // Include results from steps 1 and 2
  /// includeResultsInToolcall: [1, 2]
  ///
  /// // Include results from 'refine_colors' tool (most recent if duplicates)
  /// includeResultsInToolcall: ['refine_colors']
  /// ```
  ///
  /// **How it works:**
  /// - int values: References step by index (0-based)
  /// - String values: References step by tool name (most recent if duplicates)
  /// - Results and their associated issues (filtered by severity) are included in the system message
  /// - Provides context like "here's what you did previously and why it was wrong"
  final List<dynamic> includeResultsInToolcall;

  /// Minimum severity level for issues to include when using includeResultsInToolcall.
  /// Issues at this level and higher will be included in the system message.
  /// Defaults to IssueSeverity.high to include high and critical issues only.
  ///
  /// **Examples:**
  /// - `IssueSeverity.low`: Includes low, medium, high, and critical issues
  /// - `IssueSeverity.medium`: Includes medium, high, and critical issues
  /// - `IssueSeverity.high`: Includes high and critical issues (default)
  /// - `IssueSeverity.critical`: Includes only critical issues
  final IssueSeverity issuesSeverityFilter;

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
  //
  // TODO: Is there any way to force the `output` input (lol) to conform to a specific schema?
  /// Also, we need to enforce the output of this function to conform to that same schema.
  /// Not sure if we can be extending ToolOutput or a Schema or something.
  outputSanitizer;

  const StepConfig({
    this.audits = const [],
    this.maxRetries = 3,
    this.customPassCriteria,
    this.customFailureReason,
    this.stopOnFailure = true,
    this.includeResultsInToolcall = const [],
    this.issuesSeverityFilter = IssueSeverity.high,
    this.inputSanitizer,
    this.outputSanitizer,
  });

  /// Returns true if this step has any audits configured
  bool get hasAudits => audits.isNotEmpty;

  /// Returns true if this step has input sanitization configured
  bool get hasInputSanitizer => inputSanitizer != null;

  /// Returns true if this step has output sanitization configured
  bool get hasOutputSanitizer => outputSanitizer != null;

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
}
