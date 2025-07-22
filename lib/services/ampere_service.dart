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

  static Future<void> startChargingSession({
    required String userId,
    required Map<String, dynamic> package,
    required String portId,
  }) async {
    try {
      final packageName = package['name']?.toString() ?? 'Unknown Package';
      final ampere = (package['ampere'] ?? 10).toDouble();
      _ampereLimit = ampere.toDouble();

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

      consumedAmpere.value = 0;
      isCharging.value = true;

      _listenCurrentSensor(); // simulate ampere charging
    } catch (e, st) {
      debugPrint('AmpereService startChargingSession error: $e\n$st');
      rethrow;
    }
  }

  static void _listenCurrentSensor() {
    _currentSubscription?.cancel();
    final sensorRef = _db.child('live_readings/chargingWatts');

    _currentSubscription = sensorRef.onValue.listen((event) async {
      final val = event.snapshot.value;
      debugPrint('Charging Watts value updated: $val');
      if (val == null) return;

      double currentWatts = 0.0;
      if (val is num) {
        currentWatts = val.toDouble();
      }

      // This assumes watts is used in place of ampere for simplification
      consumedAmpere.value += currentWatts;

      if (consumedAmpere.value >= _ampereLimit) {
        await stopChargingSession();
      }

      if (_orderId != null) {
        await _db.child('orders/$_orderId').update({
          'consumedAmpere': consumedAmpere.value,
          'updatedAt': ServerValue.timestamp,
        });
      }
    });
  }

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

  //  Real-time Charging Watts Monitoring for UI ..........

  static final StreamController<double> _wattsController =
      StreamController<double>.broadcast();
  static StreamSubscription<DatabaseEvent>? _wattsSubscription;

  static Stream<double> get wattsStream => _wattsController.stream;

  static void startWattsMonitoring() {
    final DatabaseReference wattsRef = _db.child('live_readings/chargingWatts');

    _wattsSubscription?.cancel();

    _wattsSubscription = wattsRef.onValue.listen((event) {
      final value = event.snapshot.value;
      if (value is num) {
        final watts = value.toDouble();
        debugPrint('Live Charging Watts: $watts');
        _wattsController.add(watts);
      } else {
        debugPrint('Invalid chargingWatts value: $value');
      }
    });
  }

  static void stopWattsMonitoring() {
    _wattsSubscription?.cancel();
    _wattsSubscription = null;
  }

  static Future<void> addDummyWattsValue() async {
    try {
      await _db.child('live_readings').set({'chargingWatts': 1540.75});
      debugPrint('Dummy watts value added!');
    } catch (e) {
      debugPrint('Error adding dummy watts: $e');
    }
  }
}
