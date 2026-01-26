import 'package:flutter/material.dart';
import '../helpers/responsive_helper.dart';
import 'product_management_screen.dart';
import 'pos_screen.dart';
import 'reports_screen.dart';

/// Home Screen - Main navigation screen
/// Shows buttons to navigate to different sections of the app
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      body: Padding(
        padding: isTablet 
            ? const EdgeInsets.all(32.0)
            : const EdgeInsets.all(16.0),
        child: isTablet
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMenuCard(context, title: 'Products', icon: Icons.inventory_2, color: Colors.blue, onTap: () => _navigateToProducts(context)),
                  _buildMenuCard(context, title: 'Point of Sale', icon: Icons.point_of_sale, color: Colors.green, onTap: () => _navigateToPOS(context)),
                  _buildMenuCard(context, title: 'Reports', icon: Icons.assessment, color: Colors.orange, onTap: () => _navigateToReports(context)),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMenuCard(context, title: 'Products', icon: Icons.inventory_2, color: Colors.blue, onTap: () => _navigateToProducts(context)),
                  const SizedBox(height: 16),
                  _buildMenuCard(context, title: 'Point of Sale', icon: Icons.point_of_sale, color: Colors.green, onTap: () => _navigateToPOS(context)),
                  const SizedBox(height: 16),
                  _buildMenuCard(context, title: 'Reports', icon: Icons.assessment, color: Colors.orange, onTap: () => _navigateToReports(context)),
                ],
              ),
      ),
    );
  }

  void _navigateToProducts(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductManagementScreen()));
  }

  void _navigateToPOS(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const POSScreen()));
  }

  void _navigateToReports(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsScreen()));
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



