import 'dart:convert';

/// Product Model
/// Represents a product in the inventory
class DiscountRule {
  final int minQty;
  final double percent;

  DiscountRule({required this.minQty, required this.percent});

  Map<String, dynamic> toMap() => {
        'minQty': minQty,
        'percent': percent,
      };

  factory DiscountRule.fromMap(Map<String, dynamic> map) {
    return DiscountRule(
      minQty: (map['minQty'] as num?)?.toInt() ?? 0,
      percent: (map['percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

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

  // Quantity-based discount rules
  List<DiscountRule> discountRules;
  
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
    this.discountRules = const [],
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
      'discount_rules': jsonEncode(
        discountRules.map((rule) => rule.toMap()).toList(),
      ),
      'price': price,
      'quantity': quantity,
    };
  }

  /// Create Product from Map (from database)
  factory Product.fromMap(Map<String, dynamic> map) {
    final rulesJson = map['discount_rules'] as String?;
    List<DiscountRule> rules = [];
    if (rulesJson != null && rulesJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rulesJson) as List<dynamic>;
        rules = decoded
            .map((entry) => DiscountRule.fromMap(entry as Map<String, dynamic>))
            .toList();
      } catch (_) {
        rules = [];
      }
    }

    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: (map['category'] as String?)?.trim().isNotEmpty == true
          ? map['category'] as String
          : 'Uncategorized',
      barcode: map['barcode'] as String?,
      imagePath: map['image_path'] as String?,
      capitalPrice: (map['capital_price'] as num?)?.toDouble() ?? 0.0,
      discountRules: rules,
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
    List<DiscountRule>? discountRules,
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
      discountRules: discountRules ?? this.discountRules,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  double getDiscountPercent(int quantity) {
    if (discountRules.isEmpty) return 0.0;
    double percent = 0.0;
    for (final rule in discountRules) {
      if (quantity >= rule.minQty && rule.percent >= percent) {
        percent = rule.percent;
      }
    }
    return percent;
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, category: $category, barcode: $barcode, imagePath: $imagePath, capitalPrice: $capitalPrice, price: $price, quantity: $quantity, discountRules: $discountRules)';
  }
}
