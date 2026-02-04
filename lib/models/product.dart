/// Product Model
/// Represents a product in the inventory
class Product {
  // Product ID (primary key)
  int? id;

  // Product name
  String name;

  // Category (defaults to Uncategorized)
  String category;

  // Barcode (can be null if product doesn't have a barcode)
  String? barcode;

  // Product image path (optional)
  String? imagePath;

  // Product price
  double price;

  // Capital price (puhunan)
  double capitalPrice;

  // Current stock quantity
  int quantity;

  /// Constructor
  Product({
    this.id,
    required this.name,
    this.category = 'Uncategorized',
    this.barcode,
    this.imagePath,
    this.capitalPrice = 0.0,
    required this.price,
    required this.quantity,
  });

  /// Convert Product to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'barcode': barcode,
      'image_path': imagePath,
      'capital_price': capitalPrice,
      'price': price,
      'quantity': quantity,
    };
  }

  /// Create Product from Map (from database)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: (map['category'] as String?)?.trim().isNotEmpty == true
          ? map['category'] as String
          : 'Uncategorized',
      barcode: map['barcode'] as String?,
      imagePath: map['image_path'] as String?,
      capitalPrice: (map['capital_price'] as num?)?.toDouble() ?? 0.0,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
    );
  }

  /// Create a copy of the product with updated values
  Product copyWith({
    int? id,
    String? name,
    String? category,
    String? barcode,
    String? imagePath,
    double? capitalPrice,
    double? price,
    int? quantity,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      imagePath: imagePath ?? this.imagePath,
      capitalPrice: capitalPrice ?? this.capitalPrice,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, category: $category, barcode: $barcode, imagePath: $imagePath, capitalPrice: $capitalPrice, price: $price, quantity: $quantity)';
  }
}
