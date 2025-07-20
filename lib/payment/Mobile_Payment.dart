import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class Mobile_Payment extends StatefulWidget {
  final Map<String, dynamic> package;
  final String portId;
  final String userId;
  final VoidCallback? onPaymentSuccess;

  const Mobile_Payment({
    super.key,
    required this.package,
    required this.portId,
    required this.userId,
    this.onPaymentSuccess,
  });

  @override
  State<Mobile_Payment> createState() => _Mobile_PaymentState();
}

class _Mobile_PaymentState extends State<Mobile_Payment> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cardNumberController = TextEditingController(text: '4242424242424242');
  final TextEditingController _expiryController = TextEditingController(text: '12/25');
  final TextEditingController _cvvController = TextEditingController(text: '123');
  final TextEditingController _nameController = TextEditingController(text: 'TEST USER');
  bool _isProcessing = false;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.teal[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPackageSummary(),
              const SizedBox(height: 24),
              const Text(
                'Payment Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cardNumberController,
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value!.length != 16 ? 'Enter 16-digit card number' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      decoration: const InputDecoration(
                        labelText: 'MM/YY',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => !RegExp(r'^\d{2}/\d{2}$').hasMatch(value!) 
                          ? 'Enter valid expiry' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.length != 3 ? 'Enter 3-digit CVV' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Cardholder Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value!.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[800],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isProcessing ? null : _processPayment,
                child: _isProcessing 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'PAY LKR ${widget.package['price']}',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageSummary() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            const Divider(height: 24),
            _buildSummaryRow('Package', widget.package['name']),
            _buildSummaryRow('Port ID', widget.portId),
            _buildSummaryRow('Duration', '${widget.package['duration']} mins'),
            const Divider(height: 24),
            _buildSummaryRow(
              'Total Amount',
              'LKR ${widget.package['price']}',
              isBold: true,
              isAmount: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, 
      {bool isBold = false, bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isAmount ? Colors.teal[800] : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isProcessing = true);

      try {
        // 1. Create payment record
        final paymentData = {
          'userId': widget.userId,
          'package': widget.package['name'],
          'amount': widget.package['price'],
          'portId': widget.portId,
          'timestamp': ServerValue.timestamp,
          'status': 'paid',
          'cardLast4': _cardNumberController.text.substring(12),
        };

        await _dbRef.child('payments').push().set(paymentData);

        // 2. Call the success callback
        if (widget.onPaymentSuccess != null) {
          widget.onPaymentSuccess!();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment failed: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }
}