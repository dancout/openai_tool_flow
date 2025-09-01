import 'typed_interfaces.dart';

/// Represents a single property in an output schema
class PropertyEntry {
  /// The type of the property (e.g., 'string', 'number', 'boolean', 'array', 'object')
  final String type;
  
  /// Description of the property
  final String? description;
  
  /// For array types, defines the items structure
  final PropertyEntry? items;
  
  /// Minimum value for number types
  final num? minimum;
  
  /// Maximum value for number types  
  final num? maximum;
  
  /// For object types, defines nested properties
  final Map<String, PropertyEntry>? properties;
  
  /// For object types, defines which nested properties are required
  final List<String>? requiredProperties;

  const PropertyEntry({
    required this.type,
    this.description,
    this.items,
    this.minimum,
    this.maximum,
    this.properties,
    this.requiredProperties,
  });

  /// Converts this property entry to a JSON schema-compatible map
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type': type,
    };
    
    if (description != null) map['description'] = description;
    if (minimum != null) map['minimum'] = minimum;
    if (maximum != null) map['maximum'] = maximum;
    if (items != null) map['items'] = items!.toMap();
    if (properties != null) {
      map['properties'] = properties!.map((key, value) => MapEntry(key, value.toMap()));
    }
    if (requiredProperties != null && requiredProperties!.isNotEmpty) {
      map['required'] = requiredProperties;
    }
    
    return map;
  }

  /// Creates a PropertyEntry from a map
  factory PropertyEntry.fromMap(Map<String, dynamic> map) {
    return PropertyEntry(
      type: map['type'] as String,
      description: map['description'] as String?,
      items: map['items'] != null ? PropertyEntry.fromMap(map['items'] as Map<String, dynamic>) : null,
      minimum: map['minimum'] as num?,
      maximum: map['maximum'] as num?,
      properties: map['properties'] != null 
        ? (map['properties'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, PropertyEntry.fromMap(value as Map<String, dynamic>))
          )
        : null,
      requiredProperties: map['required'] != null 
        ? (map['required'] as List).cast<String>()
        : null,
    );
  }
}

/// Structured output schema for tool calls
class OutputSchema {
  /// The type of the root object (typically 'object')
  final String type;
  
  /// Map of property names to their definitions
  final Map<String, PropertyEntry> properties;
  
  /// List of required property names
  final List<String> required;

  const OutputSchema({
    this.type = 'object',
    required this.properties,
    this.required = const [],
  });

  /// Converts this schema to a JSON schema-compatible map
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'properties': properties.map((key, value) => MapEntry(key, value.toMap())),
      'required': required,
    };
  }

  /// Creates an OutputSchema from a map
  factory OutputSchema.fromMap(Map<String, dynamic> map) {
    return OutputSchema(
      type: map['type'] as String? ?? 'object',
      properties: (map['properties'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, PropertyEntry.fromMap(value as Map<String, dynamic>))),
      required: (map['required'] as List<dynamic>? ?? []).cast<String>(),
    );
  }

  /// Creates an OutputSchema from a ToolOutput instance
  /// This analyzes the toMap() output to infer schema
  static OutputSchema fromToolOutput(ToolOutput toolOutput) {
    final map = toolOutput.toMap();
    return _inferSchemaFromMap(map);
  }

  /// Creates an OutputSchema from a ToolOutput type
  /// This creates a generic ToolOutput instance and analyzes it
  static OutputSchema? fromToolOutputType<T extends ToolOutput>() {
    try {
      // For generic ToolOutput, create an empty map instance
      if (T == ToolOutput) {
        return OutputSchema(
          properties: {
            'data': PropertyEntry(
              type: 'object',
              description: 'Generic output data',
            ),
          },
          required: [],
        );
      }
      
      // For specific subclasses, we can't easily instantiate them without parameters
      // This would need to be handled by registration or manual schema definition
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Infers schema structure from a map
  static OutputSchema _inferSchemaFromMap(Map<String, dynamic> map) {
    final properties = <String, PropertyEntry>{};
    final required = <String>[];

    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      
      properties[key] = _inferPropertyFromValue(value);
      
      // Consider non-null values as required (this is a heuristic)
      if (value != null) {
        required.add(key);
      }
    }

    return OutputSchema(
      properties: properties,
      required: required,
    );
  }

  /// Infers property type from a value
  static PropertyEntry _inferPropertyFromValue(dynamic value) {
    if (value == null) {
      return const PropertyEntry(type: 'object'); // Default for null
    }
    
    if (value is String) {
      return const PropertyEntry(type: 'string');
    }
    
    if (value is num) {
      return const PropertyEntry(type: 'number');
    }
    
    if (value is bool) {
      return const PropertyEntry(type: 'boolean');
    }
    
    if (value is List) {
      if (value.isEmpty) {
        return const PropertyEntry(
          type: 'array',
          items: PropertyEntry(type: 'object'),
        );
      }
      
      // Infer from first element
      final firstItem = value.first;
      return PropertyEntry(
        type: 'array',
        items: _inferPropertyFromValue(firstItem),
      );
    }
    
    if (value is Map<String, dynamic>) {
      final nestedProperties = <String, PropertyEntry>{};
      final nestedRequired = <String>[];
      
      for (final entry in value.entries) {
        nestedProperties[entry.key] = _inferPropertyFromValue(entry.value);
        if (entry.value != null) {
          nestedRequired.add(entry.key);
        }
      }
      
      return PropertyEntry(
        type: 'object',
        properties: nestedProperties,
        requiredProperties: nestedRequired,
      );
    }
    
    // Default for unknown types
    return const PropertyEntry(type: 'object');
  }
}