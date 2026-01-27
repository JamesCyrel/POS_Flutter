import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  int _totalProducts = 0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;
  int _totalTransactions = 0;
  int _categoryCount = 0;
  double _totalSales = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload when returning to this screen
    _loadAnalytics();
  }

  /// Load dashboard analytics
  Future<void> _loadAnalytics() async {
    try {
      final lowStockProducts =
          await DatabaseHelper.instance.getLowStockProducts(threshold: 10);
      final totalProducts =
          await DatabaseHelper.instance.getTotalProductCount();
      final outOfStockCount =
          await DatabaseHelper.instance.getOutOfStockCount();
      final totalSales = await DatabaseHelper.instance.getTotalSalesAllTime();
      final totalTransactions =
          await DatabaseHelper.instance.getTotalTransactionCount();
      final categories = await DatabaseHelper.instance.getDistinctCategories();
      if (mounted) {
        setState(() {
          _lowStockProducts = lowStockProducts;
          _lowStockCount = lowStockProducts.length;
          _totalProducts = totalProducts;
          _outOfStockCount = outOfStockCount;
          _totalSales = totalSales;
          _totalTransactions = totalTransactions;
          _categoryCount = categories.length;
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
      body: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Low stock alert banner
            if (_lowStockProducts.isNotEmpty)
              _buildLowStockAlert(context, isTablet),
            // Analytics
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 32.0 : 16.0,
                vertical: isTablet ? 16.0 : 8.0,
              ),
              child: _buildAnalyticsSection(context, isTablet),
            ),
            // Main menu
            Padding(
              padding: isTablet
                  ? const EdgeInsets.fromLTRB(32, 8, 32, 32)
                  : const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _buildMenuSection(context, isTablet),
            ),
          ],
        ),
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

  /// Build analytics section
  Widget _buildAnalyticsSection(BuildContext context, bool isTablet) {
    final cardWidth =
        isTablet ? 220.0 : (MediaQuery.of(context).size.width - 48) / 2;
    final currencyFormat = NumberFormat('#,##0.00');

    final cards = <Widget>[
      _buildAnalyticsCard(
        title: 'Total Products',
        value: '$_totalProducts',
        icon: Icons.inventory_2,
        color: Colors.blue,
        width: cardWidth,
      ),
      _buildAnalyticsCard(
        title: 'Total Sales',
        value: '₱${currencyFormat.format(_totalSales)}',
        icon: Icons.payments,
        color: Colors.green,
        width: cardWidth,
      ),
      _buildAnalyticsCard(
        title: 'Transactions',
        value: '$_totalTransactions',
        icon: Icons.receipt_long,
        color: Colors.teal,
        width: cardWidth,
      ),
      _buildAnalyticsCard(
        title: 'Low Stock',
        value: '$_lowStockCount',
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
        width: cardWidth,
      ),
      _buildAnalyticsCard(
        title: 'Out of Stock',
        value: '$_outOfStockCount',
        icon: Icons.error_outline,
        color: Colors.red,
        width: cardWidth,
      ),
      _buildAnalyticsCard(
        title: 'Categories',
        value: '$_categoryCount',
        icon: Icons.category,
        color: Colors.purple,
        width: cardWidth,
      ),
    ];

    return Wrap(
      spacing: isTablet ? 16 : 12,
      runSpacing: isTablet ? 16 : 12,
      children: cards,
    );
  }

  Widget _buildMenuSection(BuildContext context, bool isTablet) {
    final availableWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = isTablet ? 64.0 : 32.0;
    final spacing = isTablet ? 16.0 : 12.0;
    final cardWidth = isTablet
        ? (availableWidth - horizontalPadding - spacing * 2) / 3
        : double.infinity;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        _buildMenuCard(
          context,
          title: 'Products',
          icon: Icons.inventory_2,
          color: Colors.blue,
          onTap: () => _navigateToProducts(context),
          width: cardWidth,
        ),
        _buildMenuCard(
          context,
          title: 'Point of Sale',
          icon: Icons.point_of_sale,
          color: Colors.green,
          onTap: () => _navigateToPOS(context),
          width: cardWidth,
        ),
        _buildMenuCard(
          context,
          title: 'Reports',
          icon: Icons.assessment,
          color: Colors.orange,
          onTap: () => _navigateToReports(context),
          width: cardWidth,
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    _loadAnalytics();
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
    double? width,
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

    return SizedBox(
      width: width,
      child: card,
    );
  }
}
