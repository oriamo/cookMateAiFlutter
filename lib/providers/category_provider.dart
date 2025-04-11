import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';

// Sample categories for initial state
final sampleCategories = [
  Category(
    id: 'category-1',
    name: 'Italian',
    imageUrl: 'https://images.unsplash.com/photo-1546549032-9571cd6b27df?q=80&w=1000',
    description: 'Delicious pasta, pizza, and other Italian classics',
    isFeatured: true,
  ),
  Category(
    id: 'category-2',
    name: 'Asian',
    imageUrl: 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?q=80&w=1000',
    description: 'Flavorful dishes from across Asia',
    isFeatured: true,
  ),
  Category(
    id: 'category-3',
    name: 'Vegetarian',
    imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?q=80&w=1000',
    description: 'Meat-free recipes packed with flavor',
    isFeatured: true,
  ),
  Category(
    id: 'category-4',
    name: 'Quick Meals',
    imageUrl: 'https://images.unsplash.com/photo-1577308856961-8e9ec64d4b9a?q=80&w=1000',
    description: 'Recipes ready in 30 minutes or less',
    isFeatured: true,
  ),
  Category(
    id: 'category-5',
    name: 'Breakfast',
    imageUrl: 'https://images.unsplash.com/photo-1533089860892-a9c9970fab1f?q=80&w=1000',
    description: 'Start your day with these delicious breakfast recipes',
    isFeatured: false,
  ),
  Category(
    id: 'category-6',
    name: 'Mediterranean',
    imageUrl: 'https://images.unsplash.com/photo-1576866209830-589e1bfbaa4d?q=80&w=1000',
    description: 'Healthy and flavorful Mediterranean dishes',
    isFeatured: false,
  ),
  Category(
    id: 'category-7',
    name: 'Desserts',
    imageUrl: 'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?q=80&w=1000',
    description: 'Sweet treats for any occasion',
    isFeatured: false,
  ),
  Category(
    id: 'category-8',
    name: 'Healthy',
    imageUrl: 'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?q=80&w=1000',
    description: 'Nutritious recipes for a balanced diet',
    isFeatured: true,
  ),
];

// State notifier to manage the categories
class CategoryNotifier extends StateNotifier<List<Category>> {
  CategoryNotifier() : super(sampleCategories);

  void addCategory(Category category) {
    state = [...state, category];
  }

  void updateCategory(Category category) {
    state = state.map((c) => c.id == category.id ? category : c).toList();
  }

  void deleteCategory(String id) {
    state = state.where((c) => c.id != id).toList();
  }
  
  List<Category> getFeaturedCategories() {
    return state.where((c) => c.isFeatured).toList();
  }
}

// Categories provider
final categoriesProvider = StateNotifierProvider<CategoryNotifier, List<Category>>((ref) {
  return CategoryNotifier();
});

// Featured categories provider
final featuredCategoriesProvider = Provider<List<Category>>((ref) {
  final categoryNotifier = ref.watch(categoriesProvider.notifier);
  return categoryNotifier.getFeaturedCategories();
});