class Category {
  final String id;
  final String name;
  final String imageUrl;
  final String description;
  final bool isFeatured;

  Category({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.description = '',
    this.isFeatured = false,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      imageUrl: json['imageUrl'],
      description: json['description'] ?? '',
      isFeatured: json['isFeatured'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'description': description,
      'isFeatured': isFeatured,
    };
  }
}