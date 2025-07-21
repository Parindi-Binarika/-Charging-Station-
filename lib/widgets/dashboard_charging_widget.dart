import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../port_availability_service.dart'; // Use your actual service

class DashboardChargingWidget extends StatefulWidget {
  final VoidCallback? onChargingComplete;

  const DashboardChargingWidget({super.key, this.onChargingComplete});

  @override
  DashboardChargingWidgetState createState() => DashboardChargingWidgetState();
}

class DashboardChargingWidgetState extends State<DashboardChargingWidget> {
  bool isCharging = false;
  int remainingSeconds = 0;
  Timer? _timer;
  String? currentOrderId;
  String? currentPackageName;
  String? currentPortId;
  String?
  currentPortType; // Added to differentiate between mobile and EV charging

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Call this method when user selects a package
  void startCharging({
    required String orderId,
    required String packageName,
    required String portId,
    required int durationMinutes,
    required String portType, // Added portType to determine charging type
  }) {
    setState(() {
      currentOrderId = orderId;
      currentPackageName = packageName;
      currentPortId = portId;
      currentPortType = portType;
      remainingSeconds =
          portType == PortAvailabilityService.MOBILE_PORT
              ? durationMinutes * 60
              : 0; // Only set countdown for mobile charging
      isCharging = true;
    });

    if (portType == PortAvailabilityService.MOBILE_PORT) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingSeconds > 0) {
          remainingSeconds--;
        } else {
          _completeCharging();
          timer.cancel();
        }
      });
    });
  }

  Future<void> _completeCharging() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update order in Realtime Database
      if (currentOrderId != null) {
        await FirebaseDatabase.instance.ref('orders/${currentOrderId!}').update(
          {'status': 'Completed', 'completedAt': ServerValue.timestamp},
        );
      }

      // Release the charging port using the actual service
      if (currentPortId != null) {
        await PortAvailabilityService.releasePort(currentPortId!, user.uid);
      }

      // Reset state and hide widget after charging is complete
      setState(() {
        isCharging = false;
        remainingSeconds = 0;
        currentOrderId = null;
        currentPackageName = null;
        currentPortId = null;
        currentPortType = null;
      });

      widget.onChargingComplete?.call();

      if (mounted) {
        _showCompletionSnackBar();
      }
    } catch (e, st) {
      print("Error completing charging: $e");
      print("StackTrace: $st");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
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
              'Charging Complete! ${currentPackageName ?? "Package"} finished.',
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Method to cancel the charging session
  void cancelCharging() {
    setState(() {
      isCharging = false;
      remainingSeconds = 0;
      currentOrderId = null;
      currentPackageName = null;
      currentPortId = null;
      currentPortType = null;
    });

    _timer?.cancel();
    _timer = null;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Charging session canceled.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show the widget if charging is in progress AND (for mobile) countdown is running
    final isMobileCharging =
        currentPortType == PortAvailabilityService.MOBILE_PORT;

    // Hide widget if not charging, or if mobile charging and countdown is finished
    if (!isCharging || (isMobileCharging && remainingSeconds <= 0)) {
      return const SizedBox.shrink();
    }

    final showCountdown = isMobileCharging && remainingSeconds > 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4CA771),
            Color(0xFFCEE6BA),
          ], // fixed: #4CA771, #CEE6BA
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CA771).withOpacity(0.15),
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
                    if (currentPackageName != null)
                      Text(
                        currentPackageName!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (isMobileCharging)
                Text(
                  _formatTime(remainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isMobileCharging)
            LinearProgressIndicator(
              value:
                  remainingSeconds > 0
                      ? 1.0 -
                          (remainingSeconds / (remainingSeconds + (60 * 60)))
                      : 1.0,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          if (isMobileCharging) const SizedBox(height: 8),
          if (showCountdown)
            Text(
              '${((remainingSeconds > 0 ? 1.0 - (remainingSeconds / (remainingSeconds + (60 * 60))) : 1.0) * 100).toStringAsFixed(0)}% Complete',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          const SizedBox(height: 16),
          if (showCountdown)
            ElevatedButton.icon(
              icon: const Icon(Icons.cancel, color: Colors.white),
              label: const Text('Cancel Charging'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Cancel Charging'),
                        content: const Text(
                          'Are you sure you want to cancel this charging session?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('No'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Yes, Cancel'),
                          ),
                        ],
                      ),
                );
                if (confirm == true) {
                  await _cancelCharging();
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _cancelCharging() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (currentOrderId != null) {
        await FirebaseDatabase.instance.ref('orders/$currentOrderId').update({
          'status': 'Cancelled',
          'cancelledAt': ServerValue.timestamp,
        });
      }

      if (currentPortId != null) {
        await PortAvailabilityService.releasePort(currentPortId!, user.uid);
      }

      setState(() {
        isCharging = false;
        currentOrderId = null;
        currentPackageName = null;
        currentPortId = null;
      });

      widget.onChargingComplete?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Charging session canceled.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, st) {
      print("Error canceling charging: $e");
      print("StackTrace: $st");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error canceling charging: $e')));
      }
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSecs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';
  }
}
