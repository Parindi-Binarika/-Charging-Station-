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
      // Safely get duration with fallback to 60 minutes
      final duration = _parseDuration(package['duration']);

      // Convert package to Map<String, dynamic> with string keys
      final safePackage =
          package is Map<String, dynamic>
              ? package
              : Map<String, dynamic>.fromEntries(
                (package as Map).entries.map(
                  (e) => MapEntry(e.key.toString(), e.value),
                ),
              );

      // Create order data with type-safe values
      final orderData = {
        'userId': userId,
        'packageName': safePackage['name']?.toString() ?? 'Unknown Package',
        'portType': portType,
        'portId': portId,
        'status': 'Active',
        'startTime': ServerValue.timestamp,
        'durationMinutes': duration,
        'createdAt': ServerValue.timestamp,
      };

      final orderRef = _database.ref('orders').push();
      await orderRef.set(orderData);

      // Get a safe order ID
      final safeOrderId = orderRef.key ?? '';

      // Start charging if widget is available
      if (chargingWidgetKey?.currentState != null &&
          chargingWidgetKey?.currentState?.mounted == true) {
        chargingWidgetKey?.currentState?.startCharging(
          orderId: safeOrderId,
          packageName: safePackage['name']?.toString() ?? 'Unknown Package',
          portId: portId,
          portType: portType,
          durationMinutes: duration,
        );
      } else {
        debugPrint('Charging widget not available or not mounted');
      }

      return {'orderId': safeOrderId, 'portId': portId, 'duration': duration};
    } catch (e, stackTrace) {
      debugPrint('Error starting charging session: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  static Future<bool> completeChargingSession({
    required String orderId,
    required String portId,
  }) async {
    try {
      if (orderId.isEmpty) {
        debugPrint('Invalid orderId provided');
        return false;
      }

      await _database.ref('orders/$orderId').update({
        'status': 'Completed',
        'completedAt': ServerValue.timestamp,
      });

      await port_service.PortAvailabilityService.releasePort(portId, '');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error completing charging session: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  // Helper method to safely parse duration
  static int _parseDuration(dynamic duration) {
    try {
      if (duration is int) return duration;
      if (duration is double) return duration.toInt();
      if (duration is String) return int.tryParse(duration) ?? 60;
      return 60;
    } catch (e) {
      debugPrint('Error parsing duration: $e');
      return 60;
    }
  }

  // Helper method to safely convert Firebase data
  static Map<String, dynamic> safeCastMap(dynamic data) {
    try {
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {};
    } catch (e) {
      debugPrint('Error casting map: $e');
      return {};
    }
  }
}
