import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ampere_service.dart';

class DashboardAmpereWidget extends StatefulWidget {
  const DashboardAmpereWidget({super.key});

  @override
  State<DashboardAmpereWidget> createState() => _DashboardAmpereWidgetState();
}

class _DashboardAmpereWidgetState extends State<DashboardAmpereWidget> {
  double _currentAmpere = 0.0;
  StreamSubscription<double>? _ampereSubscription;

  @override
  void initState() {
    super.initState();
    _ampereSubscription = AmpereService.ampereStream.listen((ampere) {
      debugPrint('Ampere value received: $ampere'); // Debug print added
      setState(() {
        _currentAmpere = ampere;
      });
    });
  }

  @override
  void dispose() {
    _ampereSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ampere Spending',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current Ampere: ${_currentAmpere.toStringAsFixed(2)}A',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
