import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/product.dart';
import '../helpers/database_helper.dart';
import '../helpers/responsive_helper.dart';
import 'payment_screen.dart';
import 'package:intl/intl.dart';

/// Cart Item Model (for temporary cart storage)
class CartItem {
  final Product product;
  int quantity;
  double? manualDiscountedUnitPrice; // Manual discount override

  CartItem({
    required this.product,
    this.quantity = 1,
    this.manualDiscountedUnitPrice,
  });

  // Get the unit price (manual discount or auto discount)
  double get unitPrice {
    if (manualDiscountedUnitPrice != null) {
      return manualDiscountedUnitPrice!;
    }
    final discountPercent = product.getDiscountPercent(quantity);
    return product.price * (1 - (discountPercent / 100));
  }

  // Get original subtotal (before any discount)
  double get subtotal => product.price * quantity;

  // Get total with discount applied
  double get total => unitPrice * quantity;

  // Get discount amount
  double get discountAmount => subtotal - total;

  // Get discount percentage
  double get discountPercent {
    if (product.price <= 0 || unitPrice >= product.price) {
      return 0.0;
    }
    return (1 - (unitPrice / product.price)) * 100;
  }
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

  // Search controller for manual product selection
  final TextEditingController _searchController = TextEditingController();

  // Products list for manual selection
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoadingProducts = false;

  // Category filter
  String _selectedCategory = 'All';
  List<String> _categories = ['All', 'Uncategorized', 'Wholesale'];

  // Debounce timer for search
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
    _searchController.addListener(_onSearchChanged);
    _loadProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scannerController?.stop();
    _scannerController?.dispose();
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
        _updateCategories(products);
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

