import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../helpers/responsive_helper.dart';
import 'package:intl/intl.dart';

/// Reports Screen
/// Shows daily sales reports
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // Selected date (default: today)
  DateTime _selectedDate = DateTime.now();

  // Report type: 'daily', 'weekly', 'monthly'
  String _reportType = 'daily';

  // Sales data
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _productsSold = [];
  double _totalSales = 0.0;

  // Loading state
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  /// Load reports based on selected type and date
  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    String startDate;
    String endDate;

    if (_reportType == 'daily') {
      startDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      endDate = startDate;
    } else if (_reportType == 'weekly') {
      // Get start of week (Monday)
      final startOfWeek =
          _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      // Get end of week (Sunday)
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      startDate = DateFormat('yyyy-MM-dd').format(startOfWeek);
      endDate = DateFormat('yyyy-MM-dd').format(endOfWeek);
    } else {
      // monthly
      // Get start of month
      final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
      // Get end of month
      final endOfMonth =
          DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
      startDate = DateFormat('yyyy-MM-dd').format(startOfMonth);
      endDate = DateFormat('yyyy-MM-dd').format(endOfMonth);
    }

    // Get total sales
    final total = await DatabaseHelper.instance
        .getTotalSalesByDateRange(startDate, endDate);

    // Get all sales for the date range
    final sales =
        await DatabaseHelper.instance.getSalesByDateRange(startDate, endDate);

    // Get products sold
    final productsSold = await DatabaseHelper.instance
        .getProductsSoldInRange(startDate, endDate);

    setState(() {
      _totalSales = total;
      _sales = sales;
      _productsSold = productsSold;
      _isLoading = false;
    });
  }

  /// Build report type button
  Widget _buildReportTypeButton(String type, String label) {
    final isSelected = _reportType == type;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _reportType = type;
        });
        _loadReports();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey.shade300,
        foregroundColor: isSelected ? Colors.white : Colors.black,
      ),
      child: Text(label),
    );
  }

  /// Show date picker
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode:
          _reportType == 'monthly' ? DatePickerMode.year : DatePickerMode.day,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sales Reports',
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Report type and date selector
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Column(
                    children: [
                      // Report type selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildReportTypeButton('daily', 'Daily'),
                          const SizedBox(width: 8),
                          _buildReportTypeButton('weekly', 'Weekly'),
                          const SizedBox(width: 8),
                          _buildReportTypeButton('monthly', 'Monthly'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Date selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Date:',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _selectDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _reportType == 'daily'
                                  ? DateFormat('MMM dd, yyyy')
                                      .format(_selectedDate)
                                  : _reportType == 'weekly'
                                      ? 'Week of ${DateFormat('MMM dd, yyyy').format(_selectedDate)}'
                                      : DateFormat('MMMM yyyy')
                                          .format(_selectedDate),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Total sales card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Total Sales',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₱${_totalSales.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_sales.length} transaction(s)',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Products sold section
                Expanded(
                  child: ResponsiveHelper.isTablet(context)
                      ? Row(
                          children: [
                            // Sales transactions
                            Expanded(
                              child: _buildSalesTransactions(context),
                            ),
                            // Products sold
                            Expanded(
                              child: _buildProductsSold(context),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            // Sales transactions
                            Expanded(
                              child: _buildSalesTransactions(context),
                            ),
                            // Products sold
                            Expanded(
                              child: _buildProductsSold(context),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  /// Build sales transactions section
  Widget _buildSalesTransactions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Sales Transactions',
            style: TextStyle(
              fontSize: ResponsiveHelper.getFontSize(
                context,
                tabletSize: 22,
                phoneSize: 18,
              ),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _sales.isEmpty
              ? Center(
                  child: Text(
                    'No sales for this date',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(
                        context,
                        tabletSize: 18,
                        phoneSize: 16,
                      ),
                      color: Colors.grey,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.isTablet(context) ? 16 : 8,
                  ),
                  itemCount: _sales.length,
                  itemBuilder: (context, index) {
                    final sale = _sales[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          'Sale #${sale['id']}',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getFontSize(
                              context,
                              tabletSize: 18,
                              phoneSize: 16,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          sale['date'],
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getFontSize(
                              context,
                              tabletSize: 16,
                              phoneSize: 14,
                            ),
                          ),
                        ),
                        trailing: Text(
                          '₱${(sale['total'] as num).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getFontSize(
                              context,
                              tabletSize: 20,
                              phoneSize: 16,
                            ),
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Build products sold section
  Widget _buildProductsSold(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Products Sold',
            style: TextStyle(
              fontSize: ResponsiveHelper.getFontSize(
                context,
                tabletSize: 22,
                phoneSize: 18,
              ),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _productsSold.isEmpty
              ? Center(
                  child: Text(
                    'No products sold',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(
                        context,
                        tabletSize: 18,
                        phoneSize: 16,
                      ),
                      color: Colors.grey,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.isTablet(context) ? 16 : 8,
                  ),
                  itemCount: _productsSold.length,
                  itemBuilder: (context, index) {
                    final product = _productsSold[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          product['name'] as String,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getFontSize(
                              context,
                              tabletSize: 18,
                              phoneSize: 16,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: product['barcode'] != null
                            ? Text(
                                'Barcode: ${product['barcode']}',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getFontSize(
                                    context,
                                    tabletSize: 14,
                                    phoneSize: 12,
                                  ),
                                ),
                              )
                            : null,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Qty: ${product['total_quantity']}',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getFontSize(
                                  context,
                                  tabletSize: 16,
                                  phoneSize: 14,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₱${(product['total_revenue'] as num).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getFontSize(
                                  context,
                                  tabletSize: 16,
                                  phoneSize: 14,
                                ),
                                color: Colors.green,
                              ),
                            ),
                          ],
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
