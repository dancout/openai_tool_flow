/// Abstract base class for strongly-typed tool inputs.
/// 
/// Provides type safety and validation for tool call parameters
/// while maintaining backward compatibility with Map-based interface.
abstract class ToolInput {
  /// Converts this input to a Map for tool call processing
  Map<String, dynamic> toMap();

  /// Creates a ToolInput from a Map
  /// 
  /// Subclasses should implement this factory constructor
  /// to enable deserialization from generic maps.
  static ToolInput fromMap(Map<String, dynamic> map) {
    throw UnimplementedError('Subclasses must implement fromMap');
  }

  /// Validates the input parameters
  /// 
  /// Returns a list of validation issues, empty if valid
  List<String> validate() => [];
}

/// Abstract base class for strongly-typed tool outputs.
/// 
/// Provides type safety for tool results while maintaining
/// backward compatibility with Map-based interface.
abstract class ToolOutput {
  /// Converts this output to a Map for serialization
  Map<String, dynamic> toMap();

  /// Creates a ToolOutput from a Map
  /// 
  /// Subclasses should implement this factory constructor
  /// to enable deserialization from generic maps.
  static ToolOutput fromMap(Map<String, dynamic> map) {
    throw UnimplementedError('Subclasses must implement fromMap');
  }
}

/// Registry for creating typed outputs from tool results
class ToolOutputRegistry {
  static final Map<String, ToolOutput Function(Map<String, dynamic>)> _creators = {};

  /// Registers a creator function for a specific tool
  static void register<T extends ToolOutput>(
    String toolName, 
    T Function(Map<String, dynamic>) creator,
  ) {
    _creators[toolName] = creator;
  }

  /// Creates a typed output for the given tool name and data
  static ToolOutput? create(String toolName, Map<String, dynamic> data) {
    final creator = _creators[toolName];
    return creator?.call(data);
  }

  /// Checks if a tool has a registered typed output
  static bool hasTypedOutput(String toolName) {
    return _creators.containsKey(toolName);
  }

  /// Gets all registered tool names
  static List<String> get registeredTools => _creators.keys.toList();
}

/// Example concrete implementation for palette extraction input
class PaletteExtractionInput extends ToolInput {
  final String imagePath;
  final int maxColors;
  final double minSaturation;
  final Map<String, dynamic> userPreferences;

  const PaletteExtractionInput({
    required this.imagePath,
    this.maxColors = 8,
    this.minSaturation = 0.3,
    this.userPreferences = const {},
  });

  factory PaletteExtractionInput.fromMap(Map<String, dynamic> map) {
    return PaletteExtractionInput(
      imagePath: map['imagePath'] as String,
      maxColors: map['maxColors'] as int? ?? 8,
      minSaturation: map['minSaturation'] as double? ?? 0.3,
      userPreferences: Map<String, dynamic>.from(map['userPreferences'] as Map? ?? {}),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'imagePath': imagePath,
      'maxColors': maxColors,
      'minSaturation': minSaturation,
      'userPreferences': userPreferences,
    };
  }

  @override
  List<String> validate() {
    final issues = <String>[];
    
    if (imagePath.isEmpty) {
      issues.add('imagePath cannot be empty');
    }
    
    if (maxColors <= 0) {
      issues.add('maxColors must be positive');
    }
    
    if (minSaturation < 0.0 || minSaturation > 1.0) {
      issues.add('minSaturation must be between 0.0 and 1.0');
    }
    
    return issues;
  }
}

/// Example concrete implementation for palette extraction output
class PaletteExtractionOutput extends ToolOutput {
  final List<String> colors;
  final double confidence;
  final String imageAnalyzed;
  final Map<String, dynamic> metadata;

  const PaletteExtractionOutput({
    required this.colors,
    required this.confidence,
    required this.imageAnalyzed,
    this.metadata = const {},
  });

  factory PaletteExtractionOutput.fromMap(Map<String, dynamic> map) {
    return PaletteExtractionOutput(
      colors: List<String>.from(map['colors'] as List),
      confidence: map['confidence'] as double,
      imageAnalyzed: map['image_analyzed'] as String,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'colors': colors,
      'confidence': confidence,
      'image_analyzed': imageAnalyzed,
      'metadata': metadata,
    };
  }
}

/// Example concrete implementation for color refinement input
class ColorRefinementInput extends ToolInput {
  final List<String> colors;
  final bool enhanceContrast;
  final String targetAccessibility;

  const ColorRefinementInput({
    required this.colors,
    this.enhanceContrast = true,
    this.targetAccessibility = 'AA',
  });

  factory ColorRefinementInput.fromMap(Map<String, dynamic> map) {
    return ColorRefinementInput(
      colors: List<String>.from(map['colors'] as List),
      enhanceContrast: map['enhance_contrast'] as bool? ?? true,
      targetAccessibility: map['target_accessibility'] as String? ?? 'AA',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'colors': colors,
      'enhance_contrast': enhanceContrast,
      'target_accessibility': targetAccessibility,
    };
  }

  @override
  List<String> validate() {
    final issues = <String>[];
    
    if (colors.isEmpty) {
      issues.add('colors list cannot be empty');
    }
    
    for (final color in colors) {
      if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
        issues.add('Invalid color format: $color (expected #RRGGBB)');
      }
    }
    
    if (!['A', 'AA', 'AAA'].contains(targetAccessibility)) {
      issues.add('targetAccessibility must be A, AA, or AAA');
    }
    
    return issues;
  }
}

/// Example concrete implementation for color refinement output
class ColorRefinementOutput extends ToolOutput {
  final List<String> refinedColors;
  final List<String> improvementsMade;
  final Map<String, double> accessibilityScores;

  const ColorRefinementOutput({
    required this.refinedColors,
    required this.improvementsMade,
    this.accessibilityScores = const {},
  });

  factory ColorRefinementOutput.fromMap(Map<String, dynamic> map) {
    return ColorRefinementOutput(
      refinedColors: List<String>.from(map['refined_colors'] as List),
      improvementsMade: List<String>.from(map['improvements_made'] as List),
      accessibilityScores: Map<String, double>.from(map['accessibility_scores'] as Map? ?? {}),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'refined_colors': refinedColors,
      'improvements_made': improvementsMade,
      'accessibility_scores': accessibilityScores,
    };
  }
}

/// Example concrete implementation for theme generation output
class ThemeGenerationOutput extends ToolOutput {
  final Map<String, String> theme;
  final Map<String, dynamic> metadata;

  const ThemeGenerationOutput({
    required this.theme,
    this.metadata = const {},
  });

  factory ThemeGenerationOutput.fromMap(Map<String, dynamic> map) {
    return ThemeGenerationOutput(
      theme: Map<String, String>.from(map['theme'] as Map),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'theme': theme,
      'metadata': metadata,
    };
  }
}