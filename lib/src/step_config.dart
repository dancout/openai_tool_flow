import 'audit_function.dart';
import 'issue.dart';

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

  const StepConfig({
    this.audits = const [],
    this.maxRetries,
    this.customPassCriteria,
    this.customFailureReason,
    this.stopOnFailure = true,
    this.auditOnlyFinalAttempt = false,
  });

  /// Creates a StepConfig with only specific audits
  const StepConfig.withAudits(List<AuditFunction> audits) : this(audits: audits);

  /// Creates a StepConfig with no audits (skip audit phase)
  const StepConfig.noAudits() : this(audits: const []);

  /// Creates a StepConfig with custom retry configuration
  const StepConfig.withRetries({
    required int maxRetries,
    List<AuditFunction> audits = const [],
  }) : this(audits: audits, maxRetries: maxRetries);

  /// Creates a StepConfig with custom pass/fail criteria
  const StepConfig.withCustomCriteria({
    required bool Function(List<Issue>) passedCriteria,
    String Function(List<Issue>)? failureReason,
    List<AuditFunction> audits = const [],
  }) : this(
    audits: audits,
    customPassCriteria: passedCriteria,
    customFailureReason: failureReason,
  );

  /// Returns true if this step has any audits configured
  bool get hasAudits => audits.isNotEmpty;

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