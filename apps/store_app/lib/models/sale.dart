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
    double parsedTotalAmount = 0.0;
    if (map['totalAmount'] != null) {
      if (map['totalAmount'] is num) {
        parsedTotalAmount = (map['totalAmount'] as num).toDouble();
      } else if (map['totalAmount'] is String) {
        parsedTotalAmount = double.tryParse(map['totalAmount']) ?? 0.0;
      }
    }

    return Sale(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      totalAmount: parsedTotalAmount,
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
    double parsedPriceAtSale = 0.0;
    if (map['priceAtSale'] != null) {
      if (map['priceAtSale'] is num) {
        parsedPriceAtSale = (map['priceAtSale'] as num).toDouble();
      } else if (map['priceAtSale'] is String) {
        parsedPriceAtSale = double.tryParse(map['priceAtSale']) ?? 0.0;
      }
    }

    int parsedProductId = 0;
    if (map['productId'] != null) {
      if (map['productId'] is num) {
        parsedProductId = (map['productId'] as num).toInt();
      } else if (map['productId'] is String) {
        parsedProductId = int.tryParse(map['productId']) ?? 0;
      }
    }

    int parsedQuantity = 0;
    if (map['quantity'] != null) {
      if (map['quantity'] is num) {
        parsedQuantity = (map['quantity'] as num).toInt();
      } else if (map['quantity'] is String) {
        parsedQuantity = int.tryParse(map['quantity']) ?? 0;
      }
    }

    return SaleItem(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      saleId: map['saleId'] != null ? int.tryParse(map['saleId'].toString()) : null,
      productId: parsedProductId,
      productName: map['productName']?.toString() ?? '',
      quantity: parsedQuantity,
      priceAtSale: parsedPriceAtSale,
    );
  }
}
