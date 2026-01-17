import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/database_helper.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  final int lowStockThreshold = 5; // Default threshold

  List<Product> get products => [..._products];
  bool get isLoading => _isLoading;
  
  List<Product> get lowStockProducts => _products.where((p) => p.stockQuantity <= lowStockThreshold).toList();
  bool get hasLowStock => lowStockProducts.isNotEmpty;

  Future<void> fetchAndSetProducts() async {
    _isLoading = true;
    notifyListeners();
    _products = await DatabaseHelper.instance.getAllProducts();
    _isLoading = false;
    notifyListeners();
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
