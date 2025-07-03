import 'dart:async';
import 'package:appnew/services/charging_service.dart';
import 'package:flutter/material.dart';
import '../port_availability_service.dart' as port_service;

class DashboardChargingWidget extends StatefulWidget {
  final VoidCallback? onChargingComplete;
  final GlobalKey<DashboardChargingWidgetState>? key;

  const DashboardChargingWidget({
    this.key,
    this.onChargingComplete,
  }) : super(key: key);

  @override
  DashboardChargingWidgetState createState() => DashboardChargingWidgetState();
}

class DashboardChargingWidgetState extends State<DashboardChargingWidget> {
  bool _isCharging = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  String? _currentOrderId;
  String? _currentPackageName;
  String? _currentPortId;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

void startCharging({
  required String orderId,
  required String packageName,
  required String portId,
  required int durationMinutes,
}) {
  
  setState(() {
    _currentOrderId = orderId;
    _currentPackageName = packageName;
    _currentPortId = portId;
    _remainingSeconds = durationMinutes * 60;
    _isCharging = true;
  });
  _startTimer();
}

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _completeCharging();
          timer.cancel();
        }
      });
    });
  }

  Future<void> _completeCharging() async {
    try {
      if (_currentOrderId != null && _currentPortId != null) {
        await ChargingService.completeChargingSession(
          orderId: _currentOrderId!,
          portId: _currentPortId!,
        );
      }

      setState(() {
        _isCharging = false;
        _currentOrderId = null;
        _currentPackageName = null;
        _currentPortId = null;
      });

      widget.onChargingComplete?.call();

      if (mounted) {
        _showCompletionSnackBar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing charging: $e')),
        );
      }
    }
  }

  void _showCompletionSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              '${_currentPackageName ?? 'Charging'} completed successfully!',
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSecs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCharging) return const SizedBox.shrink();

    final progress = _remainingSeconds > 0 
        ? 1.0 - (_remainingSeconds / (_remainingSeconds + (60 * 60))) 
        : 1.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C5C), Color(0xFF1A6B7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.ev_station, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Charging In Progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_currentPackageName != null)
                      Text(
                        _currentPackageName!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _formatTime(_remainingSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% Complete',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}