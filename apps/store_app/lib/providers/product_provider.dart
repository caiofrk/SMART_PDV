import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import '../services/database_helper.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  List<String> _categories = [];
  bool _isLoading = false;
  final int lowStockThreshold = 5; // Default threshold
  String _selectedCategory = 'Todos';

  List<String> get categories => ['Todos', ..._categories];

  List<Product> get products {
    if (_selectedCategory == 'Todos') return [..._products];
    return _products.where((p) => p.category == _selectedCategory).toList();
  }

  String get selectedCategory => _selectedCategory;

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  bool get isLoading => _isLoading;

  List<Product> get lowStockProducts =>
      _products.where((p) => p.stockQuantity <= lowStockThreshold).toList();
  bool get hasLowStock => lowStockProducts.isNotEmpty;

  Future<void> fetchAndSetProducts() async {
    _isLoading = true;
    notifyListeners();

    // Fetch both products and categories
    final results = await Future.wait([
      DatabaseHelper.instance.getAllProducts(),
      DatabaseHelper.instance.getAllCategories(),
    ]);

    _products = results[0] as List<Product>;
    _categories = results[1] as List<String>;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCategory(String name) async {
    try {
      await DatabaseHelper.instance.insertCategory(name);
      _categories.add(name);
      _categories.sort();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeCategory(String name) async {
    await DatabaseHelper.instance.deleteCategory(name);
    _categories.remove(name);
    if (_selectedCategory == name) {
      _selectedCategory = 'Todos';
    }
    notifyListeners();
  }

  Future<void> renameCategory(String oldName, String newName) async {
    await DatabaseHelper.instance.updateCategory(oldName, newName);
    final index = _categories.indexOf(oldName);
    if (index != -1) {
      _categories[index] = newName;
      _categories.sort();
      if (_selectedCategory == oldName) {
        _selectedCategory = newName;
      }
      // Also update local product list to reflect change immediately without refetch
      for (var i = 0; i < _products.length; i++) {
        if (_products[i].category == oldName) {
          _products[i] = _products[i].copyWith(category: newName);
        }
      }
      notifyListeners();
    }
  }

  Future<void> addProduct(Product product) async {
    final id = await DatabaseHelper.instance.insertProduct(product);
    final newProduct = product.copyWith(id: id);
    _products.add(newProduct);
    notifyListeners();
  }

  Future<void> updateProduct(Product product) async {
    await DatabaseHelper.instance.updateProduct(product);
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(int id) async {
    await DatabaseHelper.instance.deleteProduct(id);
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<Product?> findByBarcode(String barcode) async {
    // First check local list for speed
    try {
      return _products.firstWhere((p) => p.barcode == barcode);
    } catch (e) {
      // If not in list, check database
      return await DatabaseHelper.instance.getProductByBarcode(barcode);
    }
  }
}
