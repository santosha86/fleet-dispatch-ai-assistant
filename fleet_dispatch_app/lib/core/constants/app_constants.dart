import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // Category icons mapping (Lucide icon names → Material icons)
  static const Map<String, IconData> categoryIcons = {
    'Truck': Icons.local_shipping,
    'FileText': Icons.description,
    'Calculator': Icons.calculate,
    'BarChart': Icons.bar_chart,
    'Users': Icons.people,
    'Map': Icons.map,
    'Clock': Icons.access_time,
    'Settings': Icons.settings,
    'HelpCircle': Icons.help_outline,
    'Database': Icons.storage,
    'Search': Icons.search,
    'Activity': Icons.timeline,
    'TrendingUp': Icons.trending_up,
  };

  // Max visible rows in table before pagination
  static const int maxVisibleTableRows = 8;

  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);
}
