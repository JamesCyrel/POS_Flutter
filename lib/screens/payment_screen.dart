import 'package:flutter/material.dart';
import '../helpers/responsive_helper.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.total,
  });

  final double total;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _customerGaveController =
      TextEditingController();

  double get _change {
    final customerGave = double.tryParse(_customerGaveController.text) ?? 0.0;
    final change = customerGave - widget.total;
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
    if (customerGave < widget.total) {
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
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize:
                          ResponsiveHelper.getFontSize(context, tabletSize: 24, phoneSize: 18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₱${widget.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize:
                          ResponsiveHelper.getFontSize(context, tabletSize: 36, phoneSize: 28),
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 24 : 16),
            TextField(
              controller: _customerGaveController,
              decoration: const InputDecoration(
                labelText: 'Customer Gave',
                border: OutlineInputBorder(),
                prefixText: '₱',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize:
                    ResponsiveHelper.getFontSize(context, tabletSize: 20, phoneSize: 16),
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: isTablet ? 16 : 12),
            Container(
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: _change > 0 ? Colors.green.shade50 : Colors.grey.shade200,
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
                    'Change',
                    style: TextStyle(
                      fontSize:
                          ResponsiveHelper.getFontSize(context, tabletSize: 20, phoneSize: 16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₱${_change.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize:
                          ResponsiveHelper.getFontSize(context, tabletSize: 24, phoneSize: 18),
                      fontWeight: FontWeight.bold,
                      color: _change > 0 ? Colors.green : Colors.grey,
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
                    fontSize:
                        ResponsiveHelper.getFontSize(context, tabletSize: 22, phoneSize: 16),
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

