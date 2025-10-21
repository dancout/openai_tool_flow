/// Professional color workflow audit functions.
///
/// This file demonstrates audit functions for the 3-step professional color workflow:
/// - ColorDiversityAuditFunction: Audits seed color generation (step 1)
/// - ColorQualityAuditFunction: Audits design system colors (step 2)
library;

import 'package:openai_toolflow/openai_toolflow.dart';

import 'typed_interfaces.dart';

/// Audit for duplicate color values in a map
List<Issue> _checkForDuplicateColorValues(
  Map<String, String> colorMap,
  String contextLabel,
) {
  final issues = <Issue>[];
  final valueCounts = <String, List<String>>{}; // colorHex -> [keys]
  colorMap.forEach((key, value) {
    valueCounts.putIfAbsent(value, () => []).add(key);
  });
  final duplicates = valueCounts.entries
      .where((e) => e.value.length > 1)
      .toList();
  if (duplicates.isNotEmpty) {
    for (final dup in duplicates) {
      final colorHash = dup.key;
      final keys = dup.value;
      final keysList = keys.join(", ");
      issues.add(
        Issue(
          id: 'duplicate_colors',
          severity: IssueSeverity.critical,
          description:
              'Duplicate color value "$colorHash" found for multiple keys in $contextLabel: $keysList',
          context: {'duplicates': 'Color $colorHash used for: $keysList'},
          suggestions: [
            'The color "$colorHash" is used for: $keysList. These should be visually distinct. For example, make one lighter and one darker, or otherwise differentiate them to clarify their roles (e.g., border vs. icon).',
            'Review your color generation prompt and logic. You may keep any color values in the color suite that are not mentioned in any duplicate color issues, as those are not problematic. However, for the colors listed in this issue, you must introduce some change to ensure they are visually distinct.',
          ],
        ),
      );
    }
  }
  return issues;
}

/// Example of extending the Issue class for custom audit needs
class ColorQualityIssue extends Issue {
  /// The color that caused the issue
  final String problematicColor;

  /// Quality score (0.0 to 1.0)
  final double qualityScore;

  ColorQualityIssue({
    required super.id,
    required super.severity,
    required super.description,
    required super.context,
    required super.suggestions,
    super.round = 0,
    super.relatedData,
    required this.problematicColor,
    required this.qualityScore,
  });

  factory ColorQualityIssue.fromJson(Map<String, dynamic> json) {
    return ColorQualityIssue(
      id: json['id'] as String,
      severity: IssueSeverity.fromString(json['severity'] as String),
      description: json['description'] as String,
      context: Map<String, dynamic>.from(json['context'] as Map),
      suggestions: List<String>.from(json['suggestions'] as List),
      round: json['round'] as int? ?? 0,
      relatedData: json['relatedData'] != null
          ? Map<String, dynamic>.from(json['relatedData'] as Map)
          : null,
      problematicColor: json['problematicColor'] as String,
      qualityScore: json['qualityScore'] as double,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['problematicColor'] = problematicColor;
    json['qualityScore'] = qualityScore;
    return json;
  }
}

class FullColorSuiteQualityAuditFunction
    extends AuditFunction<FullColorSuiteOutput> {
  @override
  String get name => 'full_color_suite_quality_audit';

  @override
  List<Issue> run(FullColorSuiteOutput output) {
    final issues = <Issue>[];
    issues.addAll(_validateColorFormat(output.colorSuite));
    issues.addAll(
      _checkForDuplicateColorValues(output.colorSuite, 'color_suite'),
    );
    return issues;
  }
}

List<Issue> _validateColorFormat(Map<String, String> colors) {
  final issues = <Issue>[];

  int colorIndex = 0;

  colors.forEach((colorName, colorValue) {
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(colorValue)) {
      issues.add(
        ColorQualityIssue(
          id: 'invalid_color_format_$colorIndex',
          severity: IssueSeverity.critical,
          description:
              'Color $colorName ($colorValue) is not in valid, 6-digit hex format',
          context: {
            'color_name': colorName,
            'color_value': colorValue,
            'expected_format': '#RRGGBB',
          },
          suggestions: ['Convert to valid, 6-digit hex format'],
          problematicColor: colorValue,
          qualityScore: 0.0,
        ),
      );
    }
    colorIndex++;
  });

