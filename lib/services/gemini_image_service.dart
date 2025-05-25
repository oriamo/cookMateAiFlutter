import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiImageService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-preview-image-generation:generateContent';
  
  static String get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in environment variables');
    }
    return key;
  }

  /// Generate an image based on cooking instruction and recipe context
  static Future<Uint8List?> generateCookingImage({
    required String instruction,
    required String recipeContext,
  }) async {
    try {
      // Create a detailed prompt for cooking image generation
      final prompt = _buildCookingPrompt(instruction, recipeContext);
      
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': prompt,
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 32,
            'topP': 1,
            'maxOutputTokens': 4096,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Extract base64 image data from response
        if (data['candidates'] != null && 
            data['candidates'].isNotEmpty && 
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          
          final parts = data['candidates'][0]['content']['parts'];
          
          // Look for inline_data with image
          for (final part in parts) {
            if (part['inline_data'] != null && 
                part['inline_data']['mime_type'] != null &&
                part['inline_data']['mime_type'].toString().startsWith('image/')) {
              
              final base64Data = part['inline_data']['data'];
              if (base64Data != null) {
                return base64Decode(base64Data);
              }
            }
          }
        }
        
        debugPrint('GeminiImageService: No image data found in response');
        return null;
      } else {
        debugPrint('GeminiImageService: HTTP error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('GeminiImageService: Error generating image: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Build a detailed prompt for cooking image generation
  static String _buildCookingPrompt(String instruction, String recipeContext) {
    return '''
Generate a high-quality, photorealistic cooking image for the following instruction:

Recipe Context: $recipeContext

Current Instruction: $instruction

Please create an image that shows:
1. The specific cooking step or technique mentioned in the instruction
2. Realistic food items and cooking equipment relevant to the recipe
3. Professional kitchen lighting and composition
4. Clean, appetizing presentation
5. Focus on the action or result described in the instruction

Style: Professional food photography, well-lit, appetizing, realistic textures and colors.
Format: High resolution, suitable for mobile display.
Perspective: Close-up or medium shot that clearly shows the cooking process.
''';
  }
}