import 'package:collection/collection.dart';

/// Enumeration of valid property types for schema definitions
enum PropertyType { string, number, boolean, array, object }

/// Extension to convert PropertyType to string for JSON schema
extension PropertyTypeExtension on PropertyType {
  String get value {
    switch (this) {
      case PropertyType.string:
        return 'string';
      case PropertyType.number:
        return 'number';
      case PropertyType.boolean:
        return 'boolean';
      case PropertyType.array:
        return 'array';
      case PropertyType.object:
        return 'object';
    }
  }
}

/// Represents a single property in an output schema
class PropertyEntry {
  /// The name of this property
  final String name;

  /// The type of the property
  final PropertyType type;

  /// Description of the property
  final String? description;

  /// For array types, defines the items structure
  final PropertyType? items;

  /// Minimum value for number types
  final num? minimum;

  /// Maximum value for number types
  final num? maximum;

  /// For object types, defines nested properties
  final List<PropertyEntry>? properties;

  /// For object types, defines which nested properties are required
  final List<String>? requiredProperties;

  const PropertyEntry({
    required this.name,
    required this.type,
    this.description,
    this.items,
    this.minimum,
    this.maximum,
    this.properties,
    this.requiredProperties,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PropertyEntry) return false;
    final listEq = const ListEquality();
    return name == other.name &&
        type == other.type &&
        description == other.description &&
        items == other.items &&
        minimum == other.minimum &&
        maximum == other.maximum &&
        listEq.equals(properties, other.properties) &&
        listEq.equals(requiredProperties, other.requiredProperties);
  }

  @override
  int get hashCode {
    final listEq = const ListEquality();
    return Object.hash(
      name,
      type,
      description,
      items,
      minimum,
      maximum,
      listEq.hash(properties),
      listEq.hash(requiredProperties),
    );
  }

  /// Factory method for string properties
  factory PropertyEntry.string({required String name, String? description}) {
    return PropertyEntry(
      name: name,
      type: PropertyType.string,
      description: description,
    );
  }

  /// Factory method for number properties
  factory PropertyEntry.number({
    required String name,
    String? description,
    num? minimum,
    num? maximum,
  }) {
    return PropertyEntry(
      name: name,
      type: PropertyType.number,
      description: description,
      minimum: minimum,
      maximum: maximum,
    );
  }

  /// Factory method for boolean properties
  factory PropertyEntry.boolean({required String name, String? description}) {
    return PropertyEntry(
      name: name,
      type: PropertyType.boolean,
      description: description,
    );
  }

  /// Factory method for array properties
  factory PropertyEntry.array({
    required String name,
    required PropertyType items,
    String? description,
  }) {
    return PropertyEntry(
      name: name,
      type: PropertyType.array,
      description: description,
      items: items,
    );
  }

  /// Factory method for object properties
  factory PropertyEntry.object({
    required String name,
    String? description,
    List<PropertyEntry>? properties,
    List<String>? requiredProperties,
  }) {
    return PropertyEntry(
      name: name,
      type: PropertyType.object,
      description: description,
      properties: properties,
      requiredProperties: requiredProperties,
    );
  }

  /// Converts this property entry to a JSON schema-compatible map
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'type': type.value};

    if (description != null) map['description'] = description;
    if (minimum != null) map['minimum'] = minimum;
    if (maximum != null) map['maximum'] = maximum;
    if (items != null) map['items'] = {'type': items!.value};
    if (properties != null) {
      map['properties'] = {
        for (final prop in properties!) prop.name: prop.toMap(),
      };
    }
    if (requiredProperties != null && requiredProperties!.isNotEmpty) {
      map['required'] = requiredProperties;
    }

    return map;
  }
}

/// Structured output schema for tool calls
class OutputSchema {
  /// The type of the root object (typically 'object')
  final PropertyType type;

  /// List of property definitions
  final List<PropertyEntry> properties;

  /// List of required property names
  final List<String> required;

  /// Template for system message when using this schema (optional)
  final String? systemMessageTemplate;

  const OutputSchema({
    this.type = PropertyType.object,
    required this.properties,
    this.required = const [],
    this.systemMessageTemplate,
  });

  /// Converts this schema to a JSON schema-compatible map
  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'properties': {for (final prop in properties) prop.name: prop.toMap()},
      'required': required,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OutputSchema) return false;
    final listEq = const ListEquality();
    return type == other.type &&
        listEq.equals(properties, other.properties) &&
        listEq.equals(required, other.required) &&
        systemMessageTemplate == other.systemMessageTemplate;
  }

  @override
  int get hashCode {
    final listEq = const ListEquality();
    return Object.hash(type, listEq.hash(properties), listEq.hash(required), systemMessageTemplate);
  }
}
