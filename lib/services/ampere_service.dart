import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../port_availability_service.dart' as port_service;

class AmpereService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();
  static StreamSubscription<DatabaseEvent>? _currentSubscription;

  static ValueNotifier<double> consumedAmpere = ValueNotifier<double>(0);
  static ValueNotifier<bool> isCharging = ValueNotifier<bool>(false);

  static String? _orderId;
  static String? _portId;
  static double _ampereLimit = 0.0;

  /// Starts a charging session based on ampere package
  static Future<void> startChargingSession({
    required String userId,
    required Map<String, dynamic> package,
    required String portId,
  }) async {
    try {
      final packageName = package['name']?.toString() ?? 'Unknown Package';
      final ampere = (package['ampere'] ?? 10).toDouble();
      _ampereLimit = ampere.toDouble();

      // Create order data
      final orderData = {
        'userId': userId,
        'packageName': packageName,
        'portType': port_service.PortAvailabilityService.EV_PORT,
        'portId': portId,
        'status': 'Active',
        'startTime': ServerValue.timestamp,
        'ampereLimit': ampere,
        'consumedAmpere': 0,
        'createdAt': ServerValue.timestamp,
      };

      final orderRef = _db.child('orders').push();
      await orderRef.set(orderData);

      _orderId = orderRef.key;
      _portId = portId;

      // Reset notifier values
      consumedAmpere.value = 0;
      isCharging.value = true;

      // Listen ampere sensor
      _listenCurrentSensor();
    } catch (e, st) {
      debugPrint('AmpereService startChargingSession error: $e\n$st');
      rethrow;
    }
  }

  /// Internal method to listen current sensor readings from Firebase RTDB
  static void _listenCurrentSensor() {
    _currentSubscription?.cancel();

    // Path where current sensor writes its data, replace as per your node
    final sensorRef = _db.child('current_sensor_readings/instance1');

    _currentSubscription = sensorRef.onValue.listen((event) async {
      final val = event.snapshot.value;
      debugPrint('Ampere value updated: $val'); // Debug print added
      if (val == null) return;

      double currentAmpere = 0.0;
      // Parse ampere from snapshot value, expect a number, adjust if your data differs
      if (val is num) {
        currentAmpere = val.toDouble();
      } else if (val is Map && val.containsKey('ampere')) {
        currentAmpere = (val['ampere'] as num).toDouble();
      }

      // Accumulate ampere (simulate total consumed ampere by integrating over time)
      // Here, we assume sensor updates every second and gives instantaneous ampere.
      // For demonstration: Increase consumedAmpere by currentAmpere * deltaTime (e.g., seconds)
      // To keep simple, just add currentAmpere assuming each event = 1 second interval
      consumedAmpere.value += currentAmpere;

      if (consumedAmpere.value >= _ampereLimit) {
        // End charging session automatically
        await stopChargingSession();
      }

      // Update order in RTDB
      if (_orderId != null) {
        await _db.child('orders/$_orderId').update({
          'consumedAmpere': consumedAmpere.value,
          'updatedAt': ServerValue.timestamp,
        });
      }
    });
  }

  /// Stops charging session, marks order complete, releases port, cancels subscription
  static Future<void> stopChargingSession() async {
    if (!isCharging.value) return;

    isCharging.value = false;

    try {
      if (_orderId != null) {
        await _db.child('orders/$_orderId').update({
          'status': 'Completed',
          'completedAt': ServerValue.timestamp,
        });
      }
      if (_portId != null) {
        await port_service.PortAvailabilityService.releasePort(_portId!, '');
      }
    } catch (e, st) {
      debugPrint('AmpereService stopChargingSession error: $e\n$st');
    }

    await _currentSubscription?.cancel();
    _currentSubscription = null;

    _orderId = null;
    _portId = null;
    _ampereLimit = 0;
    consumedAmpere.value = 0;
  }

  /// Cancel charging session manually
  static Future<void> cancelChargingSession() async {
    isCharging.value = false;

    try {
      if (_orderId != null) {
        await _db.child('orders/$_orderId').update({
          'status': 'Cancelled',
          'cancelledAt': ServerValue.timestamp,
        });
      }
      if (_portId != null) {
        await port_service.PortAvailabilityService.releasePort(_portId!, '');
      }
    } catch (e) {
      debugPrint('AmpereService cancelChargingSession error: $e');
    }

    await _currentSubscription?.cancel();
    _currentSubscription = null;

    _orderId = null;
    _portId = null;
    _ampereLimit = 0;
    consumedAmpere.value = 0;
  }

  static final StreamController<double> _ampereController =
      StreamController<double>.broadcast();
  static Timer? _timer;

  static Stream<double> get ampereStream => _ampereController.stream;

  static void startAmpereDetection(double initialAmpere) {
    double currentAmpere = initialAmpere;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Simulate ampere spending (decrease over time)
      currentAmpere = currentAmpere > 0 ? currentAmpere - 0.1 : 0;
      _ampereController.add(currentAmpere);

      if (currentAmpere <= 0) {
        stopAmpereDetection();
      }
    });
  }

  static void stopAmpereDetection() {
    _timer?.cancel();
    _ampereController.close();
  }

  /// method to add the current sensor node to Firebase
  static Future<void> addCurrentSensorNode() async {
    try {
      await _db.child('current_sensor_readings/instance1').set({'ampere': 5});
      debugPrint('Node added successfully!');
    } catch (e) {
      debugPrint('Error adding current sensor node: $e');
    }
  }
}
