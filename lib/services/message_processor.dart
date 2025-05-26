// lib/services/message_processor.dart
import 'package:flutter/foundation.dart';
import 'timer_service.dart';

/// Class to process messages and detect timer requests and image generation
class MessageProcessor {
  final TimerService _timerService;
  final Function(String, String)? _onImageGenerationRequest;

  MessageProcessor(this._timerService, {Function(String, String)? onImageGenerationRequest})
      : _onImageGenerationRequest = onImageGenerationRequest;

  /// Process an AI message for timer creation and image generation
  /// Returns true if a timer was created
  Future<bool> processAIMessage(String message, [String? recipeContext]) async {
    // Check for image generation request
    _processImageGeneration(message, recipeContext ?? 'General cooking instruction');
    // Check for timer pattern
    final minutes = TimerService.extractTimerDuration(message);

    if (minutes != null) {
      debugPrint(
          '🕒 MESSAGE PROCESSOR: Detected timer request for $minutes minutes');

      // Extract label from message
      String label = 'Cooking Timer';

      // Try to find a more specific label based on context
      // First check if the message contains "for the X" or "for X" after "timer for X minutes"
      final afterMinutes = message.split('minutes').last;
      if (afterMinutes.contains('for the ') || afterMinutes.contains('for ')) {
        final forPattern = RegExp(r'for (?:the )?([\w\s]+)');
        final match = forPattern.firstMatch(afterMinutes);
        if (match != null && match.groupCount >= 1) {
          final item = match.group(1)?.trim();
          if (item != null && item.isNotEmpty) {
            label = item;
            // Capitalize first letter
            label =
                '${label.substring(0, 1).toUpperCase()}${label.substring(1)}';
          }
        }
      }

      // If we couldn't find a label after "minutes", look before the timer mention
      if (label == 'Cooking Timer') {
        final beforeTimer = message.split('timer for')[0];
        if (beforeTimer.contains('simmer') ||
            beforeTimer.contains('cook') ||
            beforeTimer.contains('bake') ||
            beforeTimer.contains('boil')) {
          // Find the cooking action
          final actions = [
            'simmer',
            'cook',
            'bake',
            'boil',
            'roast',
            'fry',
            'heat',
            'chill',
            'rest',
            'marinate'
          ];
          for (final action in actions) {
            if (beforeTimer.contains(action)) {
              // Get the action and some surrounding context
              final actionIndex = beforeTimer.indexOf(action);
              final startIndex = actionIndex > 15 ? actionIndex - 15 : 0;
              label = beforeTimer.substring(
                  startIndex, actionIndex + action.length);
              label = label.trim();
              label =
                  '${label.substring(0, 1).toUpperCase()}${label.substring(1)}';
              break;
            }
          }
        }
      }

      // Create the timer
      final timer = await _timerService.createTimer(
        label: label,
        minutes: minutes,
      );

      debugPrint(
          'Created timer: ${timer.id} - ${timer.label} for ${timer.duration.inMinutes} minutes');
      return true;
    }

    return false;
  }

  /// Process message for image generation
  void _processImageGeneration(String message, String recipeContext) {
    // Check if this looks like a cooking instruction
    final cookingKeywords = [
      'step', 'cook', 'heat', 'add', 'mix', 'stir', 'chop', 'dice', 
      'slice', 'bake', 'fry', 'boil', 'simmer', 'season', 'serve',
      'prepare', 'combine', 'blend', 'whisk', 'sauté', 'roast',
      'grill', 'steam', 'marinate', 'rest', 'cool', 'chill'
    ];
    
    final lowerMessage = message.toLowerCase();
    final isCookingInstruction = cookingKeywords.any((keyword) => 
      lowerMessage.contains(keyword)
    );
    
    if (isCookingInstruction && message.length > 10) {
      debugPrint('🖼️ MESSAGE PROCESSOR: Detected cooking instruction for image generation: "${message.substring(0, message.length > 50 ? 50 : message.length)}..."');
      
      // Call the image generation callback
      _onImageGenerationRequest?.call(message, recipeContext);
    }
  }
}
