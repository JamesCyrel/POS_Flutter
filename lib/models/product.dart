/// Product Model
/// Represents a product in the inventory
class Product {
  // Product ID (primary key)
  int? id;
  
  // Product name
  String name;
  
  // Barcode (can be null if product doesn't have a barcode)
  String? barcode;
  
  // Product price
  double price;
  
  // Current stock quantity
  int quantity;

  /// Constructor
  Product({
    this.id,
    required this.name,
    this.barcode,
    required this.price,
    required this.quantity,
  });

  /// Convert Product to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'quantity': quantity,
    };
  }

  /// Create Product from Map (from database)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      price: map['price'] as double,
      quantity: map['quantity'] as int,
    );
  }

  /// Create a copy of the product with updated values
  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    double? price,
    int? quantity,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, barcode: $barcode, price: $price, quantity: $quantity)';
  }
}



