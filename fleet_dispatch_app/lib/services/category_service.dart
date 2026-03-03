import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/category.dart';

class CategoryService {
  final ApiClient _apiClient;

  CategoryService(this._apiClient);

  /// Fetch all categories
  Future<List<Category>> getCategories() async {
    final response = await _apiClient.get(ApiEndpoints.categories);
    return (response.data as List)
        .map((json) => Category.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch queries for a specific category
  Future<List<String>> getCategoryQueries(String categoryId) async {
    final response = await _apiClient.get(
      ApiEndpoints.categoryQueries(categoryId),
    );
    return List<String>.from(response.data as List);
  }
}
