class Category {
  final String id;
  final String label;
  final String icon;
  final List<String> queries;

  Category({
    required this.id,
    required this.label,
    required this.icon,
    required this.queries,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      icon: json['icon'] as String? ?? 'HelpCircle',
      queries: (json['queries'] as List?)?.cast<String>() ?? [],
    );
  }
}
