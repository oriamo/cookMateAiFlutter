// lib/services/cooking_session_service.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../models/instruction.dart';
import 'timer_service.dart';
import 'deepgram_agent_provider.dart';

/// Manages the cooking session state and step-by-step guidance
class CookingSession {
  final Recipe recipe;
  final DateTime startTime;
  int currentStepIndex;
  int currentSubStepIndex;
  bool isActive;
  List<String> completedTimers;
  Map<String, String> activeTimers;

  CookingSession({
    required this.recipe,
    this.currentStepIndex = 0,
    this.currentSubStepIndex = 0,
    this.isActive = true,
  }) : startTime = DateTime.now(),
       completedTimers = [],
       activeTimers = {};

  InstructionStep? get currentStep {
    if (currentStepIndex >= recipe.instructions.length) return null;
    return recipe.instructions[currentStepIndex];
  }

  SubStep? get currentSubStep {
    final step = currentStep;
    if (step == null || step.subSteps.isEmpty) return null;
    if (currentSubStepIndex >= step.subSteps.length) return null;
    return step.subSteps[currentSubStepIndex];
  }

  bool get hasSubSteps {
    return currentStep?.subSteps.isNotEmpty ?? false;
  }

  bool get isOnMainStep {
    return !hasSubSteps || currentSubStepIndex == 0;
  }

  bool get isStepComplete {
    final step = currentStep;
    if (step == null) return true;
    if (step.subSteps.isEmpty) return false;
    return currentSubStepIndex >= step.subSteps.length;
  }

  bool get isSessionComplete {
    return currentStepIndex >= recipe.instructions.length;
  }

  void nextSubStep() {
    final step = currentStep;
    if (step != null && currentSubStepIndex < step.subSteps.length - 1) {
      currentSubStepIndex++;
    } else {
      nextStep();
    }
  }

  void nextStep() {
    if (currentStepIndex < recipe.instructions.length - 1) {
      currentStepIndex++;
      currentSubStepIndex = 0;
    } else {
      isActive = false;
    }
  }

  void previousStep() {
    if (currentStepIndex > 0) {
      currentStepIndex--;
      currentSubStepIndex = 0;
    }
  }

  String getCurrentStepText() {
    final step = currentStep;
    if (step == null) return "Cooking complete!";
    
    if (hasSubSteps) {
      final subStep = currentSubStep;
      if (subStep != null) {
        return subStep.description;
      }
    }
    
    return step.description;
  }

  String getCurrentStepNumber() {
    if (hasSubSteps) {
      return "Step ${currentStepIndex + 1}.${currentSubStepIndex + 1}";
    }
    return "Step ${currentStepIndex + 1}";
  }
}

/// Service to manage cooking sessions
class CookingSessionService extends StateNotifier<CookingSession?> {
  final TimerService _timerService;
  final DeepgramAgentProvider _voiceAgent;
  
  CookingSessionService(this._timerService, this._voiceAgent) : super(null);

  /// Start a new cooking session
  Future<void> startCookingSession(Recipe recipe) async {
    // Start Deepgram voice connection before sending context
    await _voiceAgent.startConversation();
    // Initialize session state
    final session = CookingSession(recipe: recipe);
    state = session;

    // Configure voice agent with full recipe context
    await _configureVoiceAgentForCooking(recipe);

    // Speak the initial greeting
    await _speakGreeting(recipe);
    
    // Guide through the first step (current step in session)
    await _guideCurrentStep();
  }

  /// Configure the voice agent with cooking context
  Future<void> _configureVoiceAgentForCooking(Recipe recipe) async {
    final context = _buildCookingContext(recipe);
    
    // Set the agent context (this will depend on your voice agent implementation)
    // For now, we'll assume there's a method to set context
    _voiceAgent.setSystemContext(context);
  }

