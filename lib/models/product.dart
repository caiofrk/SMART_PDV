class Product {
  final int? id;
  final String name;
  final String? barcode;
  final double price;
  final int stockQuantity;
  final String? imagePath;

  Product({
    this.id,
    required this.name,
    this.barcode,
    required this.price,
    required this.stockQuantity,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'stockQuantity': stockQuantity,
      'imagePath': imagePath,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      price: map['price'],
      stockQuantity: map['stockQuantity'],
      imagePath: map['imagePath'],
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    double? price,
    int? stockQuantity,
    String? imagePath,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
