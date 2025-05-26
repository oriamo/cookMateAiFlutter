import 'dart:convert';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

class GeminiImageService {
  // Try the newer Gemini 2.0 Flash model first
  static const String _imageModelUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';
  
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
    debugPrint('GeminiImageService: Starting image generation...');
    debugPrint('GeminiImageService: API Key present: ${_apiKey.isNotEmpty}');
    debugPrint('GeminiImageService: Instruction: "$instruction"');
    debugPrint('GeminiImageService: Recipe context: "$recipeContext"');
    
    try {
      // For now, let's create a mock image to test the UI
      // This will help us debug the display system
      final mockImage = await _generateMockCookingImage(instruction);
      if (mockImage != null) {
        debugPrint('GeminiImageService: Generated mock image successfully');
        return mockImage;
      }
      
      // Create a detailed prompt for cooking image generation
      final prompt = _buildCookingPrompt(instruction, recipeContext);
      debugPrint('GeminiImageService: Generated prompt: $prompt');
      
      // Try the image generation model first
      final imageResult = await _tryImageGeneration(prompt);
      if (imageResult != null) {
        return imageResult;
      }
      
      // If image generation fails, try text-only response (fallback)
      debugPrint('GeminiImageService: Image generation failed, falling back to text response');
      return null;
      
    } catch (e, stackTrace) {
      debugPrint('GeminiImageService: Error generating image: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Generate a mock image for testing
  static Future<Uint8List?> _generateMockCookingImage(String instruction) async {
    try {
      debugPrint('GeminiImageService: Creating mock image for testing...');
      
      // Create a simple colored image with text
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = Colors.orange.shade100;
      
      // Draw background
      canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 300), paint);
      
      // Draw border
      final borderPaint = Paint()
        ..color = Colors.orange.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 300), borderPaint);
      
      // Draw text
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Generated Image\n\n${instruction.length > 50 ? "${instruction.substring(0, 50)}..." : instruction}',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      
      textPainter.layout(maxWidth: 360);
      textPainter.paint(canvas, const Offset(20, 100));
      
      // Draw cooking icon
      final iconPaint = Paint()..color = Colors.orange.shade600;
      canvas.drawCircle(const Offset(200, 50), 20, iconPaint);
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 300);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
      
      return null;
    } catch (e) {
      debugPrint('GeminiImageService: Error creating mock image: $e');
      return null;
    }
  }

  /// Try to generate image using Gemini 2.0 Flash experimental model
  static Future<Uint8List?> _tryImageGeneration(String prompt) async {
    try {
      debugPrint('GeminiImageService: Trying image generation with prompt...');
      
      final response = await http.post(
        Uri.parse('$_imageModelUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': 'Generate an image: $prompt',
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 8192,
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

      debugPrint('GeminiImageService: Response status code: ${response.statusCode}');
      debugPrint('GeminiImageService: Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        debugPrint('GeminiImageService: Parsed response data: $data');
        
        // Extract base64 image data from response
        if (data['candidates'] != null && 
            data['candidates'].isNotEmpty && 
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          
          final parts = data['candidates'][0]['content']['parts'];
          debugPrint('GeminiImageService: Found ${parts.length} parts in response');
          
          // Look for inline_data with image
          for (int i = 0; i < parts.length; i++) {
            final part = parts[i];
            debugPrint('GeminiImageService: Part $i: ${part.keys}');
            
            if (part['inline_data'] != null && 
                part['inline_data']['mime_type'] != null &&
                part['inline_data']['mime_type'].toString().startsWith('image/')) {
              
              final base64Data = part['inline_data']['data'];
              if (base64Data != null) {
                debugPrint('GeminiImageService: Found image data of length: ${base64Data.length}');
                return base64Decode(base64Data);
              }
            }
          }
        }
        
        debugPrint('GeminiImageService: No image data found in response structure');
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