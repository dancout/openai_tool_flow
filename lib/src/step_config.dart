import 'audit_function.dart';
import 'issue.dart';
import 'tool_result.dart';

/// Configuration for forwarding specific step outputs/issues to this step.
class ForwardingConfig {
  /// Step index (or tool name) to forward from
  final dynamic stepReference;

  /// Whether to forward the output from this step
  final bool forwardOutput;

  /// Whether to forward issues from this step
  final bool forwardIssues;

  /// Filter function for which issues to forward
  final bool Function(Issue)? issueFilter;

  /// Keys to include from the output (null means all)
  final List<String>? outputKeys;

  const ForwardingConfig({
    required this.stepReference,
    this.forwardOutput = true,
    this.forwardIssues = true,
    this.issueFilter,
    this.outputKeys,
  });

  /// Creates a config to forward everything from a step
  ForwardingConfig.all(this.stepReference)
      : forwardOutput = true,
        forwardIssues = true,
        issueFilter = null,
        outputKeys = null;

  /// Creates a config to forward only output from a step
  ForwardingConfig.outputOnly(this.stepReference, {this.outputKeys})
      : forwardOutput = true,
        forwardIssues = false,
        issueFilter = null;

  /// Creates a config to forward only issues from a step
  ForwardingConfig.issuesOnly(this.stepReference, {this.issueFilter})
      : forwardOutput = false,
        forwardIssues = true,
        outputKeys = null;
}

/// Configuration for a specific step in a tool flow.
///
/// Allows different audit configurations and retry criteria per step.
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

  /// Configuration for which previous step outputs/issues to forward
  final List<ForwardingConfig> forwardingConfigs;

  /// Function to sanitize/transform previous step outputs for use as input
  /// Takes previous step results and returns cleaned input
  final Map<String, dynamic> Function(List<ToolResult>)? outputSanitizer;

  const StepConfig({
    this.audits = const [],
    this.maxRetries,
    this.customPassCriteria,
    this.customFailureReason,
    this.stopOnFailure = true,
    this.auditOnlyFinalAttempt = false,
    this.forwardingConfigs = const [],
    this.outputSanitizer,
  });

  /// Returns true if this step has any audits configured
  bool get hasAudits => audits.isNotEmpty;

  /// Returns true if this step has any forwarding configured
  bool get hasForwarding => forwardingConfigs.isNotEmpty;

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

  /// Filters and forwards outputs/issues from previous steps based on configuration
  Map<String, dynamic> buildForwardedInput(
    List<ToolResult> previousResults,
    Map<String, ToolResult> resultsByToolName,
  ) {
    final forwardedInput = <String, dynamic>{};

    for (final config in forwardingConfigs) {
      ToolResult? sourceResult;

      // Find the source result by index or tool name
      if (config.stepReference is int) {
        final index = config.stepReference as int;
        if (index >= 0 && index < previousResults.length) {
          sourceResult = previousResults[index];
        }
      } else if (config.stepReference is String) {
        final toolName = config.stepReference as String;
        sourceResult = resultsByToolName[toolName];
      }

      if (sourceResult == null) continue;

      // Forward output if configured
      if (config.forwardOutput) {
        final output = sourceResult.output;
        if (config.outputKeys != null) {
          // Forward only specific keys
          for (final key in config.outputKeys!) {
            if (output.containsKey(key)) {
              forwardedInput['${sourceResult.toolName}_$key'] = output[key];
            }
          }
        } else {
          // Forward all output keys with tool name prefix
          for (final entry in output.entries) {
            forwardedInput['${sourceResult.toolName}_${entry.key}'] = entry.value;
          }
        }
      }

      // Forward issues if configured
      if (config.forwardIssues) {
        final issues = sourceResult.issues;
        final filteredIssues = config.issueFilter != null
            ? issues.where(config.issueFilter!).toList()
            : issues;

        if (filteredIssues.isNotEmpty) {
          forwardedInput['_forwarded_issues_${sourceResult.toolName}'] = 
              filteredIssues.map((issue) => issue.toJson()).toList();
          
          // Also add the associated output for context
          forwardedInput['_forwarded_output_${sourceResult.toolName}'] = sourceResult.output;
        }
      }
    }

    return forwardedInput;
  }

  /// Applies output sanitization if configured
  Map<String, dynamic> sanitizeInput(
    Map<String, dynamic> rawInput,
    List<ToolResult> previousResults,
  ) {
    if (outputSanitizer == null) {
      return rawInput;
    }

    final sanitizedInput = Map<String, dynamic>.from(rawInput);
    final sanitizedData = outputSanitizer!(previousResults);
    sanitizedInput.addAll(sanitizedData);

    return sanitizedInput;
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
      forwardingConfigs: const [],
    );
  }

  /// Converts to JSON (limited due to function serialization constraints)
  Map<String, dynamic> toJson() {
    return {
      'maxRetries': maxRetries,
      'stopOnFailure': stopOnFailure,
      'auditOnlyFinalAttempt': auditOnlyFinalAttempt,
      'hasAudits': hasAudits,
      'hasForwarding': hasForwarding,
      'hasOutputSanitizer': hasOutputSanitizer,
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
