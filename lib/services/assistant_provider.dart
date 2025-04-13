// lib/services/assistant_provider.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'assistant_service.dart';

/// Provider that wraps the AssistantService and exposes its functionality
/// using the ChangeNotifier pattern for state management
class AssistantProvider extends ChangeNotifier {
  final AssistantService _assistantService = AssistantService();
  bool _isInitializing = false;
  bool _isInitialized = false;
  String? _error;

  // Getters
  AssistantService get assistantService => _assistantService;
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  AssistantState get state => _assistantService.state;
  List<AssistantMessage> get messages => _assistantService.messages;
  bool get isContinuousListening => _assistantService.isContinuousListening;

  AssistantProvider() {
    _initializeAssistant();

    // Set up listeners
    _setupListeners();
  }

  /// Set up listeners for service events
  void _setupListeners() {
    // Listen for state changes
    _assistantService.onStateChange.listen((state) {
      notifyListeners();
    });

    // Listen for new messages
    _assistantService.onMessage.listen((message) {
      notifyListeners();
    });

    // Listen for errors
    _assistantService.onError.listen((error) {
      _error = error;
      notifyListeners();
    });
  }

  /// Initialize the assistant service
  Future<void> _initializeAssistant() async {
    if (_isInitializing || _isInitialized) return;

    _isInitializing = true;
    _error = null;
    notifyListeners();

    try {
      final initialized = await _assistantService.initialize();
      _isInitialized = initialized;

      if (!initialized) {
        _error = 'Failed to initialize assistant';
      }
    } catch (e) {
      _error = 'Error initializing assistant: $e';
      _isInitialized = false;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Start listening for voice commands
  Future<void> startListening({bool continuous = false}) async {
    if (!_isInitialized) {
      _error = 'Assistant not initialized';
      notifyListeners();
      return;
    }

    await _assistantService.startListening(continuous: continuous);
    notifyListeners();
  }

  /// Stop listening for voice commands
  Future<void> stopListening() async {
    await _assistantService.stopListening();
    notifyListeners();
  }

  /// Send a text message to the assistant
  Future<void> sendTextMessage(String text) async {
    if (!_isInitialized) {
      _error = 'Assistant not initialized';
      notifyListeners();
      return;
    }

    await _assistantService.sendTextMessage(text);
    notifyListeners();
  }

  /// Send a message with an image to the assistant
  Future<void> sendImageMessage(String text, Uint8List image) async {
    if (!_isInitialized) {
      _error = 'Assistant not initialized';
      notifyListeners();
      return;
    }

    await _assistantService.sendImageMessage(text, image);
    notifyListeners();
  }

  /// Capture current camera frame and analyze it
  Future<void> analyzeCurrentFrame(String prompt) async {
    if (!_isInitialized) {
      _error = 'Assistant not initialized';
      notifyListeners();
      return;
    }

    final frame = await _assistantService.videoService.captureFrame();
    if (frame != null) {
      await sendImageMessage(prompt, frame);
    } else {
      _error = 'Failed to capture camera frame';
      notifyListeners();
    }
  }

  /// Clear the message history
  void clearHistory() {
    _assistantService.clearHistory();
    notifyListeners();
  }

  /// Reset error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _assistantService.dispose();
    super.dispose();
  }
}

// Define a Riverpod provider for the AssistantProvider
final assistantProvider = ChangeNotifierProvider<AssistantProvider>((ref) {
  return AssistantProvider();
});