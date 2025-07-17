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

    // Start real-time watts monitoring from Firebase
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Charging Power',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Charging Power: ${_chargingWatts.toStringAsFixed(2)} W',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
