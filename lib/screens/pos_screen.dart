import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/product.dart';
import '../helpers/database_helper.dart';
import '../helpers/responsive_helper.dart';
import 'package:intl/intl.dart';

/// Cart Item Model (for temporary cart storage)
class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;
}

/// POS Screen - Point of Sale with barcode scanning
class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  // Cart to hold items being sold
  final List<CartItem> _cart = [];

  // Scanner controller
  MobileScannerController? _scannerController;

  // Whether scanner is active
  bool _isScanning = false;

  // Mode: 'scan' or 'manual'
  String _mode = 'scan';

  // Customer payment controller
  final TextEditingController _customerGaveController = TextEditingController();

  // Search controller for manual product selection
  final TextEditingController _searchController = TextEditingController();

  // Products list for manual selection
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
    _searchController.addListener(_filterProducts);
    _loadProducts();
  }

  @override
  void dispose() {
    _scannerController?.stop();
    _scannerController?.dispose();
    _customerGaveController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Initialize scanner controller
  void _initializeScanner() {
    _scannerController?.dispose();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  /// Load all products for manual selection
  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });

    try {
      final products = await DatabaseHelper.instance.getAllProducts();

      if (mounted) {
        setState(() {
          _allProducts = products;
          _filteredProducts = products;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load products: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Filter products based on search query
  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((product) {
          return product.name.toLowerCase().contains(query) ||
              (product.barcode != null &&
                  product.barcode!.toLowerCase().contains(query));
        }).toList();
      }
    });
  }

  /// Add product to cart manually
  void _addProductToCart(Product product) {
    // Check stock availability
    if (product.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product is out of stock'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if product is already in cart
    final existingIndex = _cart.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      // Check if we can increase quantity
      if (_cart[existingIndex].quantity >= product.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only ${product.quantity} available in stock',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      // Increase quantity
      setState(() {
        _cart[existingIndex].quantity++;
      });
    } else {
      // Add to cart
      setState(() {
        _cart.add(CartItem(product: product, quantity: 1));
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${product.name} to cart'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Calculate change (customer gave - total)
  double get _change {
    final customerGave = double.tryParse(_customerGaveController.text) ?? 0.0;
    final change = customerGave - _cartTotal;
    return change < 0 ? 0.0 : change;
  }

  /// Calculate total amount in cart
  double get _cartTotal {
    return _cart.fold(0.0, (sum, item) => sum + item.total);
  }

  /// Handle barcode scan result
  Future<void> _handleBarcodeScan(String barcode) async {
    // Stop scanning
    await _stopScanner();

    try {
      // Find product by barcode
      final product =
          await DatabaseHelper.instance.getProductByBarcode(barcode);

      if (product == null) {
        // Product not found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product with barcode "$barcode" not found'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Check if product is already in cart
      final existingIndex = _cart.indexWhere(
        (item) => item.product.id == product.id,
      );

      if (existingIndex >= 0) {
        // Increase quantity
        setState(() {
          _cart[existingIndex].quantity++;
        });
      } else {
        // Check stock availability
        if (product.quantity <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product is out of stock'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        // Add to cart
        setState(() {
          _cart.add(CartItem(product: product, quantity: 1));
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${product.name} to cart'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning barcode: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Start barcode scanner
  Future<void> _startScanner() async {
    try {
      // Reinitialize scanner if it's in a bad state
      if (_scannerController == null) {
        _initializeScanner();
      }

      // Stop first if already running
      if (_isScanning) {
        await _scannerController?.stop();
      }

      // Start the scanner
      await _scannerController?.start();

      if (mounted) {
        setState(() {
          _isScanning = true;
        });
      }
    } catch (e) {
      // If start fails, reinitialize and try again
      _initializeScanner();
      try {
        await _scannerController?.start();
        if (mounted) {
          setState(() {
            _isScanning = true;
          });
        }
      } catch (e2) {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start camera: ${e2.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  /// Stop barcode scanner
  Future<void> _stopScanner() async {
    try {
      await _scannerController?.stop();
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    } catch (e) {
      // Even if stop fails, update the state
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  /// Remove item from cart
  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  /// Update item quantity in cart
  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeFromCart(index);
      return;
    }

    // Check stock availability
    final cartItem = _cart[index];
    if (newQuantity > cartItem.product.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only ${cartItem.product.quantity} available in stock',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _cart[index].quantity = newQuantity;
    });
  }

  /// Process checkout
  Future<void> _checkout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    // Confirm checkout
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Checkout'),
        content: Text(
          'Total: ₱${_cartTotal.toStringAsFixed(2)}\n\n'
          'Proceed with checkout?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing checkout...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Get current date
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      // Prepare cart items for transaction
      final cartItems = _cart
          .map((item) => {
                'product_id': item.product.id!,
                'quantity': item.quantity,
                'price': item.product.price,
              })
          .toList();

      // Process checkout with transaction (atomic operation)
      await DatabaseHelper.instance.processCheckout(
        _cartTotal,
        dateStr,
        cartItems,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Clear cart and customer payment
      setState(() {
        _cart.clear();
        _customerGaveController.clear();
      });

      // Reload products to update stock levels
      _loadProducts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sale completed! Total: ₱${_cartTotal.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Checkout failed: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveHelper.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Point of Sale',
          style: TextStyle(
            fontSize: isTablet ? 28 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: isTablet ? 28 : 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isTablet
          ? Row(
              children: [
                // Left side - Cart
                Expanded(
                  flex: 2,
                  child: _buildCartSection(context, isTablet),
                ),
                // Right side - Scanner/Manual Selection
                Expanded(
                  flex: 1,
                  child: _buildProductSelectionSection(context),
                ),
              ],
            )
          : Column(
              children: [
                // Product selection section on top for phones
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: _buildProductSelectionSection(context),
                ),
                // Cart section below
                Expanded(
                  child: _buildCartSection(context, isTablet),
                ),
              ],
            ),
    );
  }

  /// Build cart section
  Widget _buildCartSection(BuildContext context, bool isTablet) {
    return Column(
      children: [
        // Cart header
        Container(
          padding: EdgeInsets.all(
            ResponsiveHelper.isTablet(context) ? 16 : 12,
          ),
          color: Colors.blue.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cart',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(
                    context,
                    tabletSize: 24,
                    phoneSize: 20,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Items: ${_cart.length}',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(
                    context,
                    tabletSize: 18,
                    phoneSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Cart items list
        Expanded(
          child: _cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: ResponsiveHelper.getFontSize(
                          context,
                          tabletSize: 80,
                          phoneSize: 60,
                        ),
                        color: Colors.grey,
                      ),
                      SizedBox(
                        height: ResponsiveHelper.isTablet(context) ? 16 : 12,
                      ),
                      Text(
                        'Cart is empty',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getFontSize(
                            context,
                            tabletSize: 24,
                            phoneSize: 18,
                          ),
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(
                        height: ResponsiveHelper.isTablet(context) ? 8 : 6,
                      ),
                      Text(
                        'Scan barcode or manually add items',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getFontSize(
                            context,
                            tabletSize: 18,
                            phoneSize: 14,
                          ),
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _cart.length,
                  padding: EdgeInsets.all(
                    ResponsiveHelper.isTablet(context) ? 8 : 4,
                  ),
                  itemBuilder: (context, index) {
                    final item = _cart[index];
                    return Card(
                      margin: EdgeInsets.only(
                        bottom: ResponsiveHelper.isTablet(context) ? 8 : 4,
                        left: ResponsiveHelper.isTablet(context) ? 0 : 4,
                        right: ResponsiveHelper.isTablet(context) ? 0 : 4,
                      ),
                      child: ListTile(
                        dense: !isTablet,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal:
                              ResponsiveHelper.isTablet(context) ? 16 : 12,
                          vertical: ResponsiveHelper.isTablet(context) ? 8 : 4,
                        ),
                        title: Text(
                          item.product.name,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getFontSize(
                              context,
                              tabletSize: 20,
                              phoneSize: 16,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '₱${item.product.price.toStringAsFixed(2)} each',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getFontSize(
                              context,
                              tabletSize: 16,
                              phoneSize: 12,
                            ),
                          ),
                        ),
                        trailing: isTablet
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Quantity controls
                                  IconButton(
                                    icon:
                                        const Icon(Icons.remove_circle_outline),
                                    onPressed: () => _updateQuantity(
                                      index,
                                      item.quantity - 1,
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => _updateQuantity(
                                      index,
                                      item.quantity + 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '₱${item.total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _removeFromCart(index),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 20),
                                        onPressed: () => _updateQuantity(
                                          index,
                                          item.quantity - 1,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Text(
                                          '${item.quantity}',
                                          style: TextStyle(
                                            fontSize:
                                                ResponsiveHelper.getFontSize(
                                              context,
                                              tabletSize: 20,
                                              phoneSize: 16,
                                            ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 20),
                                        onPressed: () => _updateQuantity(
                                          index,
                                          item.quantity + 1,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '₱${item.total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.getFontSize(
                                        context,
                                        tabletSize: 18,
                                        phoneSize: 14,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () => _removeFromCart(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
        ),
        // Total, customer payment, change, and checkout
        Container(
          padding: EdgeInsets.all(
            ResponsiveHelper.isTablet(context) ? 16 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            children: [
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total:',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(
                        context,
                        tabletSize: 24,
                        phoneSize: 20,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₱${_cartTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(
                        context,
                        tabletSize: 32,
                        phoneSize: 24,
                      ),
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: ResponsiveHelper.isTablet(context) ? 16 : 12,
              ),
              // Customer Gave input
              TextField(
                controller: _customerGaveController,
                decoration: const InputDecoration(
                  labelText: 'Customer Gave',
                  border: OutlineInputBorder(),
                  prefixText: '₱',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(
                    context,
                    tabletSize: 20,
                    phoneSize: 16,
                  ),
                ),
                onChanged: (value) {
                  setState(() {}); // Rebuild to update change
                },
              ),
              SizedBox(
                height: ResponsiveHelper.isTablet(context) ? 16 : 12,
              ),
              // Change display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      _change > 0 ? Colors.green.shade50 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _change > 0 ? Colors.green : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Change:',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getFontSize(
                          context,
                          tabletSize: 22,
                          phoneSize: 18,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₱${_change.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getFontSize(
                          context,
                          tabletSize: 28,
                          phoneSize: 22,
                        ),
                        fontWeight: FontWeight.bold,
                        color: _change > 0 ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: ResponsiveHelper.isTablet(context) ? 16 : 12,
              ),
              SizedBox(
                width: double.infinity,
                height: ResponsiveHelper.isTablet(context) ? 60 : 48,
                child: ElevatedButton(
                  onPressed: _checkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'CHECKOUT',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(
                        context,
                        tabletSize: 24,
                        phoneSize: 18,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build product selection section (scanner or manual)
  Widget _buildProductSelectionSection(BuildContext context) {
    final isTablet = ResponsiveHelper.isTablet(context);

    return Container(
      color: Colors.grey.shade100,
      child: Column(
        children: [
          // Mode toggle header
          Container(
            padding: EdgeInsets.all(isTablet ? 12 : 8),
            color: Colors.blue.shade700,
            child: Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    context,
                    'scan',
                    'Scan Barcode',
                    Icons.qr_code_scanner,
                    isTablet,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeButton(
                    context,
                    'manual',
                    'Manual Add',
                    Icons.search,
                    isTablet,
                  ),
                ),
              ],
            ),
          ),
          // Content based on mode
          Expanded(
            child: _mode == 'scan'
                ? _buildScannerView(context, isTablet)
                : _buildManualSelectionView(context, isTablet),
          ),
        ],
      ),
    );
  }

  /// Build mode toggle button
  Widget _buildModeButton(
    BuildContext context,
    String mode,
    String label,
    IconData icon,
    bool isTablet,
  ) {
    final isSelected = _mode == mode;
    return ElevatedButton.icon(
      onPressed: () async {
        // Stop scanner if switching away from scan mode
        if (_mode == 'scan' && _isScanning) {
          await _stopScanner();
        }
        // Reinitialize scanner when switching back to scan mode
        if (mode == 'scan' && _mode != 'scan') {
          _initializeScanner();
        }
        setState(() {
          _mode = mode;
        });
      },
      icon: Icon(icon, size: isTablet ? 20 : 18),
      label: Text(
        label,
        style: TextStyle(
          fontSize: isTablet ? 16 : 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.white : Colors.blue.shade300,
        foregroundColor: isSelected ? Colors.blue.shade700 : Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 12 : 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Build scanner view
  Widget _buildScannerView(BuildContext context, bool isTablet) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Scanner controls
          Container(
            padding: EdgeInsets.all(isTablet ? 12 : 8),
            color: Colors.blue.shade900,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Barcode Scanner',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isScanning ? Icons.stop : Icons.play_arrow,
                    color: Colors.white,
                    size: isTablet ? 28 : 24,
                  ),
                  onPressed: () async {
                    if (_isScanning) {
                      await _stopScanner();
                    } else {
                      await _startScanner();
                    }
                  },
                ),
              ],
            ),
          ),
          // Scanner view
          Expanded(
            child: _isScanning && _scannerController != null
                ? MobileScanner(
                    controller: _scannerController!,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          _handleBarcodeScan(barcode.rawValue!);
                          break;
                        }
                      }
                    },
                    errorBuilder: (context, error, child) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 60,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Camera Error',
                              style: TextStyle(
                                fontSize: isTablet ? 20 : 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                error.toString(),
                                style: TextStyle(
                                  fontSize: isTablet ? 14 : 12,
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                _initializeScanner();
                                await _startScanner();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: isTablet ? 60 : 50,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap play to start scanning',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 12,
                            color: Colors.white54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Build manual product selection view
  Widget _buildManualSelectionView(BuildContext context, bool isTablet) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: EdgeInsets.all(isTablet ? 12 : 8),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products by name or barcode...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 16 : 12,
              ),
            ),
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
            ),
          ),
        ),
        // Products list
        Expanded(
          child: _isLoadingProducts
              ? const Center(child: CircularProgressIndicator())
              : _filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchController.text.isNotEmpty
                                ? Icons.search_off
                                : Icons.inventory_2_outlined,
                            size: isTablet ? 60 : 50,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'No products found'
                                : 'No products available',
                            style: TextStyle(
                              fontSize: isTablet ? 18 : 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final isOutOfStock = product.quantity <= 0;
                        return Card(
                          margin: EdgeInsets.only(
                            bottom: isTablet ? 8 : 4,
                            left: isTablet ? 4 : 2,
                            right: isTablet ? 4 : 2,
                          ),
                          color: isOutOfStock
                              ? Colors.grey.shade200
                              : Colors.white,
                          child: ListTile(
                            dense: !isTablet,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 16 : 12,
                              vertical: isTablet ? 8 : 4,
                            ),
                            title: Text(
                              product.name,
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                                color:
                                    isOutOfStock ? Colors.grey : Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '₱${product.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: isTablet ? 14 : 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                if (product.barcode != null)
                                  Text(
                                    'Barcode: ${product.barcode}',
                                    style: TextStyle(
                                      fontSize: isTablet ? 12 : 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                Text(
                                  'Stock: ${product.quantity}',
                                  style: TextStyle(
                                    fontSize: isTablet ? 12 : 10,
                                    color: isOutOfStock
                                        ? Colors.red
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.add_shopping_cart,
                                color: isOutOfStock ? Colors.grey : Colors.blue,
                                size: isTablet ? 28 : 24,
                              ),
                              onPressed: isOutOfStock
                                  ? null
                                  : () => _addProductToCart(product),
                              tooltip:
                                  isOutOfStock ? 'Out of stock' : 'Add to cart',
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
