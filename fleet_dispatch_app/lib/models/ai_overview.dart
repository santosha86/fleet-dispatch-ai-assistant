class AIAssistantOverview {
  final Map<String, List<String>> processComparison;
  final List<BusinessValue> businessValue;
  final List<KeyMetric> keyMetrics;
  final List<Capability> capabilities;
  final String languageSupport;

  AIAssistantOverview({
    required this.processComparison,
    required this.businessValue,
    required this.keyMetrics,
    required this.capabilities,
    required this.languageSupport,
  });

  factory AIAssistantOverview.fromJson(Map<String, dynamic> json) {
    final procComp = json['process_comparison'] as Map<String, dynamic>?;
    final processComparison = <String, List<String>>{};
    if (procComp != null) {
      for (final entry in procComp.entries) {
        processComparison[entry.key] =
            (entry.value as List?)?.cast<String>() ?? [];
      }
    }

    return AIAssistantOverview(
      processComparison: processComparison,
      businessValue: (json['business_value'] as List?)
              ?.map((e) =>
                  BusinessValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      keyMetrics: (json['key_metrics'] as List?)
              ?.map(
                  (e) => KeyMetric.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      capabilities: (json['capabilities'] as List?)
              ?.map(
                  (e) => Capability.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      languageSupport: json['language_support'] as String? ?? '',
    );
  }
}

class BusinessValue {
  final String metric;
  final String before;
  final String after;

  BusinessValue({
    required this.metric,
    required this.before,
    required this.after,
  });

  factory BusinessValue.fromJson(Map<String, dynamic> json) {
    return BusinessValue(
      metric: json['metric'] as String? ?? '',
      before: json['before'] as String? ?? '',
      after: json['after'] as String? ?? '',
    );
  }
}

class KeyMetric {
  final String value;
  final String label;

  KeyMetric({required this.value, required this.label});

  factory KeyMetric.fromJson(Map<String, dynamic> json) {
    return KeyMetric(
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class Capability {
  final String icon;
  final String label;

  Capability({required this.icon, required this.label});

  factory Capability.fromJson(Map<String, dynamic> json) {
    return Capability(
      icon: json['icon'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}
