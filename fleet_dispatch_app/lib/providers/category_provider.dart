import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../services/category_service.dart';
import 'chat_provider.dart';

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService(ref.read(apiClientProvider));
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final service = ref.read(categoryServiceProvider);
  return service.getCategories();
});