  /// Build cooking context for the voice agent
  String _buildCookingContext(Recipe recipe) {
    final buffer = StringBuffer();
    buffer.writeln("You are a cooking assistant helping the user prepare ${recipe.title}.");
    buffer.writeln("Recipe description: ${recipe.description}");
    buffer.writeln("Total cooking time: ${recipe.totalTimeMinutes} minutes");
    buffer.writeln("Serves: ${recipe.servings} people");
    buffer.writeln("Difficulty: ${recipe.difficulty}");
    buffer.writeln("");
    
    buffer.writeln("INGREDIENTS:");
    for (final ingredient in recipe.ingredients) {
      final name = ingredient['name'] ?? '';
      final amount = ingredient['amount'] ?? '';
      final unit = ingredient['unit'] ?? '';
      buffer.writeln("- $amount $unit $name");
    }
    buffer.writeln("");
    
    buffer.writeln("INSTRUCTIONS:");
    for (int i = 0; i < recipe.instructions.length; i++) {
      final step = recipe.instructions[i];
      buffer.writeln("Step ${i + 1}: ${step.description}");
      
      if (step.subSteps.isNotEmpty) {
        for (int j = 0; j < step.subSteps.length; j++) {
          final subStep = step.subSteps[j];
          buffer.write("  ${i + 1}.${j + 1}: ${subStep.description}");
          if (subStep.timing != null) {
            buffer.write(" (${subStep.timing})");
          }
          buffer.writeln();
        }
      }
      buffer.writeln();
    }
    
    buffer.writeln("Your role:");
    buffer.writeln("- Guide the user step by step through the recipe");
    buffer.writeln("- Create timers when timing information is provided");
    buffer.writeln("- Be encouraging and helpful");
    buffer.writeln("- Ask if they're ready before moving to the next step");
    buffer.writeln("- If they ask to repeat a step, provide the current step information");
    buffer.writeln("- If they ask for the next step, move to the next instruction");
    buffer.writeln("- If they need help with timing, create appropriate timers");
    
    return buffer.toString();
  }

  /// Speak the initial greeting
  Future<void> _speakGreeting(Recipe recipe) async {
    final greeting = "Let's get started cooking ${recipe.title}! "
        "This recipe serves ${recipe.servings} people and should take about ${recipe.totalTimeMinutes} minutes. "
        "I'll guide you through each step. Are you ready to begin?";
    
    await _voiceAgent.speak(greeting);
  }

  /// Guide through the current step
  Future<void> _guideCurrentStep() async {
    final session = state;
    if (session == null || !session.isActive) return;
    
    final step = session.currentStep;
    if (step == null) {
      await _speakCompletion();
      return;
    }
    
    String guidance;
    if (session.hasSubSteps) {
      final subStep = session.currentSubStep;
      if (subStep != null) {
        guidance = "${session.getCurrentStepNumber()}: ${subStep.description}";
        
        // Create timer if timing information is available
        if (subStep.timing != null) {
          await _createTimerForSubStep(subStep);
        }
      } else {
        guidance = "Step ${session.currentStepIndex + 1} is complete. Ready for the next step?";
      }
    } else {
      guidance = "${session.getCurrentStepNumber()}: ${step.description}";
    }
    
    await _voiceAgent.speak(guidance);
  }

  /// Create a timer for a sub-step with timing information
  Future<void> _createTimerForSubStep(SubStep subStep) async {
    final timing = subStep.timing;
    if (timing == null) return;
    
    // Parse timing information (e.g., "1-2 minutes", "30 seconds", "about 5 minutes")
    final duration = _parseTimingDuration(timing);
    if (duration != null) {
      final timerId = await _timerService.startTimer(
        label: subStep.description,
        duration: duration,
      );
      
      // Store timer ID in session
      final session = state;
      if (session != null) {
        session.activeTimers[subStep.description] = timerId;
        state = CookingSession(
          recipe: session.recipe,
          currentStepIndex: session.currentStepIndex,
          currentSubStepIndex: session.currentSubStepIndex,
          isActive: session.isActive,
        )..activeTimers = session.activeTimers
         ..completedTimers = session.completedTimers;
      }
      
      await _voiceAgent.speak("I've started a ${timing} timer for this step.");
    }
  }

