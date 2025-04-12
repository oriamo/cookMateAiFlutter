import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';

class AzureFunctionService {
  static const String baseUrl = 'http://localhost:7071/api';

  Future<Recipe> getMeal(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/GetMeal?id=$id'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Recipe.fromJson(data);
      } else {
        throw Exception('Failed to load meal: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to Azure Function: $e');
    }
  }
}