  return issues;
}

/// Example of a comprehensive color audit function for design system colors
class ColorQualityAuditFunction extends AuditFunction<DesignSystemColorOutput> {
  @override
  String get name => 'color_quality_audit';

  @override
  List<Issue> run(DesignSystemColorOutput output) {
    final systemColors = output.systemColors;
    final issues = <Issue>[];
    issues.addAll(_validateColorFormat(systemColors));
    issues.addAll(_checkForDuplicateColorValues(systemColors, 'system_colors'));
    return issues;
  }

  @override
  bool passedCriteria(List<Issue> issues) {
    // Custom criteria: pass if no medium or higher severity issues
    return !issues.any(
      (issue) =>
          issue.severity == IssueSeverity.medium ||
          issue.severity == IssueSeverity.high ||
          issue.severity == IssueSeverity.critical,
    );
  }

  @override
  String getFailureReason(List<Issue> issues) {
    final problemIssues = issues
        .where(
          (issue) =>
              issue.severity == IssueSeverity.medium ||
              issue.severity == IssueSeverity.high ||
              issue.severity == IssueSeverity.critical,
        )
        .toList();

    if (problemIssues.isNotEmpty) {
      final descriptions = problemIssues
          .map((issue) => issue.description)
          .join(', ');
      return 'Color quality issues found: $descriptions';
    }

    return super.getFailureReason(issues);
  }
}

/// Example of a diversity audit function with weighted threshold for seed colors
class ColorDiversityAuditFunction
    extends AuditFunction<SeedColorGenerationOutput> {
  final int minimumColors;
  final double weightedThreshold;

  ColorDiversityAuditFunction({
    this.minimumColors = 3,
    this.weightedThreshold = 5.0, // Weighted score threshold
  });

  @override
  String get name => 'color_diversity_audit';

  @override
  List<Issue> run(SeedColorGenerationOutput output) {
    final issues = <Issue>[];

    // Check if we have enough colors using strongly-typed access
    final colors = output.seedColors;
    if (colors.length < minimumColors) {
      issues.add(
        Issue(
          id: 'insufficient_colors',
          severity: IssueSeverity.high,
          description: 'Not enough seed colors generated for a diverse palette',
          context: {
            'colors_found': colors.length,
            'minimum_required': minimumColors,
          },
          suggestions: [
            'Adjust generation parameters',
            'Request more diverse color theory approaches',
          ],
        ),
      );
    }

    return issues;
  }

  @override
  bool passedCriteria(List<Issue> issues) {
    // Custom weighted scoring: assign weights to severity levels
    double totalWeight = 0.0;

    for (final issue in issues) {
      switch (issue.severity) {
        case IssueSeverity.low:
          totalWeight += 1.0;
          break;
        case IssueSeverity.medium:
          totalWeight += 2.0;
          break;
        case IssueSeverity.high:
          totalWeight += 4.0;
          break;
        case IssueSeverity.critical:
          totalWeight += 8.0;
          break;
      }
    }

    return totalWeight <= weightedThreshold;
  }

  @override
  String getFailureReason(List<Issue> issues) {
    double totalWeight = 0.0;

    for (final issue in issues) {
      switch (issue.severity) {
        case IssueSeverity.low:
          totalWeight += 1.0;
          break;
        case IssueSeverity.medium:
          totalWeight += 2.0;
          break;
        case IssueSeverity.high:
          totalWeight += 4.0;
          break;
        case IssueSeverity.critical:
          totalWeight += 8.0;
          break;
      }
    }

    return 'Weighted issue score ($totalWeight) exceeds threshold ($weightedThreshold). Issues: ${issues.map((i) => '${i.severity.name}: ${i.description}').join(', ')}';
  }
}
