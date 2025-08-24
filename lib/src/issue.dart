/// Represents an issue identified during tool execution or audit.
/// 
/// This class follows a strict but extensible schema:
/// - Strict: certain fields are required
/// - Extensible: projects may extend the class with new fields
/// - The pipeline never strips fields — it always forwards the full object by serializing with `toJson()`
class Issue {
  /// Unique identifier for this issue
  final String id;
  
  /// Severity level of the issue
  final IssueSeverity severity;
  
  /// Human-readable description of the issue
  final String description;
  
  /// Structured metadata about where/why issue occurred
  final Map<String, dynamic> context;
  
  /// List of suggested resolutions
  final List<String> suggestions;

  /// Creates an Issue with required fields
  const Issue({
    required this.id,
    required this.severity,
    required this.description,
    required this.context,
    required this.suggestions,
  });

  /// Creates an Issue from a JSON map
  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'] as String,
      severity: IssueSeverity.fromString(json['severity'] as String),
      description: json['description'] as String,
      context: Map<String, dynamic>.from(json['context'] as Map),
      suggestions: List<String>.from(json['suggestions'] as List),
    );
  }

  /// Converts this Issue to a JSON map
  /// 
  /// Subclasses should override this method to include their additional fields
  /// while calling super.toJson() to preserve the base fields.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'severity': severity.toString(),
      'description': description,
      'context': context,
      'suggestions': suggestions,
    };
  }

  @override
  String toString() {
    return 'Issue(id: $id, severity: $severity, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Issue &&
        other.id == id &&
        other.severity == severity &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(id, severity, description);
}

/// Severity levels for issues
enum IssueSeverity {
  low,
  medium,
  high,
  critical;

  /// Creates an IssueSeverity from a string value
  static IssueSeverity fromString(String value) {
    switch (value.toLowerCase()) {
      case 'low':
        return IssueSeverity.low;
      case 'medium':
        return IssueSeverity.medium;
      case 'high':
        return IssueSeverity.high;
      case 'critical':
        return IssueSeverity.critical;
      default:
        throw ArgumentError('Invalid severity: $value');
    }
  }

  @override
  String toString() => name;
}