  /// Parse timing duration from text
  Duration? _parseTimingDuration(String timing) {
    final lowerTiming = timing.toLowerCase();
    
    // Match patterns like "1-2 minutes", "30 seconds", "about 5 minutes"
    final minutePatterns = [
      RegExp(r'(\d+)(?:\s*-\s*\d+)?\s*minutes?'),
      RegExp(r'about\s+(\d+)\s*minutes?'),
      RegExp(r'roughly\s+(\d+)\s*minutes?'),
    ];
    
    final secondPatterns = [
      RegExp(r'(\d+)(?:\s*-\s*\d+)?\s*seconds?'),
      RegExp(r'about\s+(\d+)\s*seconds?'),
    ];
    
    // Try to match minutes
    for (final pattern in minutePatterns) {
      final match = pattern.firstMatch(lowerTiming);
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '');
        if (minutes != null) {
          return Duration(minutes: minutes);
        }
      }
    }
    
    // Try to match seconds
    for (final pattern in secondPatterns) {
      final match = pattern.firstMatch(lowerTiming);
      if (match != null) {
        final seconds = int.tryParse(match.group(1) ?? '');
        if (seconds != null) {
          return Duration(seconds: seconds);
        }
      }
    }
    
    return null;
  }

  /// Move to next step/sub-step
  Future<void> nextStep() async {
    final session = state;
    if (session == null || !session.isActive) return;
    
    session.nextSubStep();
    state = CookingSession(
      recipe: session.recipe,
      currentStepIndex: session.currentStepIndex,
      currentSubStepIndex: session.currentSubStepIndex,
      isActive: session.isActive,
    )..activeTimers = session.activeTimers
     ..completedTimers = session.completedTimers;
    
    await _guideCurrentStep();
  }

  /// Move to previous step
  Future<void> previousStep() async {
    final session = state;
    if (session == null) return;
    
    session.previousStep();
    state = CookingSession(
      recipe: session.recipe,
      currentStepIndex: session.currentStepIndex,
      currentSubStepIndex: session.currentSubStepIndex,
      isActive: session.isActive,
    )..activeTimers = session.activeTimers
     ..completedTimers = session.completedTimers;
    
    await _guideCurrentStep();
  }

  /// Repeat current step
  Future<void> repeatCurrentStep() async {
    await _guideCurrentStep();
  }

  /// Jump to a specific main step index (1-based) and reset sub-step
  Future<void> goToStep(int stepNumber) async {
    final session = state;
    if (session == null || !session.isActive) return;
    final idx = stepNumber - 1;
    if (idx < 0 || idx >= session.recipe.instructions.length) return;
    session.currentStepIndex = idx;
    session.currentSubStepIndex = 0;
    state = CookingSession(
      recipe: session.recipe,
      currentStepIndex: session.currentStepIndex,
      currentSubStepIndex: session.currentSubStepIndex,
      isActive: session.isActive,
    )..activeTimers = session.activeTimers
     ..completedTimers = session.completedTimers;
    await _guideCurrentStep();
  }

  /// Speak completion message
  Future<void> _speakCompletion() async {
    final session = state;
    if (session == null) return;
    
    final completion = "Congratulations! You've successfully completed ${session.recipe.title}. "
        "Your delicious meal is ready to serve. Enjoy!";
    
    await _voiceAgent.speak(completion);
  }

  /// End the cooking session
  void endCookingSession() {
    final session = state;
    if (session != null) {
      // Cancel any active timers
      for (final timerId in session.activeTimers.values) {
        _timerService.cancelTimer(timerId);
      }
    }
    
    state = null;
  }

  /// Get current cooking status for display
  String getCurrentStatus() {
    final session = state;
    if (session == null) return "No active cooking session";
    if (session.isSessionComplete) return "Cooking complete!";
    
    return "${session.getCurrentStepNumber()}: ${session.getCurrentStepText()}";
  }
}

/// Provider for cooking session service
final cookingSessionProvider = StateNotifierProvider<CookingSessionService, CookingSession?>((ref) {
  final timerService = TimerService();
  final voiceAgent = ref.read(deepgramAgentProvider);
  return CookingSessionService(timerService, voiceAgent);
});
