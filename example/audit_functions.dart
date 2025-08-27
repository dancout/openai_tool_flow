import 'package:openai_toolflow/openai_toolflow.dart';

/// A simple audit function that can be created with a function
/// 
/// This implementation is provided in the example for flexibility,
/// allowing projects to use it or create their own audit implementations.
class SimpleAuditFunction extends AuditFunction {
  @override
  final String name;
  
  final List<Issue> Function(ToolResult) _auditFunction;
  final bool Function(List<Issue>)? _passedCriteriaFunction;
  final String Function(List<Issue>)? _failureReasonFunction;

  /// Creates a simple audit function with a name and audit function
  SimpleAuditFunction({
    required this.name,
    required List<Issue> Function(ToolResult) auditFunction,
    bool Function(List<Issue>)? passedCriteriaFunction,
    String Function(List<Issue>)? failureReasonFunction,
  }) : _auditFunction = auditFunction,
       _passedCriteriaFunction = passedCriteriaFunction,
       _failureReasonFunction = failureReasonFunction;

  @override
  List<Issue> run(ToolResult result) => _auditFunction(result);

  @override
  bool passedCriteria(List<Issue> issues) {
    return _passedCriteriaFunction?.call(issues) ?? super.passedCriteria(issues);
  }

  @override
  String getFailureReason(List<Issue> issues) {
    return _failureReasonFunction?.call(issues) ?? super.getFailureReason(issues);
  }
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

/// Example of a comprehensive color audit function
class ColorQualityAuditFunction extends AuditFunction {
  @override
  String get name => 'color_quality_audit';

  @override
  List<Issue> run(ToolResult result) {
    final issues = <Issue>[];
    
    // TODO: If we could specify this AuditFunction's run method to intake a more specifc ToolResult, then we wouldn't have to convert it to a map and then hope that we find a list of colors at ['colors']

    // Check if colors are in valid hex format
    final colors = result.output.toMap()['colors'] as List?;
    if (colors != null) {
      for (int i = 0; i < colors.length; i++) {
        final color = colors[i] as String;
        if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
          issues.add(ColorQualityIssue(
            id: 'invalid_color_format_$i',
            severity: IssueSeverity.medium,
            description: 'Color $color is not in valid hex format',
            context: {
              'color_index': i,
              'color_value': color,
              'expected_format': '#RRGGBB',
            },
            suggestions: ['Convert to valid hex format'],
            problematicColor: color,
            qualityScore: 0.0,
          ));
        }
      }
    }
    
    return issues;
  }

  @override
  bool passedCriteria(List<Issue> issues) {
    // Custom criteria: pass if no medium or higher severity issues
    return !issues.any((issue) => 
      issue.severity == IssueSeverity.medium ||
      issue.severity == IssueSeverity.high ||
      issue.severity == IssueSeverity.critical
    );
  }

  @override
  String getFailureReason(List<Issue> issues) {
    final problemIssues = issues.where((issue) => 
      issue.severity == IssueSeverity.medium ||
      issue.severity == IssueSeverity.high ||
      issue.severity == IssueSeverity.critical
    ).toList();
    
    if (problemIssues.isNotEmpty) {
      final descriptions = problemIssues.map((issue) => issue.description).join(', ');
      return 'Color quality issues found: $descriptions';
    }
    
    return super.getFailureReason(issues);
  }
}

/// Example of a diversity audit function with weighted threshold
class ColorDiversityAuditFunction extends AuditFunction {
  final int minimumColors;
  final double weightedThreshold;

  ColorDiversityAuditFunction({
    this.minimumColors = 3,
    this.weightedThreshold = 5.0, // Weighted score threshold
  });

  @override
  String get name => 'color_diversity_audit';

  @override
  List<Issue> run(ToolResult result) {
    final issues = <Issue>[];
    
    // Check if we have enough colors
    final colors = result.output.toMap()['colors'] as List?;
    if (colors == null || colors.length < minimumColors) {
      issues.add(Issue(
        id: 'insufficient_colors',
        severity: IssueSeverity.high,
        description: 'Not enough colors extracted for a diverse palette',
        context: {
          'colors_found': colors?.length ?? 0,
          'minimum_required': minimumColors,
        },
        suggestions: [
          'Adjust extraction parameters',
          'Try a different image with more color variety',
        ],
      ));
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