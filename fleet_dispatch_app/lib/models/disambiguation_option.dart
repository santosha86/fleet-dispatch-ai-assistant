class DisambiguationOption {
  final String value;
  final String? label;

  DisambiguationOption({required this.value, this.label});

  factory DisambiguationOption.fromJson(dynamic json) {
    if (json is String) {
      return DisambiguationOption(value: json);
    }
    if (json is Map<String, dynamic>) {
      return DisambiguationOption(
        value: json['value'] as String? ?? '',
        label: json['display'] as String?,
      );
    }
    return DisambiguationOption(value: json.toString());
  }

  String get displayText => label ?? value;
}
