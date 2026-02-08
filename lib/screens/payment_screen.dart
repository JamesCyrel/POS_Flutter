import 'package:flutter/material.dart';
import '../helpers/responsive_helper.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.originalTotal,
    required this.discount,
    required this.grandTotal,
  });

  final double originalTotal;
  final double discount;
  final double grandTotal;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _customerGaveController = TextEditingController();

  double get _change {
    final customerGave = double.tryParse(_customerGaveController.text) ?? 0.0;
    final change = customerGave - widget.grandTotal;
    return change < 0 ? 0.0 : change;
  }

  @override
  void dispose() {
    _customerGaveController.dispose();
    super.dispose();
  }

  void _submitPayment() {
    final customerGave =
        double.tryParse(_customerGaveController.text.trim()) ?? 0.0;
    if (customerGave < widget.grandTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer payment is less than total'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context, customerGave);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveHelper.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: Padding(
        padding: EdgeInsets.all(isTablet ? 16 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Total (Original)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 12 : 10,
                vertical: isTablet ? 8 : 6,
              ),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total:',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context,
                          tabletSize: 16, phoneSize: 14),
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  Text(
                    '₱${widget.originalTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context,
                          tabletSize: 18, phoneSize: 16),
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 6 : 4),
            // Discount
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 12 : 10,
                vertical: isTablet ? 8 : 6,
              ),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Discount:',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context,
                          tabletSize: 16, phoneSize: 14),
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  Text(
                    '- ₱${widget.discount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context,
                          tabletSize: 18, phoneSize: 16),
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 6 : 4),
            // Grand Total
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 12 : 10,
                vertical: isTablet ? 10 : 8,
              ),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Grand Total:',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context,
                          tabletSize: 18, phoneSize: 16),
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  Text(
                    '₱${widget.grandTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context,
                          tabletSize: 22, phoneSize: 20),
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 16 : 12),
            TextField(
              controller: _customerGaveController,
              decoration: const InputDecoration(
                labelText: 'Customer Gave',
                border: OutlineInputBorder(),
                prefixText: '₱',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context,
                    tabletSize: 20, phoneSize: 18),
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: isTablet ? 16 : 12),
            Container(
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: _change >= 0 ? Colors.blue.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _change >= 0 ? Colors.blue : Colors.red,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Change:',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context,
                          tabletSize: 24, phoneSize: 20),
                      fontWeight: FontWeight.bold,
                      color: _change >= 0
                          ? Colors.blue.shade800
                          : Colors.red.shade800,
                    ),
                  ),
                  Text(
                    '₱${_change.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context,
                          tabletSize: 32, phoneSize: 26),
                      fontWeight: FontWeight.bold,
                      color: _change >= 0 ? Colors.blue : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              height: isTablet ? 60 : 50,
              child: ElevatedButton(
                onPressed: _submitPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'FINALIZE PAYMENT',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getFontSize(context,
                        tabletSize: 22, phoneSize: 16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
