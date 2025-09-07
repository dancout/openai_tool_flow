/// Token usage tracking for OpenAI API calls.
///
/// This class stores comprehensive token usage information for a single
/// tool call attempt, enabling granular tracking and aggregation.
class TokenUsage {
  /// Number of tokens used in the prompt/input
  final int promptTokens;

  /// Number of tokens generated in the completion/output
  final int completionTokens;

  /// Total tokens used (promptTokens + completionTokens)
  final int totalTokens;

  /// Creates a TokenUsage instance with required token counts
  const TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  /// Creates a TokenUsage with all zero values for initial input data
  /// or when token tracking is disabled
  const TokenUsage.zero()
      : promptTokens = 0,
        completionTokens = 0,
        totalTokens = 0;

  /// Creates a TokenUsage from a Map (typically from OpenAI API response)
  factory TokenUsage.fromMap(Map<String, dynamic> map) {
    final promptTokens = (map['prompt_tokens'] as int?) ?? 0;
    final completionTokens = (map['completion_tokens'] as int?) ?? 0;
    final totalTokens = (map['total_tokens'] as int?) ?? (promptTokens + completionTokens);

    return TokenUsage(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
    );
  }

  /// Converts this TokenUsage to a Map for serialization
  Map<String, dynamic> toMap() {
    return {
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'total_tokens': totalTokens,
    };
  }

  /// Creates a copy of this TokenUsage with optional field updates
  TokenUsage copyWith({
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
  }) {
    return TokenUsage(
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      totalTokens: totalTokens ?? this.totalTokens,
    );
  }

  @override
  String toString() {
    return 'TokenUsage(prompt: $promptTokens, completion: $completionTokens, total: $totalTokens)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TokenUsage &&
        other.promptTokens == promptTokens &&
        other.completionTokens == completionTokens &&
        other.totalTokens == totalTokens;
  }

  @override
  int get hashCode => Object.hash(promptTokens, completionTokens, totalTokens);
}