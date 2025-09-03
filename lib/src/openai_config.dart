import 'dart:io';

/// Configuration for OpenAI API access and defaults.
///
/// Can load API key and defaults from environment variables or be configured programmatically.
class OpenAIConfig {
  /// OpenAI API key
  final String apiKey;

  /// Default model to use when not specified in a step
  final String defaultModel;

  /// Default temperature for model calls
  final double? defaultTemperature;

  /// Default max tokens for model calls
  final int? defaultMaxTokens;

  /// Base URL for OpenAI API (useful for proxies or alternative endpoints)
  final String baseUrl;

  /// Creates an OpenAIConfig with explicit values
  const OpenAIConfig({
    required this.apiKey,
    this.defaultModel = 'gpt-4',
    this.defaultTemperature,
    this.defaultMaxTokens,
    required this.baseUrl,
  });

  /// Creates an OpenAIConfig from environment variables
  ///
  /// Looks for the following environment variables:
  /// - OPENAI_API_KEY (required)
  /// - OPENAI_DEFAULT_MODEL (optional, defaults to 'gpt-4')
  /// - OPENAI_DEFAULT_TEMPERATURE (optional)
  /// - OPENAI_DEFAULT_MAX_TOKENS (optional)
  /// - OPENAI_BASE_URL (optional, defaults to 'https://api.openai.com/v1')
  factory OpenAIConfig.fromEnvironment() {
    final apiKey = Platform.environment['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw ArgumentError('OPENAI_API_KEY environment variable is required');
    }

    final defaultModel =
        Platform.environment['OPENAI_DEFAULT_MODEL'] ?? 'gpt-4';
    final baseUrl =
        Platform.environment['OPENAI_BASE_URL'] ?? 'https://api.openai.com/v1';

    final temperatureString =
        Platform.environment['OPENAI_DEFAULT_TEMPERATURE'];
    final double? defaultTemperature = temperatureString != null
        ? double.tryParse(temperatureString)
        : null;

    final maxTokensString = Platform.environment['OPENAI_DEFAULT_MAX_TOKENS'];
    final int? defaultMaxTokens = maxTokensString != null
        ? int.tryParse(maxTokensString)
        : null;

    return OpenAIConfig(
      apiKey: apiKey,
      defaultModel: defaultModel,
      defaultTemperature: defaultTemperature,
      defaultMaxTokens: defaultMaxTokens,
      baseUrl: baseUrl,
    );
  }

  /// Creates an OpenAIConfig from a .env file
  ///
  /// This is a simplified implementation that reads key=value pairs from a .env file.
  /// In a real implementation, you might want to use a package like 'dotenv'.
  factory OpenAIConfig.fromDotEnv([String filePath = '.env']) {
    final envVars = <String, String>{};

    try {
      final file = File(filePath);
      if (file.existsSync()) {
        final lines = file.readAsLinesSync();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
            final parts = trimmed.split('=');
            if (parts.length >= 2) {
              final key = parts[0].trim();
              final value = parts.sublist(1).join('=').trim();
              // Remove quotes if present
              var cleanValue = value;
              if ((cleanValue.startsWith('"') && cleanValue.endsWith('"')) ||
                  (cleanValue.startsWith("'") && cleanValue.endsWith("'"))) {
                cleanValue = cleanValue.substring(1, cleanValue.length - 1);
              }
              envVars[key] = cleanValue;
            }
          }
        }
      }
    } catch (e) {
      // If we can't read the .env file, we'll just use environment variables
    }

    // Merge with actual environment variables (env vars take precedence)
    final mergedEnv = {...envVars, ...Platform.environment};

    final apiKey = mergedEnv['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw ArgumentError(
        'OPENAI_API_KEY not found in .env file or environment variables',
      );
    }

    final defaultModel = mergedEnv['OPENAI_DEFAULT_MODEL'] ?? 'gpt-4';
    final baseUrl = mergedEnv['OPENAI_BASE_URL'] ?? 'https://api.openai.com/v1';

    final temperatureString = mergedEnv['OPENAI_DEFAULT_TEMPERATURE'];
    final double? defaultTemperature = temperatureString != null
        ? double.tryParse(temperatureString)
        : null;

    final maxTokensString = mergedEnv['OPENAI_DEFAULT_MAX_TOKENS'];
    final int? defaultMaxTokens = maxTokensString != null
        ? int.tryParse(maxTokensString)
        : null;

    return OpenAIConfig(
      apiKey: apiKey,
      defaultModel: defaultModel,
      defaultTemperature: defaultTemperature,
      defaultMaxTokens: defaultMaxTokens,
      baseUrl: baseUrl,
    );
  }

  /// Creates a copy of this config with updated values
  OpenAIConfig copyWith({
    String? apiKey,
    String? defaultModel,
    double? defaultTemperature,
    int? defaultMaxTokens,
    String? baseUrl,
  }) {
    return OpenAIConfig(
      apiKey: apiKey ?? this.apiKey,
      defaultModel: defaultModel ?? this.defaultModel,
      defaultTemperature: defaultTemperature ?? this.defaultTemperature,
      defaultMaxTokens: defaultMaxTokens ?? this.defaultMaxTokens,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }

  /// Converts this config to a JSON map (excluding the API key for security)
  Map<String, dynamic> toJson() {
    return {
      'defaultModel': defaultModel,
      'defaultTemperature': defaultTemperature,
      'defaultMaxTokens': defaultMaxTokens,
      'baseUrl': baseUrl,
    };
  }

  @override
  String toString() {
    return 'OpenAIConfig(defaultModel: $defaultModel, baseUrl: $baseUrl)';
  }
}
