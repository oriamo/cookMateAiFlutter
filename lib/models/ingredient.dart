class Ingredient {
  final String id;
  final String name;
  final String? quantity;
  final String? unit;
  final String? category;
  final String? recipeId;
  final bool isPurchased;

  const Ingredient({
    required this.id,
    required this.name,
    this.quantity,
    this.unit,
    this.category,
    this.recipeId,
    this.isPurchased = false,
  });

  // Create ingredient from JSON
  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as String?,
      unit: json['unit'] as String?,
      category: json['category'] as String?,
      recipeId: json['recipeId'] as String?,
      isPurchased: json['isPurchased'] as bool? ?? false,
    );
  }

  // Convert ingredient to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'recipeId': recipeId,
      'isPurchased': isPurchased,
    };
  }

  // Create a copy of this ingredient with some fields replaced
  Ingredient copyWith({
    String? id,
    String? name,
    String? quantity,
    String? unit,
    String? category,
    String? recipeId,
    bool? isPurchased,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      recipeId: recipeId ?? this.recipeId,
      isPurchased: isPurchased ?? this.isPurchased,
    );
  }
}
