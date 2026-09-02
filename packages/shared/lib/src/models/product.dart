class Product {
  final int? id;
  final String name;
  final String? barcode;
  final double price;
  final int stockQuantity;
  final String? imagePath;
  final String? category;

  Product({
    this.id,
    required this.name,
    this.barcode,
    required this.price,
    required this.stockQuantity,
    this.imagePath,
    this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'stockQuantity': stockQuantity,
      'imagePath': imagePath,
      'category': category,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    double parsedPrice = 0.0;
    if (map['price'] != null) {
      if (map['price'] is num) {
        parsedPrice = (map['price'] as num).toDouble();
      } else if (map['price'] is String) {
        parsedPrice = double.tryParse(map['price']) ?? 0.0;
      }
    }

    int parsedStock = 0;
    final stockVal = map['stockQuantity'] ?? map['stock_quantity'];
    if (stockVal != null) {
      if (stockVal is num) {
        parsedStock = stockVal.toInt();
      } else if (stockVal is String) {
        parsedStock = int.tryParse(stockVal) ?? 0;
      }
    }

    final imageVal = map['imagePath'] ?? map['image_path'];

    return Product(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      name: map['name']?.toString() ?? '',
      barcode: map['barcode']?.toString(),
      price: parsedPrice,
      stockQuantity: parsedStock,
      imagePath: imageVal?.toString(),
      category: map['category']?.toString(),
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    double? price,
    int? stockQuantity,
    String? imagePath,
    String? category,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      imagePath: imagePath ?? this.imagePath,
      category: category ?? this.category,
    );
  }
}
