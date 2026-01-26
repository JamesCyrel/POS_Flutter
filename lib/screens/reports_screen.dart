import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  // Date range (default: today)
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  // Report type: 'daily', 'weekly', 'monthly', 'custom'
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

  /// Load reports based on selected type and date range
  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    String startDate;
    String endDate;

    if (_reportType == 'daily') {
      startDate = DateFormat('yyyy-MM-dd').format(_startDate);
      endDate = startDate;
    } else if (_reportType == 'weekly') {
      // Get start of week (Monday)
      final startOfWeek =
          _startDate.subtract(Duration(days: _startDate.weekday - 1));
      // Get end of week (Sunday)
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      startDate = DateFormat('yyyy-MM-dd').format(startOfWeek);
      endDate = DateFormat('yyyy-MM-dd').format(endOfWeek);
    } else if (_reportType == 'monthly') {
      // Get start of month
      final startOfMonth = DateTime(_startDate.year, _startDate.month, 1);
      // Get end of month
      final endOfMonth = DateTime(_startDate.year, _startDate.month + 1, 0);
      startDate = DateFormat('yyyy-MM-dd').format(startOfMonth);
      endDate = DateFormat('yyyy-MM-dd').format(endOfMonth);
    } else {
      // Custom date range
      startDate = DateFormat('yyyy-MM-dd').format(_startDate);
      endDate = DateFormat('yyyy-MM-dd').format(_endDate);
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

  /// Show date range picker
  Future<void> _selectDateRange() async {
    if (_reportType == 'custom') {
      // Show custom date range picker
      final pickedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.blue,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedRange != null) {
        setState(() {
          _startDate = pickedRange.start;
          _endDate = pickedRange.end;
        });
        _loadReports();
      }
    } else {
      // Show single date picker for daily/weekly/monthly
      final picked = await showDatePicker(
        context: context,
        initialDate: _startDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDatePickerMode:
            _reportType == 'monthly' ? DatePickerMode.year : DatePickerMode.day,
      );

      if (picked != null) {
        setState(() {
          _startDate = picked;
          _endDate = picked;
        });
        _loadReports();
      }
    }
  }

  /// Get date range display text
  String _getDateRangeText() {
    if (_reportType == 'daily') {
      return DateFormat('MMM dd, yyyy').format(_startDate);
    } else if (_reportType == 'weekly') {
      final startOfWeek =
          _startDate.subtract(Duration(days: _startDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return '${DateFormat('MMM dd').format(startOfWeek)} - ${DateFormat('MMM dd, yyyy').format(endOfWeek)}';
    } else if (_reportType == 'monthly') {
      return DateFormat('MMMM yyyy').format(_startDate);
    } else {
      // Custom range
      if (_startDate.year == _endDate.year &&
          _startDate.month == _endDate.month &&
          _startDate.day == _endDate.day) {
        return DateFormat('MMM dd, yyyy').format(_startDate);
      }
      return '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}';
    }
  }

  /// Export report to Excel
  Future<void> _exportToExcel() async {
    if (_sales.isEmpty && _productsSold.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading dialog
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
                Text('Generating Excel file...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Get date range info
      String startDate;
      String endDate;
      String reportTitle;

      if (_reportType == 'daily') {
        startDate = DateFormat('yyyy-MM-dd').format(_startDate);
        endDate = startDate;
        reportTitle =
            'Daily Report - ${DateFormat('MMM dd, yyyy').format(_startDate)}';
      } else if (_reportType == 'weekly') {
        final startOfWeek =
            _startDate.subtract(Duration(days: _startDate.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        startDate = DateFormat('yyyy-MM-dd').format(startOfWeek);
        endDate = DateFormat('yyyy-MM-dd').format(endOfWeek);
        reportTitle =
            'Weekly Report - ${DateFormat('MMM dd, yyyy').format(startOfWeek)} to ${DateFormat('MMM dd, yyyy').format(endOfWeek)}';
      } else if (_reportType == 'monthly') {
        final startOfMonth = DateTime(_startDate.year, _startDate.month, 1);
        final endOfMonth = DateTime(_startDate.year, _startDate.month + 1, 0);
        startDate = DateFormat('yyyy-MM-dd').format(startOfMonth);
        endDate = DateFormat('yyyy-MM-dd').format(endOfMonth);
        reportTitle =
            'Monthly Report - ${DateFormat('MMMM yyyy').format(_startDate)}';
      } else {
        // Custom range
        startDate = DateFormat('yyyy-MM-dd').format(_startDate);
        endDate = DateFormat('yyyy-MM-dd').format(_endDate);
        reportTitle =
            'Custom Report - ${DateFormat('MMM dd, yyyy').format(_startDate)} to ${DateFormat('MMM dd, yyyy').format(_endDate)}';
      }

      // Create Excel file
      final excel = Excel.createExcel();
      excel.delete('Sheet1'); // Delete default sheet

      // Sheet 1: Summary
      final summarySheetName =
          reportTitle.length > 31 ? 'Summary' : reportTitle;
      final summarySheet = excel[summarySheetName];
      summarySheet.appendRow(['Sales Report Summary']);
      summarySheet.appendRow([]);
      summarySheet.appendRow(['Report Type:', _reportType.toUpperCase()]);
      summarySheet.appendRow(['Date Range:', '$startDate to $endDate']);
      summarySheet.appendRow([
        'Generated:',
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())
      ]);
      summarySheet.appendRow([]);
      summarySheet
          .appendRow(['Total Sales:', '₱${_totalSales.toStringAsFixed(2)}']);
      summarySheet.appendRow(['Total Transactions:', '${_sales.length}']);
      summarySheet.appendRow(['Products Sold:', '${_productsSold.length}']);

      // Sheet 2: Sales Transactions
      final salesSheet = excel['Sales Transactions'];
      salesSheet.appendRow(['Sales Transactions']);
      salesSheet.appendRow([]);
      salesSheet.appendRow(['Sale ID', 'Date', 'Total Amount (₱)']);

      for (final sale in _sales) {
        salesSheet.appendRow([
          sale['id'],
          sale['date'],
          (sale['total'] as num).toStringAsFixed(2),
        ]);
      }

      salesSheet.appendRow([]);
      salesSheet
          .appendRow(['Total:', '', '₱${_totalSales.toStringAsFixed(2)}']);

      // Sheet 3: Products Sold
      final productsSheet = excel['Products Sold'];
      productsSheet.appendRow(['Products Sold']);
      productsSheet.appendRow([]);
      productsSheet.appendRow(
          ['Product Name', 'Barcode', 'Quantity', 'Total Revenue (₱)']);

      for (final product in _productsSold) {
        productsSheet.appendRow([
          product['name'] as String,
          product['barcode'] ?? 'N/A',
          product['total_quantity'],
          (product['total_revenue'] as num).toStringAsFixed(2),
        ]);
      }

      // Get Downloads directory path
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        // For Android, use external storage Downloads folder
        final externalStorageDir = await getExternalStorageDirectory();
        if (externalStorageDir != null) {
          // Navigate to Downloads folder
          final downloadsPath = '/storage/emulated/0/Download';
          downloadsDir = Directory(downloadsPath);

          // If that doesn't exist, try alternative path
          if (!await downloadsDir.exists()) {
            final altPath = '${externalStorageDir.parent.path}/Download';
            downloadsDir = Directory(altPath);
          }

          // Create directory if it doesn't exist
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
        }
      }

      // Fallback to app documents if Downloads not available
      if (downloadsDir == null || !await downloadsDir.exists()) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      // Generate filename with date range
      final dateStr = _reportType == 'custom'
          ? '${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}'
          : DateFormat('yyyyMMdd').format(_startDate);
      final fileName = 'Sales_Report_${_reportType}_$dateStr.xlsx';
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);

      // Save Excel file
      final excelBytes = excel.save();
      if (excelBytes != null) {
        await file.writeAsBytes(excelBytes);
      }

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show success message with file location
      if (mounted) {
        final isDownloads = downloadsDir.path.contains('Download');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Excel file saved successfully!'),
                const SizedBox(height: 4),
                Text(
                  isDownloads
                      ? 'Location: Downloads/$fileName'
                      : 'File: $fileName',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () async {
                await Share.shareXFiles(
                  [XFile(filePath)],
                  text: reportTitle,
                  subject: 'Sales Report Export',
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting Excel: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
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
                          const SizedBox(width: 8),
                          _buildReportTypeButton('custom', 'Custom Range'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Date selector and Export button
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
                            onPressed: _selectDateRange,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _getDateRangeText(),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _exportToExcel,
                            icon: const Icon(Icons.download),
                            label: const Text('Export Excel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
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