  /// Handle search text changes with debouncing
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _filterProducts();
    });
  }

  /// Filter products based on search query
  void _filterProducts() {
    if (!mounted) return;

    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty && _selectedCategory == 'All') {
      setState(() {
        _filteredProducts = _allProducts;
      });
      return;
    }

    final filtered = _allProducts.where((product) {
      final productCategory =
          product.category.trim().isEmpty ? 'Uncategorized' : product.category;
      final categoryMatch = _selectedCategory == 'All' ||
          productCategory.toLowerCase() ==
              _selectedCategory.toLowerCase().trim();
      if (!categoryMatch) return false;

      if (query.isEmpty) {
        return true;
      }

      final nameMatch = product.name.toLowerCase().contains(query);
      final barcodeMatch = product.barcode != null &&
          product.barcode!.toLowerCase().contains(query);
      return nameMatch || barcodeMatch;
    }).toList();

    if (mounted) {
      setState(() {
        _filteredProducts = filtered;
      });
    }
  }

  void _updateCategories(List<Product> products) {
    if (!mounted) return;
    final dynamicCategories = products
        .map((product) => product.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final nextCategories = <String>[
      'All',
      'Uncategorized',
      'Wholesale',
      ...dynamicCategories.where(
        (category) =>
            category.toLowerCase() != 'uncategorized' &&
            category.toLowerCase() != 'wholesale',
      ),
    ];

    setState(() {
      _categories = nextCategories;
      if (!_categories.contains(_selectedCategory)) {
        _selectedCategory = 'All';
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

  /// Calculate original total (before discount)
  double get _originalTotal {
    return _cart.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Calculate total discount amount
  double get _totalDiscount {
    return _cart.fold(0.0, (sum, item) => sum + item.discountAmount);
  }

  /// Calculate total amount in cart (after discount)
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

  /// Edit manual discount for a cart item
  Future<void> _editManualDiscount(int index) async {
    final cartItem = _cart[index];
    final basePrice = cartItem.product.price;
    final currentUnitPrice = cartItem.unitPrice;
    var currentDiscountAmount = basePrice - currentUnitPrice;
    if (currentDiscountAmount < 0) currentDiscountAmount = 0;
    if (currentDiscountAmount > basePrice) currentDiscountAmount = basePrice;
    final currentDiscountPercent =
        basePrice > 0 ? (currentDiscountAmount / basePrice) * 100 : 0.0;
    final controller = TextEditingController(
      text: currentDiscountPercent.toStringAsFixed(1),
    );
    var isPercentMode = true;
    final autoUnitPrice = cartItem.product
                .getDiscountPercent(cartItem.quantity) >
            0
        ? cartItem.product.price *
            (1 - (cartItem.product.getDiscountPercent(cartItem.quantity) / 100))
        : cartItem.product.price;
    final rootContext = context;

    double? calculateDiscountedPrice(String input, bool percentMode) {
      final cleaned = input
          .replaceAll('₱', '')
          .replaceAll('%', '')
          .replaceAll(',', '')
          .trim();
      if (cleaned.isEmpty) return null;
      final value = double.tryParse(cleaned);
      if (value == null) return null;
      if (percentMode) {
        if (value < 0 || value > 100) return null;
        return basePrice * (1 - (value / 100));
      }
      if (value < 0 || value > basePrice) return null;
      return basePrice - value;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isTablet = ResponsiveHelper.isTablet(dialogContext);
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final previewPrice =
                calculateDiscountedPrice(controller.text, isPercentMode);
            return AlertDialog(
              title: const Text('Edit Discount Price'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product: ${cartItem.product.name}',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Original price: ₱${basePrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                    ),
                  ),
                  if (cartItem.manualDiscountedUnitPrice == null &&
                      autoUnitPrice < basePrice)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Auto discount price: ₱${autoUnitPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Percent'),
                        selected: isPercentMode,
                        onSelected: (selected) {
                          if (!selected) return;
                          setDialogState(() {
                            final price = calculateDiscountedPrice(
                              controller.text,
                              isPercentMode,
                            );
                            isPercentMode = true;
                            if (price != null && basePrice > 0) {
                              final value =
                                  ((basePrice - price) / basePrice) * 100;
                              controller.text = value.toStringAsFixed(1);
                            } else {
                              controller.text =
                                  currentDiscountPercent.toStringAsFixed(1);
                            }
                            controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: controller.text.length),
                            );
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Peso'),
                        selected: !isPercentMode,
                        onSelected: (selected) {
                          if (!selected) return;
                          setDialogState(() {
                            final price = calculateDiscountedPrice(
                              controller.text,
                              isPercentMode,
                            );
                            isPercentMode = false;
                            if (price != null) {
                              final value = basePrice - price;
                              controller.text = value.toStringAsFixed(2);
                            } else {
                              controller.text =
                                  currentDiscountAmount.toStringAsFixed(2);
                            }
                            controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: controller.text.length),
                            );
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isPercentMode
                          ? 'Discount percent'
                          : 'Discount amount',
                      prefixText: isPercentMode ? null : '₱',
                      suffixText: isPercentMode ? '%' : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  if (previewPrice != null)
                    Text(
                      'Final price per item: ₱${previewPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    Text(
                      isPercentMode
                          ? 'Enter a percent from 0 to 100'
                          : 'Enter a peso amount up to ₱${basePrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.red.shade400,
                      ),
                    ),
                  if (previewPrice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Total for ${cartItem.quantity} items: ₱${(previewPrice * cartItem.quantity).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _cart[index].manualDiscountedUnitPrice = null;
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Reset to Auto'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final discountedPrice = calculateDiscountedPrice(
                      controller.text,
                      isPercentMode,
                    );
                    if (discountedPrice == null) {
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            isPercentMode
                                ? 'Enter a percent from 0 to 100'
                                : 'Enter a valid peso discount amount',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (discountedPrice > basePrice) {
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Discounted price cannot exceed original price',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (discountedPrice < 0) {
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        const SnackBar(
                          content: Text('Discounted price cannot be negative'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _cart[index].manualDiscountedUnitPrice = discountedPrice;
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Open payment screen
  Future<void> _openPaymentScreen() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    final originalTotal = _originalTotal;
    final discount = _totalDiscount;
    final grandTotal = _cartTotal;

    final customerGave = await Navigator.push<double>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          originalTotal: originalTotal,
          discount: discount,
          grandTotal: grandTotal,
        ),
      ),
    );

    if (customerGave == null) return;

    await _checkout(customerGave, grandTotal);
  }

  /// Process checkout
  Future<void> _checkout(double customerGave, double total) async {
    // Capture total before any state changes so it doesn't reset to 0
    final double checkoutTotal = total;

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
                'price': item.unitPrice,
              })
          .toList();

      // Process checkout with transaction (atomic operation)
      await DatabaseHelper.instance.processCheckout(
        checkoutTotal,
        dateStr,
        cartItems,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Clear cart
      setState(() {
        _cart.clear();
      });

      // Reload products to update stock levels
      _loadProducts();

      if (mounted) {
        final change = customerGave - checkoutTotal;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sale completed! Total: ₱${checkoutTotal.toStringAsFixed(2)} | Change: ₱${change.toStringAsFixed(2)}',
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
                  height: MediaQuery.of(context).size.height * 0.55,
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
                  key: const ValueKey('cart_list'),
                  itemCount: _cart.length,
                  padding: EdgeInsets.all(
                    ResponsiveHelper.isTablet(context) ? 8 : 4,
                  ),
                  cacheExtent: 200,
                  itemBuilder: (context, index) {
                    final item = _cart[index];
                    return Card(
                      key: ValueKey('cart_item_${item.product.id}_$index'),
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₱${item.product.price.toStringAsFixed(2)} each',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getFontSize(
                                  context,
                                  tabletSize: 16,
                                  phoneSize: 12,
                                ),
                              ),
                            ),
                            if (item.manualDiscountedUnitPrice != null)
                              Text(
                                item.discountPercent > 0
                                    ? 'Manual: ₱${item.unitPrice.toStringAsFixed(2)} each (${item.discountPercent.toStringAsFixed(1)}% off)'
                                    : 'Manual: ₱${item.unitPrice.toStringAsFixed(2)} each',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getFontSize(
                                    context,
                                    tabletSize: 14,
                                    phoneSize: 11,
                                  ),
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else if (item.discountPercent > 0)
                              Text(
                                'Auto: ₱${item.unitPrice.toStringAsFixed(2)} each (${item.discountPercent.toStringAsFixed(1)}% off)',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getFontSize(
                                    context,
                                    tabletSize: 14,
                                    phoneSize: 11,
                                  ),
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (item.discountAmount > 0)
                              Text(
                                'Saved: ₱${item.discountAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getFontSize(
                                    context,
                                    tabletSize: 12,
                                    phoneSize: 10,
                                  ),
                                  color: Colors.green.shade700,
                                ),
                              ),
                          ],
                        ),
                        trailing: isTablet
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Edit discount button
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit discount price',
                                    onPressed: () => _editManualDiscount(index),
                                  ),
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
                                      // Edit discount button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                        ),
                                        tooltip: 'Edit discount price',
                                        onPressed: () =>
                                            _editManualDiscount(index),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
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
        // Totals display (compact)
        if (_cart.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.isTablet(context) ? 12 : 8,
              vertical: ResponsiveHelper.isTablet(context) ? 8 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                          tabletSize: 14,
                          phoneSize: 12,
                        ),
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    Text(
                      '₱${_originalTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getFontSize(
                          context,
                          tabletSize: 14,
                          phoneSize: 12,
                        ),
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                // Discount
                if (_totalDiscount > 0) ...[
                  SizedBox(
                    height: ResponsiveHelper.isTablet(context) ? 3 : 2,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Discount:',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getFontSize(
                            context,
                            tabletSize: 14,
                            phoneSize: 12,
                          ),
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade800,
                        ),
                      ),
                      Text(
                        '- ₱${_totalDiscount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getFontSize(
                            context,
                            tabletSize: 14,
                            phoneSize: 12,
                          ),
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
                // Grand Total
                SizedBox(
                  height: ResponsiveHelper.isTablet(context) ? 3 : 2,
                ),
                Divider(
                  color: Colors.grey.shade400,
                  thickness: 0.5,
                  height: ResponsiveHelper.isTablet(context) ? 6 : 4,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Grand Total:',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getFontSize(
                          context,
                          tabletSize: 16,
                          phoneSize: 14,
                        ),
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    Text(
                      '₱${_cartTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getFontSize(
                          context,
                          tabletSize: 18,
                          phoneSize: 16,
                        ),
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // Checkout button
        Container(
          padding: EdgeInsets.all(
            ResponsiveHelper.isTablet(context) ? 16 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: ResponsiveHelper.isTablet(context) ? 60 : 48,
            child: ElevatedButton(
              onPressed: _openPaymentScreen,
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
        // Category filter
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 12 : 8,
            vertical: isTablet ? 8 : 6,
          ),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                      _filterProducts();
                    },
                    selectedColor: Colors.blue.shade100,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
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
                      key: const ValueKey('products_list'),
                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                      itemCount: _filteredProducts.length,
                      cacheExtent: 250,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final isOutOfStock = product.quantity <= 0;
                        return Card(
                          key: ValueKey('product_${product.id}'),
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
                            leading: Container(
                              width: isTablet ? 48 : 40,
                              height: isTablet ? 48 : 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade200,
                              ),
                              child: product.imagePath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(product.imagePath!),
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.image,
                                      color: Colors.grey,
                                    ),
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
                                  'Category: ${product.category.trim().isEmpty ? 'Uncategorized' : product.category}',
                                  style: TextStyle(
                                    fontSize: isTablet ? 12 : 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (product.discountRules.isNotEmpty)
                                  Text(
                                    'Discounts: ${product.discountRules.map((r) => '${r.minQty}+ @ ${r.percent}%').join(', ')}',
                                    style: TextStyle(
                                      fontSize: isTablet ? 11 : 9,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
