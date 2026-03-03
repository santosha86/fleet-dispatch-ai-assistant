import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand colors (matching web app)
  static const indigo500 = Color(0xFF6366F1);
  static const indigo600 = Color(0xFF4F46E5);
  static const indigo900 = Color(0xFF312E81);
  static const purple600 = Color(0xFF7C3AED);

  // Dark theme
  static const darkBg = Color(0xFF1A1A2E);
  static const darkBgSecondary = Color(0xFF16213E);
  static const darkSurface = Color(0xFF16213E);
  static const darkHeader = Color(0xFF0F3460);

  // Light theme
  static const lightBg = Color(0xFFF8FAFC);
  static const lightSurface = Colors.white;
  static const lightHeader = Color(0xFF1E3A5F);

  // Semantic
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // Text
  static const textPrimary = Color(0xFFE2E8F0);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  // Chart palette (matching web COLORS array)
  static const List<Color> chartColors = [
    Color(0xFF3B82F6), // blue-500
    Color(0xFF10B981), // emerald-500
    Color(0xFFF59E0B), // amber-500
    Color(0xFFEF4444), // red-500
    Color(0xFF8B5CF6), // violet-500
    Color(0xFFEC4899), // pink-500
    Color(0xFF06B6D4), // cyan-500
    Color(0xFF84CC16), // lime-500
    Color(0xFFF97316), // orange-500
    Color(0xFF6366F1), // indigo-500
  ];

  // Gradient for user message bubble
  static const userBubbleGradient = LinearGradient(
    colors: [indigo600, purple600],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Gradient for send button
  static const sendButtonGradient = LinearGradient(
    colors: [indigo600, purple600],
  );
}
