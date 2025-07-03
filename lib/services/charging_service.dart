import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../widgets/dashboard_charging_widget.dart';
import '../port_availability_service.dart' as port_service;

class ChargingService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  static Future<Map<String, dynamic>?> startChargingSession({
    required String userId,
    required Map<String, dynamic> package,
    required String portId,
    required String portType,
    required GlobalKey<DashboardChargingWidgetState>? chargingWidgetKey,
  }) async {
    try {
      final duration = package['duration'] ?? 60;

      final orderData = {
        'userId': userId,
        'packageName': package['name'],
        'portType': portType,
        'portId': portId,
        'status': 'Active',
        'startTime': ServerValue.timestamp,
        'durationMinutes': duration,
        'createdAt': ServerValue.timestamp,
      };

      final orderRef = _database.ref('orders').push();
      await orderRef.set(orderData);

      chargingWidgetKey?.currentState?.startCharging(
        orderId: orderRef.key!,
        packageName: package['name'],
        portId: portId,
        durationMinutes: duration,
      );

      return {'orderId': orderRef.key!, 'portId': portId, 'duration': duration};
    } catch (e) {
      print('Error starting charging session: $e');
      return null;
    }
  }

  static Future<bool> completeChargingSession({
    required String orderId,
    required String portId,
  }) async {
    try {
      await _database.ref('orders/$orderId').update({
        'status': 'Completed',
        'completedAt': ServerValue.timestamp,
      });

      await port_service.PortAvailabilityService.releasePort(portId, '');
      return true;
    } catch (e) {
      print('Error completing charging session: $e');
      return false;
    }
  }
}
