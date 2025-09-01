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
  final PropertyType? itemsType;

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
    this.itemsType,
    this.minimum,
    this.maximum,
    this.properties,
    this.requiredProperties,
  });

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
    required PropertyType itemsType,
    String? description,
  }) {
    return PropertyEntry(
      name: name,
      type: PropertyType.array,
      description: description,
      itemsType: itemsType,
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
    if (itemsType != null) map['items'] = itemsType!.value;
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

  const OutputSchema({
    this.type = PropertyType.object,
    required this.properties,
    this.required = const [],
  });

  /// Converts this schema to a JSON schema-compatible map
  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'properties': {for (final prop in properties) prop.name: prop.toMap()},
      'required': required,
    };
  }
}
