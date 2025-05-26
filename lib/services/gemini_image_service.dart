import 'dart:convert';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiImageService {
  // Gemini Image Generation API settings
  static const String _imageModel = 'gemini-2.0-flash-preview-image-generation';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  
  // Use real Gemini image generation API
  static const bool _useMockImages = false;
  
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
    String? fallbackImageUrl, // Recipe step image URL as fallback
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
      
      // Final fallback to recipe step image if real generation fails
      if (!_useMockImages && fallbackImageUrl != null && fallbackImageUrl.isNotEmpty) {
        debugPrint('GeminiImageService: Using recipe step image as fallback: $fallbackImageUrl');
        final stepImage = await _loadImageFromUrl(fallbackImageUrl);
        if (stepImage != null) {
          debugPrint('GeminiImageService: Successfully loaded recipe step image as fallback');
          return stepImage;
        }
      }
      
      // Last resort: generate mock image
      if (!_useMockImages) {
        final mockImage = await _generateMockCookingImage(instruction);
        if (mockImage != null) {
          debugPrint('GeminiImageService: Generated mock image as last resort');
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

  /// Try to generate image using direct HTTP API call
  static Future<Uint8List?> _tryImageGeneration(String prompt) async {
    try {
      debugPrint('GeminiImageService: Trying image generation with direct HTTP API...');
      
      // Try using Google Generative AI package first (recommended approach)
      final geminiResult = await _tryGeminiPackageGeneration(prompt);
      if (geminiResult != null) {
        return geminiResult;
      }
      
      // Fall back to direct HTTP call with correct format
      debugPrint('GeminiImageService: Gemini package failed, trying direct HTTP call...');
      
      final url = '$_baseUrl/$_imageModel:generateContent?key=$_apiKey';
      
      final response = await http.post(
        Uri.parse(url),
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
            'responseModalities': ['TEXT', 'IMAGE'], // Required for image generation
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

  /// Generate image using Google Generative AI package with correct configuration
  static Future<Uint8List?> _tryGeminiPackageGeneration(String prompt) async {
    try {
      debugPrint('GeminiImageService: Using Gemini 2.0 Flash Preview Image Generation...');
      
      // Initialize the Gemini image generation model
      final model = GenerativeModel(
        model: _imageModel,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 8192,
        ),
      );
      
      // Generate content with image generation request
      // According to docs, we need to explicitly ask for image generation
      final response = await model.generateContent([
        Content.text('Generate an image: $prompt'),
      ]);
      
      debugPrint('GeminiImageService: Response received with ${response.candidates.length} candidates');
      
      if (response.candidates.isNotEmpty) {
        final candidate = response.candidates.first;
        
        if (candidate.content.parts.isNotEmpty) {
          debugPrint('GeminiImageService: Found ${candidate.content.parts.length} parts in response');
          
          for (int i = 0; i < candidate.content.parts.length; i++) {
            final part = candidate.content.parts[i];
            debugPrint('GeminiImageService: Part $i type: ${part.runtimeType}');
            
            // Check for different part types
            if (part is DataPart) {
              debugPrint('GeminiImageService: Found DataPart with mimeType: ${part.mimeType}');
              
              if (part.mimeType.startsWith('image/')) {
                debugPrint('GeminiImageService: Found image data, decoding base64...');
                return part.bytes;
              }
            } else if (part is TextPart) {
              debugPrint('GeminiImageService: Text response: ${part.text}');
            } else {
              debugPrint('GeminiImageService: Unknown part type: ${part.runtimeType}');
            }
          }
        }
      }
      
      debugPrint('GeminiImageService: No image data found in response');
      return null;
      
    } catch (e, stackTrace) {
      debugPrint('GeminiImageService: Google Generative AI package error: $e');
      debugPrint('GeminiImageService: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Build a detailed prompt for cooking image generation
  static String _buildCookingPrompt(String instruction, String recipeContext) {
    return '''Please generate an image for this cooking instruction:

Recipe: $recipeContext
Instruction: $instruction

Create a professional food photography image showing:
- The specific cooking step or technique mentioned
- Realistic food ingredients and cooking equipment
- Well-lit kitchen setting with appetizing presentation
- Clear focus on the cooking action or result

Style: High-quality food photography, professional kitchen lighting, appetizing colors and textures.''';
  }

  /// Load image from URL (for recipe step images)
  static Future<Uint8List?> _loadImageFromUrl(String imageUrl) async {
    try {
      debugPrint('GeminiImageService: Loading image from URL: $imageUrl');
      
      final response = await http.get(Uri.parse(imageUrl));
      
      if (response.statusCode == 200) {
        debugPrint('GeminiImageService: Successfully loaded image from URL, size: ${response.bodyBytes.length} bytes');
        return response.bodyBytes;
      } else {
        debugPrint('GeminiImageService: Failed to load image from URL, status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('GeminiImageService: Error loading image from URL: $e');
      return null;
    }
  }
}