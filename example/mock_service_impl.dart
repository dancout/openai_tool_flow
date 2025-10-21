import 'package:openai_toolflow/openai_toolflow.dart';

import 'typed_interfaces.dart';

// Create a mock service for demonstration with enhanced responses for new workflow
final mockService = MockOpenAiToolService(
  responses: {
    SeedColorGenerationOutput.stepName: {
      'seed_colors': [
        '#2563EB',
        '#7C3AED',
        '#059669',
      ], // Professional blue, purple, green
      'design_style': 'modern',
      'mood': 'professional',
      'color_theory': {
        'harmony_type': 'triadic',
        'principles': ['contrast', 'balance', 'accessibility'],
        'psychological_impact': 'trustworthy and innovative',
      },
      'confidence': 0.92,
    },
    DesignSystemColorOutput.stepName: {
      'system_colors': {
        'primary': '#2563EB', // Professional blue
        'secondary': '#7C3AED', // Accent purple
        'surface': '#F8FAFC', // Light surface
        'text': '#1E293B', // Dark text
        'warning': '#F59E0B', // Amber warning
        'error': '#EF4444', // Red error
      },
      'accessibility_scores': {
        'primary': '7.2:1',
        'secondary': '6.8:1',
        'surface': '21.0:1',
        'text': '19.5:1',
        'warning': '5.9:1',
        'error': '6.1:1',
      },
      'color_harmonies': ['complementary', 'analogous', 'triadic'],
      'design_principles': {
        'contrast_ratio': 'AAA compliant',
        'color_psychology': 'trust and innovation focused',
        'brand_alignment': 'professional services',
      },
    },
    FullColorSuiteOutput.stepName: {
      'color_suite': {
        // Text colors
        'primaryText': '#1E293B',
        'secondaryText': '#475569',
        'interactiveText': '#2563EB',
        'mutedText': '#94A3B8',
        'disabledText': '#CBD5E1',

        // Background colors
        'primaryBackground': '#FFFFFF',
        'secondaryBackground': '#F8FAFC',
        'surfaceBackground': '#F1F5F9',
        'cardBackground': '#FFFFFF',
        'overlayBackground': '#1E293B80',
        'hoverBackground': '#F1F5F9',

        // Status backgrounds
        'errorBackground': '#FEF2F2',
        'warningBackground': '#FFFBEB',
        'successBackground': '#F0FDF4',
        'infoBackground': '#EFF6FF',

        // Interactive colors
        'primaryButton': '#2563EB',
        'secondaryButton': '#7C3AED',
        'disabledButton': '#94A3B8',
        'primaryLink': '#2563EB',
        'visitedLink': '#7C3AED',

        // Icon colors
        'primaryIcon': '#1E293B',
        'secondaryIcon': '#475569',
        'selectionIcon': '#2563EB',
        'errorIcon': '#EF4444',
        'successIcon': '#059669',
      },
      'brand_guidelines': {
        'primary_usage': 'Call-to-action buttons, links, key highlights',
        'secondary_usage':
            'Accent elements, secondary actions, decorative elements',
        'text_hierarchy':
            'Primary text for headings, secondary for body, muted for captions',
        'background_strategy':
            'Layered approach with subtle elevation through background variations',
      },
      'usage_recommendations': {
        'accessibility': 'All color combinations meet WCAG AA standards',
        'contrast_ratios':
            'Text colors provide minimum 4.5:1 ratio against backgrounds',
        'interactive_states':
            'Hover and focus states use darker variants for clear feedback',
        'error_handling':
            'Error colors reserved for validation and critical alerts only',
      },
    },
  },
);
