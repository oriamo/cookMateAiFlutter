// lib/services/deepgram_agent_types.dart

/// States for the Deepgram Voice Agent
enum DeepgramAgentState {
  /// Agent is idle, not connected or listening
  idle,
  
  /// Agent is connecting to the Deepgram API
  connecting,
  
  /// Agent is connected but not actively listening/processing
  connected,
  
  /// Agent is actively listening for user speech
  listening,
  
  /// Agent is processing user input
  processing,
  
  /// Agent is speaking (audio playback is active)
  speaking,
}

/// Interface for the Deepgram Voice Agent API responses
class DeepgramResponse {
  final String type;
  final Map<String, dynamic> data;
  
  DeepgramResponse({required this.type, required this.data});
  
  factory DeepgramResponse.fromJson(Map<String, dynamic> json) {
    return DeepgramResponse(
      type: json['type'] as String,
      data: json,
    );
  }
}