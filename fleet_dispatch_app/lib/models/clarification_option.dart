class ClarificationOption {
  final String route;
  final String label;

  ClarificationOption({required this.route, required this.label});

  factory ClarificationOption.fromJson(Map<String, dynamic> json) {
    return ClarificationOption(
      route: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}
