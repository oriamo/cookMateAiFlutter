class InstructionStep {
  final String description;
  final String imageUrl;

  InstructionStep({
    String? description,
    String? instruction,
    required this.imageUrl,
    int? stepNumber,
  })  : description = description ?? instruction!;

  /// Create an InstructionStep from JSON, supporting both 'instruction' and 'description' keys
  factory InstructionStep.fromJson(Map<String, dynamic> json) {
    return InstructionStep(
      instruction: json['instruction'] as String? ?? json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }

  /// Convert this InstructionStep to JSON
  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'imageUrl': imageUrl,
    };
  }
}
