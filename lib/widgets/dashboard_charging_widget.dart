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
  }) {
    final int safeDuration =
        durationMinutes is int
            ? durationMinutes
            : int.tryParse(durationMinutes.toString()) ?? 60;
    setState(() {
      isCharging = true;
      remainingSeconds = safeDuration * 60;
      currentOrderId = orderId;
      currentPackageName = packageName;
      currentPortId = portId;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingSeconds > 0) {
          remainingSeconds--;
        } else {
          isCharging = false;
          timer.cancel();
          _completeCharging();
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

      // Reset state
      setState(() {
        currentOrderId = null;
        currentPackageName = null;
        currentPortId = null;
      });

      widget.onChargingComplete?.call();

      if (mounted) {
        _showCompletionSnackBar();
      }
    } catch (e) {
      print("Error completing charging: $e");
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

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSecs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!isCharging) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
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
                      'Charging in Progress',
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
              Text(
                formatTime(remainingSeconds),
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
            value:
                remainingSeconds > 0
                    ? (60 - remainingSeconds) /
                        60 // Assuming 1 minute for development
                    : 1.0,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '${remainingSeconds > 0 ? ((60 - remainingSeconds) / 60 * 100).toInt() : 100}% Complete',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
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
                await cancelCharging();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> cancelCharging() async {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error canceling charging: $e')));
      }
    }
  }
}
