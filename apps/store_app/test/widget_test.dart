import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  test('Product model serialization and deserialization', () {
    final product = Product(
      id: 1,
      name: 'cigarro',
      barcode: '123456',
      price: 10.0,
      stockQuantity: 10,
      category: 'Outros',
    );

    final map = product.toMap();
    expect(map['price'], 10.0);
    expect(map['name'], 'cigarro');

    final reconstructed = Product.fromMap(map);
    expect(reconstructed.price, 10.0);
    expect(reconstructed.name, 'cigarro');
    expect(reconstructed.stockQuantity, 10);
  });
}
