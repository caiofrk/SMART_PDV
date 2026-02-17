import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductLookupService {
  // Using a more general retail/community API (Produto.xyz)
  // This is better for non-food items like tobacco, drinks, and electronics.
  static const String _primaryUrl = 'https://api.produto.xyz/v1/gtin/';
  static const String _fallbackUrl =
      'https://world.openfoodfacts.org/api/v0/product/';

  /// Fetches product information from multiple sources
  /// Returns a Map with 'name' and 'category' if found, null otherwise.
  static Future<Map<String, String>?> lookupByBarcode(String barcode) async {
    // 1. Try Primary Source (Produto.xyz - Better for general/tobacco)
    try {
      final url = Uri.parse('$_primaryUrl$barcode');
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['name'] != null) {
          return {
            'name': (data['name'] as String).toUpperCase(),
            'category': _translateCategory(
              data['category_name'] ?? 'Tabacaria',
            ),
          };
        }
      }
    } catch (e) {
      print('Produto.xyz lookup failed, trying fallback...');
    }

    // 2. Try Fallback Source (Open Food Facts - Better for snacks/beverages)
    try {
      final url = Uri.parse('$_fallbackUrl$barcode.json');
      final response = await http.get(url).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final p = data['product'];
          String? name = p['product_name_pt'] ?? p['product_name'];
          if (name != null) {
            String category = 'Conveniência';
            if (p['categories_tags'] != null &&
                (p['categories_tags'] as List).isNotEmpty) {
              category = _translateTag(p['categories_tags'][0]);
            }
            return {'name': name.toUpperCase(), 'category': category};
          }
        }
      }
    } catch (e) {
      print('Secondary lookup also failed.');
    }

    return null;
  }

  static String _translateCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('tobacco') || lower.contains('cigar'))
      return 'Tabacaria';
    if (lower.contains('beverage') || lower.contains('drink')) return 'Bebidas';
    if (lower.contains('snack')) return 'Conveniência';
    return category;
  }

  static String _translateTag(String tag) {
    if (tag.contains(':')) tag = tag.split(':').last;
    final mapping = {
      'snacks': 'Conveniência',
      'beverages': 'Bebidas',
      'alcohols': 'Bebidas Alcoólicas',
      'tobacco-products': 'Tabacaria',
    };
    return mapping[tag.toLowerCase()] ??
        tag[0].toUpperCase() + tag.substring(1);
  }
}
