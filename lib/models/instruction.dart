class SubStep {
  final String description;
  final String? timing; // Optional timing like "1-2 minutes"

  SubStep({
    required this.description,
    this.timing,
  });

  factory SubStep.fromJson(Map<String, dynamic> json) {
    return SubStep(
      description: json['description'] as String,
      timing: json['timing'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      if (timing != null) 'timing': timing,
    };
  }
}

class InstructionStep {
  final String description;
  final String imageUrl;
  final List<SubStep> subSteps;

  InstructionStep({
    String? description,
    String? instruction,
    required this.imageUrl,
    int? stepNumber,
    List<SubStep>? subSteps,
  })  : description = description ?? instruction!,
        subSteps = subSteps ?? [];

  /// Create an InstructionStep from JSON, supporting both 'instruction' and 'description' keys
  factory InstructionStep.fromJson(Map<String, dynamic> json) {
    return InstructionStep(
      instruction: json['instruction'] as String? ?? json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      subSteps: (json['subSteps'] as List<dynamic>?)
          ?.map((step) => SubStep.fromJson(Map<String, dynamic>.from(step)))
          .toList() ?? [],
    );
  }

  /// Convert this InstructionStep to JSON
  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'imageUrl': imageUrl,
      if (subSteps.isNotEmpty) 'subSteps': subSteps.map((step) => step.toJson()).toList(),
    };
  }
}
