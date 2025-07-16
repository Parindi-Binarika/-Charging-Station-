import 'package:flutter/material.dart';

class EV_Payment extends StatefulWidget {
  final Map<String, dynamic> package;
  final String portId;
  final String userId;
  final VoidCallback? onPaymentSuccess;

  const EV_Payment({
    super.key,
    required this.package,
    required this.portId,
    required this.userId,
    this.onPaymentSuccess,
  });

  @override
  State<EV_Payment> createState() => _EV_PaymentState();
}

class _EV_PaymentState extends State<EV_Payment> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController(
    text: '12/25',
  );
  final TextEditingController _cvvController = TextEditingController(
    text: '123',
  );
  final TextEditingController _nameController = TextEditingController(
    text: 'TEST USER',
  );
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EV Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Package: ${widget.package['name']}'),
              Text('Ampere: ${widget.package['ampere']}A'),
              Text('Price: LKR ${widget.package['price']}'),
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
                validator:
                    (value) =>
                        value!.length != 16
                            ? 'Enter 16-digit card number'
                            : null,
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
                      validator:
                          (value) =>
                              !RegExp(r'^\d{2}/\d{2}$').hasMatch(value!)
                                  ? 'Enter valid expiry'
                                  : null,
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
                      validator:
                          (value) =>
                              value!.length != 3 ? 'Enter 3-digit CVV' : null,
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
                onPressed: _isProcessing ? null : _processPayment,
                child:
                    _isProcessing
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

  Future<void> _processPayment() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isProcessing = true);

      await Future.delayed(const Duration(seconds: 1)); // Simulate payment

      if (widget.onPaymentSuccess != null) {
        widget.onPaymentSuccess!();
      }
      setState(() => _isProcessing = false);
    }
  }
}
