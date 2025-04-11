class Category {
  final String id;
  final String name;
  final String imageUrl;
  final String description;
  final int recipeCount;

  Category({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.description,
    this.recipeCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      imageUrl: json['imageUrl'],
      description: json['description'],
      recipeCount: json['recipeCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'description': description,
      'recipeCount': recipeCount,
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? description,
    int? recipeCount,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      recipeCount: recipeCount ?? this.recipeCount,
    );
  }
}