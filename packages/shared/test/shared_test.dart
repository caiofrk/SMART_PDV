import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  test('Product model parses camelCase and snake_case maps', () {
    final camelMap = {
      'id': 1,
      'name': 'Cigarro',
      'barcode': '789123',
      'price': 10.5,
      'stockQuantity': 20,
      'imagePath': 'local/path.jpg',
      'category': 'Outros',
    };
    final p1 = Product.fromMap(camelMap);
    expect(p1.stockQuantity, 20);
    expect(p1.imagePath, 'local/path.jpg');
    expect(p1.price, 10.5);

    final snakeMap = {
      'id': '2',
      'name': 'Isqueiro',
      'barcode': '456789',
      'price': '5.0',
      'stock_quantity': '15',
      'image_path': 'https://cloud.com/img.png',
      'category': 'Isqueiros',
    };
    final p2 = Product.fromMap(snakeMap);
    expect(p2.id, 2);
    expect(p2.stockQuantity, 15);
    expect(p2.imagePath, 'https://cloud.com/img.png');
    expect(p2.price, 5.0);
  });
}
