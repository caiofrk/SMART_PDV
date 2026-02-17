import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductLookupService {
  static const String _baseUrl =
      'https://world.openfoodfacts.org/api/v0/product/';

  /// Fetches product information from Open Food Facts API
  /// Returns a Map with 'name' and 'category' if found, null otherwise.
  static Future<Map<String, String>?> lookupByBarcode(String barcode) async {
    try {
      final url = Uri.parse('$_baseUrl$barcode.json');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'];

          String? name = product['product_name_pt'] ?? product['product_name'];
          String? category =
              product['categories_tags'] != null &&
                  (product['categories_tags'] as List).isNotEmpty
              ? _formatCategory(product['categories_tags'][0])
              : 'Outros';

          if (name != null) {
            return {'name': name.toUpperCase(), 'category': category};
          }
        }
      }
    } catch (e) {
      print('Error looking up barcode: $e');
    }
    return null;
  }

  static String _formatCategory(String tag) {
    // Remove language prefix (e.g., 'en:snacks' -> 'Snacks')
    if (tag.contains(':')) {
      tag = tag.split(':').last;
    }
    // Simple mapping for Portuguese
    final mapping = {
      'snacks': 'Petiscos',
      'beverages': 'Bebidas',
      'sugary-snacks': 'Doces',
      'chocolates': 'Chocolates',
      'soft-drinks': 'Refrigerantes',
      'alcohols': 'Bebidas Alcoólicas',
    };

    return mapping[tag.toLowerCase()] ??
        tag[0].toUpperCase() + tag.substring(1);
  }
}
