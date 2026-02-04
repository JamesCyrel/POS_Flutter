import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../helpers/database_helper.dart';
import '../helpers/responsive_helper.dart';

/// Product Management Screen
/// Allows adding, editing, and viewing products
class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  // List to hold all products
  List<Product> _products = [];

  // Filtered products for search
  List<Product> _filteredProducts = [];

  // Search controller
  final TextEditingController _searchController = TextEditingController();

  // Category filter
  String _selectedCategory = 'All';
  List<String> _categories = ['All', 'Uncategorized', 'Wholesale'];

  // Loading state
  bool _isLoading = true;

  // Debounce timer for search
  Timer? _searchDebounce;

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
        _filteredProducts = _products;
      });
      return;
    }

    final filtered = _products.where((product) {
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

  /// Load all products from database
  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    final products = await DatabaseHelper.instance.getAllProducts();

    setState(() {
      _products = products;
      _filteredProducts = products;
      _isLoading = false;
    });
    _updateCategories(products);
  }

  /// Show barcode scanner dialog
  Future<String?> _showBarcodeScanner(BuildContext dialogContext) async {
    final scannerController = MobileScannerController();
    String? scannedBarcode;

    final result = await showDialog<String>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (scannerDialogContext) {
        // Start scanner when dialog opens
        scannerController.start();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Scan Barcode'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: scannerController,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null &&
                              scannedBarcode == null) {
                            scannedBarcode = barcode.rawValue;
                            scannerController.stop();
                            Navigator.pop(scannerDialogContext, scannedBarcode);
                            break;
                          }
                        }
                      },
                    ),
                    // Overlay with instructions
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Point camera at barcode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    scannerController.stop();
                    Navigator.pop(scannerDialogContext);
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    // Clean up scanner controller
    scannerController.stop();
    scannerController.dispose();

    return result;
  }

  /// Show dialog to add/edit product
  Future<void> _showProductDialog({Product? product}) async {
    // Controllers for form fields
    final nameController = TextEditingController(text: product?.name ?? '');
    final barcodeController =
        TextEditingController(text: product?.barcode ?? '');
    final categoryController = TextEditingController(
      // For new products, start empty so 'Uncategorized' only appears as a hint,
      // but when editing keep the existing category.
      text: product?.category ?? '',
    );
    final capitalController = TextEditingController(
      text: product?.capitalPrice != null && product!.capitalPrice > 0
          ? product.capitalPrice.toStringAsFixed(2)
          : '',
    );
    final priceController = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    final quantityController = TextEditingController(
      text: product?.quantity.toString() ?? '0',
    );
    String? selectedImagePath = product?.imagePath;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product == null ? 'Add Product' : 'Edit Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image picker
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade200,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: selectedImagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(selectedImagePath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(
                              Icons.image,
                              color: Colors.grey,
                              size: 32,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final picked = await _imagePicker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1024,
                                maxHeight: 1024,
                                imageQuality: 85,
                              );
                              if (picked != null) {
                                selectedImagePath = picked.path;
                                setDialogState(() {});
                              }
                            },
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Select Image'),
                          ),
                          if (selectedImagePath != null) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                selectedImagePath = null;
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.delete, color: Colors.red),
                              label: const Text(
                                'Remove Image',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Barcode field with scan button
                TextField(
                  controller: barcodeController,
                  decoration: InputDecoration(
                    labelText: 'Barcode (optional)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () async {
                        // Scan barcode
                        final scannedBarcode =
                            await _showBarcodeScanner(context);
                        if (scannedBarcode != null) {
                          barcodeController.text = scannedBarcode;
                          setDialogState(() {});
                          // Show success message
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Barcode scanned: $scannedBarcode'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        }
                      },
                      tooltip: 'Scan Barcode',
                    ),
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'e.g. Uncategorized, Wholesale',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: capitalController,
                  decoration: const InputDecoration(
                    labelText: 'Capital Price (Puhunan)',
                    border: OutlineInputBorder(),
                    prefixText: '₱',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(fontSize: 18)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      // Validate inputs
      if (nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product name is required')),
        );
        return;
      }

      final price = double.tryParse(priceController.text);
      if (price == null || price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valid price is required')),
        );
        return;
      }

      final capitalInput = capitalController.text.trim();
      final capitalPrice =
          capitalInput.isEmpty ? price : double.tryParse(capitalInput);
      if (capitalPrice == null || capitalPrice < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valid capital price is required')),
        );
        return;
      }

      final quantity = int.tryParse(quantityController.text) ?? 0;
      if (quantity < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valid quantity is required')),
        );
        return;
      }

      // Create or update product
      final newProduct = Product(
        id: product?.id,
        name: nameController.text.trim(),
        category: categoryController.text.trim().isEmpty
            ? 'Uncategorized'
            : categoryController.text.trim(),
        barcode: barcodeController.text.trim().isEmpty
            ? null
            : barcodeController.text.trim(),
        imagePath: selectedImagePath,
        capitalPrice: capitalPrice,
        price: price,
        quantity: quantity,
      );

      if (product == null) {
        // Add new product
        await DatabaseHelper.instance.insertProduct(newProduct);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );
      } else {
        // Update existing product
        await DatabaseHelper.instance.updateProduct(newProduct);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully')),
        );
      }

      // Reload products
      _loadProducts();
    }
  }

  /// Delete product with confirmation
  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteProduct(product.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted')),
      );
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Product Management',
          style: TextStyle(
            fontSize: ResponsiveHelper.getFontSize(
              context,
              tabletSize: 28,
              phoneSize: 20,
            ),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 32),
            onPressed: () => _showProductDialog(),
            tooltip: 'Add Product',
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
          Padding(
            padding: const EdgeInsets.all(8.0),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          // Products list
          Expanded(
            child: _isLoading
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
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No products found'
                                  : 'No products yet',
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.grey,
                              ),
                            ),
                            if (_searchController.text.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _showProductDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Product'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : _buildProductsGrid(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Product', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  /// Build products grid
  Widget _buildProductsGrid() {
    return Padding(
      padding: ResponsiveHelper.getPadding(
        context,
        tabletPadding: const EdgeInsets.all(16.0),
        phonePadding: const EdgeInsets.all(8.0),
      ),
      child: GridView.builder(
        key: const ValueKey('products_grid'),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveHelper.getGridCrossAxisCount(
            context,
            tabletCount: 3,
            phoneCount: 2,
          ),
          crossAxisSpacing: ResponsiveHelper.isTablet(context) ? 16 : 8,
          mainAxisSpacing: ResponsiveHelper.isTablet(context) ? 16 : 8,
          childAspectRatio: ResponsiveHelper.isTablet(context) ? 1.5 : 1.4,
        ),
        itemCount: _filteredProducts.length,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          final product = _filteredProducts[index];
          final isLowStock = product.quantity <= 10;
          final isOutOfStock = product.quantity == 0;
          return Card(
            key: ValueKey('product_card_${product.id}'),
            elevation: 2,
            color: isOutOfStock
                ? Colors.red.shade50
                : isLowStock
                    ? Colors.orange.shade50
                    : Colors.white,
            child: Padding(
              padding: EdgeInsets.all(
                ResponsiveHelper.isTablet(context) ? 16.0 : 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (product.imagePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(product.imagePath!),
                        height: ResponsiveHelper.isTablet(context) ? 80 : 60,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: ResponsiveHelper.isTablet(context) ? 80 : 60,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.image,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
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
                      ),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showProductDialog(product: product);
                          } else if (value == 'delete') {
                            _deleteProduct(product);
                          }
                        },
                      ),
                    ],
                  ),
                  if (product.barcode != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Barcode: ${product.barcode}',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getFontSize(
                          context,
                          tabletSize: 14,
                          phoneSize: 12,
                        ),
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Category: ${product.category.trim().isEmpty ? 'Uncategorized' : product.category}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(
                        context,
                        tabletSize: 14,
                        phoneSize: 12,
                      ),
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Capital: ₱${product.capitalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(
                        context,
                        tabletSize: 14,
                        phoneSize: 12,
                      ),
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '₱${product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getFontSize(
                              context,
                              tabletSize: 18,
                              phoneSize: 14,
                            ),
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: product.quantity == 0
                                ? Colors.red.withOpacity(0.2)
                                : product.quantity <= 10
                                    ? Colors.orange.withOpacity(0.2)
                                    : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: isLowStock
                                ? Border.all(
                                    color: Colors.orange.shade400,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLowStock)
                                Icon(
                                  isOutOfStock
                                      ? Icons.error_outline
                                      : Icons.warning_amber_rounded,
                                  size: ResponsiveHelper.getFontSize(
                                    context,
                                    tabletSize: 14,
                                    phoneSize: 12,
                                  ),
                                  color:
                                      isOutOfStock ? Colors.red : Colors.orange,
                                ),
                              if (isLowStock) const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Stock: ${product.quantity}',
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.getFontSize(
                                      context,
                                      tabletSize: 14,
                                      phoneSize: 12,
                                    ),
                                    fontWeight: FontWeight.bold,
                                    color: product.quantity == 0
                                        ? Colors.red
                                        : product.quantity <= 10
                                            ? Colors.orange
                                            : Colors.green,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
