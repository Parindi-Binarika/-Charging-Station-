import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ampere_service.dart';

class DashboardAmpereWidget extends StatefulWidget {
  const DashboardAmpereWidget({super.key});

  @override
  State<DashboardAmpereWidget> createState() => _DashboardAmpereWidgetState();
}

class _DashboardAmpereWidgetState extends State<DashboardAmpereWidget> {
  double _chargingWatts = 0.0;
  StreamSubscription<double>? _wattsSubscription;

  @override
  void initState() {
    super.initState();

    // Start real-time watts monitoring from Firebase .........
    AmpereService.startWattsMonitoring();

    _wattsSubscription = AmpereService.wattsStream.listen((watts) {
      setState(() {
        _chargingWatts = watts;
      });
    });
  }

  @override
  void dispose() {
    _wattsSubscription?.cancel();
    AmpereService.stopWattsMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFCEE6BA).withOpacity(0.85), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4CA771),
          width: 1.2,
        ), 
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CA771).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Charging Power',
            style: TextStyle(
              color: Color(0xFF013237), // #013237
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Charging Power: ${_chargingWatts.toStringAsFixed(2)} W',
            style: const TextStyle(
              color: Color(0xFF4CA771), 
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
