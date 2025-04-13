import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'azure_function_service.dart';

final azureFunctionServiceProvider = Provider<AzureFunctionService>((ref) {
  return AzureFunctionService();
});
