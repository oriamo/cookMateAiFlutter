import 'dart:convert';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiImageService {
  // Image generation settings
  static const String _imageModelUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';
  
  // Note: Gemini image generation is not yet publicly available
  // Current status: Using enhanced mock images until real API is available
  // Set to false once real Gemini image generation becomes available
  static const bool _useMockImages = true;
  
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
      // Check if we should use mock images (while real API is unavailable)
      if (_useMockImages) {
        debugPrint('GeminiImageService: Using mock images (real Gemini image generation not yet available)');
        final mockImage = await _generateMockCookingImage(instruction);
        if (mockImage != null) {
          debugPrint('GeminiImageService: Generated enhanced mock image successfully');
          return mockImage;
        }
      }
      
      // Try real image generation (currently not available)
      final prompt = _buildCookingPrompt(instruction, recipeContext);
      debugPrint('GeminiImageService: Attempting real image generation with prompt: $prompt');
      
      final imageResult = await _tryImageGeneration(prompt);
      if (imageResult != null) {
        debugPrint('GeminiImageService: Successfully generated real image');
        return imageResult;
      }
      
      debugPrint('GeminiImageService: Real image generation failed');
      
      // Final fallback to mock if real generation fails and mock wasn't used initially
      if (!_useMockImages) {
        final mockImage = await _generateMockCookingImage(instruction);
        if (mockImage != null) {
          debugPrint('GeminiImageService: Generated mock image as fallback');
          return mockImage;
        }
      }
      
      debugPrint('GeminiImageService: All image generation methods failed');
      return null;
      
    } catch (e, stackTrace) {
      debugPrint('GeminiImageService: Error generating image: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Generate a mock image for testing (until real image generation is available)
  static Future<Uint8List?> _generateMockCookingImage(String instruction) async {
    try {
      debugPrint('GeminiImageService: Creating enhanced mock image for testing...');
      
      // Create a realistic-looking cooking image mockup
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Create gradient background
      final rect = const Rect.fromLTWH(0, 0, 400, 300);
      final gradient = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(0, 300),
        [Colors.orange.shade50, Colors.orange.shade100],
      );
      final gradientPaint = Paint()..shader = gradient;
      canvas.drawRect(rect, gradientPaint);
      
      // Draw kitchen-like background elements
      final kitchenPaint = Paint()
        ..color = Colors.brown.shade200
        ..style = PaintingStyle.fill;
      
      // Draw cutting board representation
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(50, 200, 300, 80),
          const Radius.circular(8),
        ),
        kitchenPaint,
      );
      
      // Draw cooking utensil representation
      final utensilPaint = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 3;
      canvas.drawLine(const Offset(100, 50), const Offset(120, 100), utensilPaint);
      canvas.drawCircle(const Offset(110, 45), 8, utensilPaint);
      
      // Draw food elements based on instruction keywords
      final foodPaint = Paint()..color = Colors.red.shade300;
      if (instruction.toLowerCase().contains('tomato') || 
          instruction.toLowerCase().contains('sauce')) {
        canvas.drawCircle(const Offset(200, 150), 15, foodPaint);
      }
      
      // Add "AI Generated" watermark
      final watermarkPainter = TextPainter(
        text: const TextSpan(
          text: '🤖 AI Generated Image',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      watermarkPainter.layout();
      watermarkPainter.paint(canvas, const Offset(10, 10));
      
      // Draw main instruction text
      final maxLength = 60;
      final displayText = instruction.length > maxLength 
          ? '${instruction.substring(0, maxLength)}...' 
          : instruction;
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: displayText,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      
      textPainter.layout(maxWidth: 380);
      textPainter.paint(canvas, const Offset(10, 250));
      
      // Add border for professional look
      final borderPaint = Paint()
        ..color = Colors.orange.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        borderPaint,
      );
      
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
      debugPrint('GeminiImageService: Trying image generation with Gemini 2.0 Flash Experimental...');
      
      // Try using Google Generative AI package first
      final geminiResult = await _tryGeminiPackageGeneration(prompt);
      if (geminiResult != null) {
        return geminiResult;
      }
      
      // Fall back to direct HTTP call
      debugPrint('GeminiImageService: Gemini package failed, trying direct HTTP call...');
      
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

  /// Try using Google Generative AI package for image generation
  static Future<Uint8List?> _tryGeminiPackageGeneration(String prompt) async {
    try {
      debugPrint('GeminiImageService: Trying with Google Generative AI package...');
      
      // Initialize the Gemini model
      final model = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
        apiKey: _apiKey,
      );
      
      // Try to generate content with image request
      final response = await model.generateContent([
        Content.text('Generate an image: $prompt')
      ]);
      
      debugPrint('GeminiImageService: Gemini package response: ${response.text}');
      
      // The Google Generative AI package currently doesn't support image generation
      // This will likely return text explaining that image generation isn't supported
      return null;
      
    } catch (e) {
      debugPrint('GeminiImageService: Google Generative AI package error: $e');
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