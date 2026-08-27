class Sale {
  final int? id;
  final double totalAmount;
  final DateTime timestamp;
  final List<SaleItem> items;

  Sale({
    this.id,
    required this.totalAmount,
    required this.timestamp,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'totalAmount': totalAmount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map, {List<SaleItem> items = const []}) {
    return Sale(
      id: map['id'],
      totalAmount: map['totalAmount'],
      timestamp: DateTime.parse(map['timestamp']),
      items: items,
    );
  }
}

class SaleItem {
  final int? id;
  final int? saleId;
  final int productId;
  final String productName; // Joined from products table usually
  final int quantity;
  final double priceAtSale;

  SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    this.productName = '',
    required this.quantity,
    required this.priceAtSale,
  });

  Map<String, dynamic> toMap(int saleId) {
    return {
      'id': id,
      'saleId': saleId,
      'productId': productId,
      'quantity': quantity,
      'priceAtSale': priceAtSale,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'],
      saleId: map['saleId'],
      productId: map['productId'],
      productName: map['productName'] ?? '',
      quantity: map['quantity'],
      priceAtSale: map['priceAtSale'],
    );
  }
}
