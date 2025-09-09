import 'dart:convert';

import 'package:openai_toolflow/openai_toolflow.dart';

// Strongly-typed output for feature pitch
class FeaturePitchOutput extends ToolOutput {
  final String name;
  final String tagline;
  final String valueProp;

  FeaturePitchOutput({
    required this.name,
    required this.tagline,
    required this.valueProp,
    required super.round,
  }) : super.subclass();

  @override
  Map<String, dynamic> toMap() => {
    'name': name,
    'tagline': tagline,
    'value_prop': valueProp,
    '_round': round,
  };

  factory FeaturePitchOutput.fromMap(Map<String, dynamic> map, int round) {
    return FeaturePitchOutput(
      name: map['name'] ?? '',
      tagline: map['tagline'] ?? '',
      valueProp: map['value_prop'] ?? '',
      round: round,
    );
  }
}

// Strongly-typed output for marketing plan
class MarketingPlanOutput extends ToolOutput {
  final String blogPostTitle;
  final String emailCampaignBody;
  final List<String> socialMediaPosts;

  MarketingPlanOutput({
    required this.blogPostTitle,
    required this.emailCampaignBody,
    required this.socialMediaPosts,
    required int round,
  }) : super.subclass(round: round);

  @override
  Map<String, dynamic> toMap() => {
    'blog_post_title': blogPostTitle,
    'email_campaign_body': emailCampaignBody,
    'social_media_posts': socialMediaPosts,
    '_round': round,
  };

  factory MarketingPlanOutput.fromMap(Map<String, dynamic> map, int round) {
    return MarketingPlanOutput(
      blogPostTitle: map['blog_post_title'] ?? '',
      emailCampaignBody: map['email_campaign_body'] ?? '',
      socialMediaPosts: List<String>.from(map['social_media_posts'] ?? []),
      round: round,
    );
  }
}

class FeaturePitchStepDefinition extends StepDefinition<FeaturePitchOutput> {
  @override
  FeaturePitchOutput fromMap(Map<String, dynamic> data, int round) {
    return FeaturePitchOutput.fromMap(data, round);
  }

  @override
  OutputSchema get outputSchema => OutputSchema(
    properties: [
      PropertyEntry.string(name: 'name'),
      PropertyEntry.string(name: 'tagline'),
      PropertyEntry.string(name: 'value_prop'),
    ],
  );

  @override
  String get stepName => 'generate_feature_pitch';
}

class MarketingPlanStepDefinition extends StepDefinition<MarketingPlanOutput> {
  @override
  MarketingPlanOutput fromMap(Map<String, dynamic> data, int round) {
    return MarketingPlanOutput.fromMap(data, round);
  }

  @override
  OutputSchema get outputSchema => OutputSchema(
    properties: [
      PropertyEntry.string(name: 'blog_post_title'),
      PropertyEntry.string(name: 'email_campaign_body'),
      PropertyEntry.array(
        name: 'social_media_posts',
        items: PropertyType.string,
      ),
    ],
  );

  @override
  String get stepName => 'generate_marketing_plan';
}

void main() async {
  final config = OpenAIConfig.fromDotEnv();

  final steps = [
    ToolCallStep.fromStepDefinition(FeaturePitchStepDefinition()),
    ToolCallStep.fromStepDefinition(MarketingPlanStepDefinition()),
  ];

  final toolFlow = ToolFlow(config: config, steps: steps);

  final result = await toolFlow.run(
    input: {'product_category': 'project management tool'},
  );

  final encoder = JsonEncoder.withIndent('  ');
  print('Feature Pitch:');
  // Call toMap on vanilla output directly
  print(
    'Feature Pitch: ${encoder.convert(result.finalResults[1].output.toMap())}\n',
  );

  final marketingPlan = result.finalResults[2]
      .asTyped<MarketingPlanOutput>()
      .output; // Option to strongly type output for parameter access
  print('Marketing Plan: ${encoder.convert(marketingPlan.toMap())}');
}
