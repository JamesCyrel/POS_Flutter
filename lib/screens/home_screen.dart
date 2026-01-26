import 'package:flutter/material.dart';
import '../helpers/responsive_helper.dart';
import '../helpers/database_helper.dart';
import '../models/product.dart';
import 'product_management_screen.dart';
import 'pos_screen.dart';
import 'reports_screen.dart';

/// Home Screen - Main navigation screen
/// Shows buttons to navigate to different sections of the app
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _lowStockProducts = [];

  @override
  void initState() {
    super.initState();
    _loadLowStockProducts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload when returning to this screen
    _loadLowStockProducts();
  }

  /// Load products with low stock (<= 10)
  Future<void> _loadLowStockProducts() async {
    try {
      final products =
          await DatabaseHelper.instance.getLowStockProducts(threshold: 10);
      if (mounted) {
        setState(() {
          _lowStockProducts = products;
        });
      }
    } catch (e) {
      // Silently handle errors - low stock check is not critical
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveHelper.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'POS Inventory Management',
          style: TextStyle(
            fontSize: isTablet ? 28 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 2,
      ),
      body: Column(
        children: [
          // Low stock alert banner
          if (_lowStockProducts.isNotEmpty)
            _buildLowStockAlert(context, isTablet),
          // Main menu
          Expanded(
            child: Padding(
              padding: isTablet
                  ? const EdgeInsets.all(32.0)
                  : const EdgeInsets.all(16.0),
              child: isTablet
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMenuCard(context,
                            title: 'Products',
                            icon: Icons.inventory_2,
                            color: Colors.blue,
                            onTap: () => _navigateToProducts(context)),
                        _buildMenuCard(context,
                            title: 'Point of Sale',
                            icon: Icons.point_of_sale,
                            color: Colors.green,
                            onTap: () => _navigateToPOS(context)),
                        _buildMenuCard(context,
                            title: 'Reports',
                            icon: Icons.assessment,
                            color: Colors.orange,
                            onTap: () => _navigateToReports(context)),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMenuCard(context,
                            title: 'Products',
                            icon: Icons.inventory_2,
                            color: Colors.blue,
                            onTap: () => _navigateToProducts(context)),
                        const SizedBox(height: 16),
                        _buildMenuCard(context,
                            title: 'Point of Sale',
                            icon: Icons.point_of_sale,
                            color: Colors.green,
                            onTap: () => _navigateToPOS(context)),
                        const SizedBox(height: 16),
                        _buildMenuCard(context,
                            title: 'Reports',
                            icon: Icons.assessment,
                            color: Colors.orange,
                            onTap: () => _navigateToReports(context)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build low stock alert banner
  Widget _buildLowStockAlert(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.orange.shade300, width: 2),
        ),
      ),
      child: InkWell(
        onTap: () => _showLowStockDetails(context),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
              size: isTablet ? 32 : 28,
            ),
            SizedBox(width: isTablet ? 16 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Low Stock Alert!',
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  SizedBox(height: isTablet ? 4 : 2),
                  Text(
                    '${_lowStockProducts.length} product${_lowStockProducts.length > 1 ? 's' : ''} have 10 or fewer items in stock',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.orange.shade700,
              size: isTablet ? 20 : 18,
            ),
          ],
        ),
      ),
    );
  }

  /// Show low stock products details
  void _showLowStockDetails(BuildContext context) {
    final isTablet = ResponsiveHelper.isTablet(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Low Stock Products'),
          ],
        ),
        content: SizedBox(
          width: isTablet ? 500 : double.maxFinite,
          child: _lowStockProducts.isEmpty
              ? const Center(
                  child: Text('No low stock products'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _lowStockProducts.length,
                  itemBuilder: (context, index) {
                    final product = _lowStockProducts[index];
                    final isCritical = product.quantity == 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isCritical
                          ? Colors.red.shade50
                          : Colors.orange.shade50,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCritical
                              ? Colors.red.shade300
                              : Colors.orange.shade300,
                          child: Text(
                            '${product.quantity}',
                            style: TextStyle(
                              color: isCritical
                                  ? Colors.red.shade900
                                  : Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCritical
                                ? Colors.red.shade900
                                : Colors.orange.shade900,
                          ),
                        ),
                        subtitle: Text(
                          'Stock: ${product.quantity} | Price: ₱${product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isCritical
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                        trailing: Icon(
                          isCritical ? Icons.error : Icons.warning,
                          color: isCritical
                              ? Colors.red.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _navigateToProducts(context);
            },
            icon: const Icon(Icons.inventory_2),
            label: const Text('Manage Products'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToProducts(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProductManagementScreen()),
    );
    // Refresh low stock products when returning
    _loadLowStockProducts();
  }

  void _navigateToPOS(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const POSScreen()));
  }

  void _navigateToReports(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const ReportsScreen()));
  }

  /// Build a menu card widget
  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isTablet = ResponsiveHelper.isTablet(context);

    Widget card = Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: isTablet
              ? const EdgeInsets.all(32.0)
              : const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isTablet ? 80 : 60,
                color: color,
              ),
              SizedBox(height: isTablet ? 24 : 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: isTablet ? 28 : 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    if (isTablet) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: card,
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: card,
      );
    }
  }
}
