import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'azure_function_service.dart';

// Provider that creates and returns the AzureFunctionService instance
final azureFunctionServiceProvider = Provider<AzureFunctionService>((ref) {
  return AzureFunctionServiceMock();
});

// Mock implementation for demo UI purposes
class AzureFunctionServiceMock implements AzureFunctionService {
  @override
  Future<Map<String, dynamic>> getPaginatedMeals({
    String? category,
    String? searchTerm,
    String? continuationToken,
  }) async {
    // Return an empty response to force the app to use our dummy data
    return {
      'items': [],
      'categories': [],
      'continuationToken': null,
    };
  }

  @override
  Future<dynamic> callAzureFunction(String functionName, Map<String, dynamic> body,
      {bool? returnRawResponse}) async {
    // Mock implementation - returns an empty response
    return {};
  }
}