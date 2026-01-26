import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';

/// Database Helper Class
/// Handles all SQLite database operations
class DatabaseHelper {
  // Singleton pattern - only one instance of DatabaseHelper
  static final DatabaseHelper instance = DatabaseHelper._init();

  // Database instance
  static Database? _database;

  // Private constructor
  DatabaseHelper._init();

  /// Get database instance (creates if doesn't exist)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_inventory.db');
    return _database!;
  }

  /// Initialize database and create tables
  Future<Database> _initDB(String filePath) async {
    // Get the database path
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Open or create the database
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  /// Create all database tables
  Future<void> _createDB(Database db, int version) async {
    // Create products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');

    // Create sales table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    // Create index for sales date queries
    await db.execute('CREATE INDEX idx_sales_date ON sales(date)');

    // Create sale_items table
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Create indexes for sale_items
    await db
        .execute('CREATE INDEX idx_sale_items_sale_id ON sale_items(sale_id)');
    await db.execute(
        'CREATE INDEX idx_sale_items_product_id ON sale_items(product_id)');
  }

  // ========== PRODUCT OPERATIONS ==========

  /// Insert a new product
  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  /// Get all products
  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final result = await db.query('products', orderBy: 'name ASC');
    return result.map((map) => Product.fromMap(map)).toList();
  }

  /// Get products with low stock (quantity <= threshold)
  Future<List<Product>> getLowStockProducts({int threshold = 10}) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'quantity <= ?',
      whereArgs: [threshold],
      orderBy: 'quantity ASC, name ASC',
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  /// Get a product by ID
  Future<Product?> getProductById(int id) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  /// Get a product by barcode
  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  /// Update a product
  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  /// Delete a product
  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update product quantity (for stock management)
  Future<int> updateProductQuantity(int productId, int newQuantity) async {
    final db = await database;
    return await db.update(
      'products',
      {'quantity': newQuantity},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // ========== SALE OPERATIONS ==========

  /// Insert a new sale
  Future<int> insertSale(double total, String date) async {
    final db = await database;
    return await db.insert('sales', {
      'total': total,
      'date': date,
    });
  }

  /// Insert a sale item
  Future<int> insertSaleItem(
      int saleId, int productId, int quantity, double price) async {
    final db = await database;
    return await db.insert('sale_items', {
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'price': price,
    });
  }

  /// Get all sales for a specific date
  Future<List<Map<String, dynamic>>> getSalesByDate(String date) async {
    final db = await database;
    return await db.query(
      'sales',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'id DESC',
    );
  }

  /// Get total sales for a specific date
  Future<double> getTotalSalesByDate(String date) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(total) as total FROM sales WHERE date = ?',
      [date],
    );
    if (result.isEmpty || result.first['total'] == null) {
      return 0.0;
    }
    return (result.first['total'] as num).toDouble();
  }

  /// Get sale items for a specific sale
  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final db = await database;
    return await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
  }

  /// Get all products sold today with quantities
  Future<List<Map<String, dynamic>>> getProductsSoldToday(String date) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        p.name,
        p.barcode,
        SUM(si.quantity) as total_quantity,
        SUM(si.quantity * si.price) as total_revenue
      FROM sale_items si
      INNER JOIN sales s ON si.sale_id = s.id
      INNER JOIN products p ON si.product_id = p.id
      WHERE s.date = ?
      GROUP BY p.id
      ORDER BY total_quantity DESC
    ''', [date]);
  }

  /// Get total sales for a date range
  Future<double> getTotalSalesByDateRange(
      String startDate, String endDate) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(total) as total FROM sales WHERE date >= ? AND date <= ?',
      [startDate, endDate],
    );
    if (result.isEmpty || result.first['total'] == null) {
      return 0.0;
    }
    return (result.first['total'] as num).toDouble();
  }

  /// Get all sales for a date range
  Future<List<Map<String, dynamic>>> getSalesByDateRange(
      String startDate, String endDate) async {
    final db = await database;
    return await db.query(
      'sales',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'id DESC',
    );
  }

  /// Get products sold in a date range
  Future<List<Map<String, dynamic>>> getProductsSoldInRange(
      String startDate, String endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        p.name,
        p.barcode,
        SUM(si.quantity) as total_quantity,
        SUM(si.quantity * si.price) as total_revenue
      FROM sale_items si
      INNER JOIN sales s ON si.sale_id = s.id
      INNER JOIN products p ON si.product_id = p.id
      WHERE s.date >= ? AND s.date <= ?
      GROUP BY p.id
      ORDER BY total_quantity DESC
    ''', [startDate, endDate]);
  }

  /// Process checkout with transaction (atomic operation)
  /// Returns sale ID on success, throws exception on failure
  Future<int> processCheckout(
    double total,
    String date,
    List<Map<String, dynamic>> cartItems,
  ) async {
    final db = await database;

    return await db.transaction((txn) async {
      // Validate stock availability for all items first
      for (final item in cartItems) {
        final productId = item['product_id'] as int;
        final requestedQuantity = item['quantity'] as int;

        // Get current stock
        final productResult = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId],
        );

        if (productResult.isEmpty) {
          throw Exception('Product with ID $productId not found');
        }

        final currentStock = productResult.first['quantity'] as int;
        if (currentStock < requestedQuantity) {
          throw Exception(
            'Insufficient stock. Product ID $productId has only $currentStock available, but $requestedQuantity requested',
          );
        }
      }

      // Create sale record
      final saleId = await txn.insert('sales', {
        'total': total,
        'date': date,
      });

      // Process each cart item
      for (final item in cartItems) {
        final productId = item['product_id'] as int;
        final quantity = item['quantity'] as int;
        final price = item['price'] as double;

        // Add sale item
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': productId,
          'quantity': quantity,
          'price': price,
        });

        // Update product stock (with validation)
        final productResult = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId],
        );

        if (productResult.isEmpty) {
          throw Exception(
              'Product with ID $productId not found during stock update');
        }

        final currentStock = productResult.first['quantity'] as int;
        final newQuantity = currentStock - quantity;

        if (newQuantity < 0) {
          throw Exception(
            'Stock validation failed. Product ID $productId would have negative stock',
          );
        }

        await txn.update(
          'products',
          {'quantity': newQuantity},
          where: 'id = ?',
          whereArgs: [productId],
        );
      }

      return saleId;
    });
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
