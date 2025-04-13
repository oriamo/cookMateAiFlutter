import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';

class AzureFunctionService {
  static String get _baseUrl {
    // Use 10.0.2.2 for Android emulator to access host machine's localhost
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:7071/api';
    }
    // Use localhost for other platforms
    return 'http://localhost:7071/api';
  }

  late final Dio _dio;

  AzureFunctionService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      validateStatus: (status) => status! < 500,
    ))
      ..interceptors.add(LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (object) {
            debugPrint('Dio Log: $object');
          }));
  }

  Future<Recipe> getMeal(String id) async {
    try {
      debugPrint('Fetching meal with ID: $id');
      final response = await http.get(Uri.parse('$_baseUrl/GetMeal?id=$id'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Recipe.fromJson(data);
      } else {
        debugPrint('Failed to load meal. Status code: ${response.statusCode}');
        throw Exception('Failed to load meal: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in getMeal: $e');
      if (e is DioException) {
        _handleDioError(e);
      }
      throw Exception('Failed to connect to Azure Function: $e');
    }
  }

  Future<Map<String, dynamic>> createMeal({
    required String name,
    required List<Map<String, dynamic>> ingredients,
    required List<String> instructions,
    required int cookingTime,
    required int servings,
    required String category,
    required String difficulty,
    int? calories,
  }) async {
    try {
      debugPrint('Creating new meal: $name');
      final response = await _dio.post(
        '/meals',
        data: {
          'name': name,
          'ingredients': ingredients,
          'instructions': instructions,
          'cookingTime': cookingTime,
          'servings': servings,
          'category': category,
          'difficulty': difficulty,
          'calories': calories,
        },
      );

      if (response.statusCode == 201) {
        return response.data;
      } else {
        debugPrint(
            'Failed to create meal. Status: ${response.statusCode}, Message: ${response.statusMessage}');
        throw Exception('Failed to create meal: ${response.statusMessage}');
      }
    } catch (e) {
      debugPrint('Error in createMeal: $e');
      if (e is DioException) {
        _handleDioError(e);
      }
      rethrow;
    }
  }

  void _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        debugPrint('Connection timeout: ${e.message}');
        throw Exception(
            'Connection timeout. Please check your internet connection.');
      case DioExceptionType.receiveTimeout:
        debugPrint('Receive timeout: ${e.message}');
        throw Exception(
            'Server is taking too long to respond. Please try again.');
      case DioExceptionType.connectionError:
        debugPrint('Connection error: ${e.message}');
        throw Exception(
            'Could not connect to the server. Please check your internet connection.');
      case DioExceptionType.badResponse:
        debugPrint(
            'Bad response: Status ${e.response?.statusCode}, Data: ${e.response?.data}');
        throw Exception('Server error: ${e.response?.statusMessage}');
      default:
        debugPrint('Unexpected Dio error: ${e.message}');
        throw Exception('An unexpected error occurred. Please try again.');
    }
  }
}
