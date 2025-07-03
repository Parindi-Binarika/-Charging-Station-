import 'package:firebase_database/firebase_database.dart';

class PortAvailabilityService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static const String _portsNode = 'charging_ports';

  static const String MOBILE_PORT = 'mobile';
  static const String EV_PORT = 'ev';

  // Initialize ports in Realtime Database (call this once when setting up the system)
  static Future<void> initializePorts() async {
    try {
      final portsRef = _database.ref(_portsNode);

      final ports = [
        {
          'id': 'mobile_port_1',
          'type': MOBILE_PORT,
          'name': 'Mobile Charging Port 1',
        },
        {
          'id': 'mobile_port_2',
          'type': MOBILE_PORT,
          'name': 'Mobile Charging Port 2',
        },
        {'id': 'ev_port_1', 'type': EV_PORT, 'name': 'EV Charging Port 1'},
      ];

      for (final port in ports) {
        final doc = await portsRef.child(port['id']!).get();
        if (!doc.exists) {
          await portsRef.child(port['id']!).set({
            'id': port['id'],
            'type': port['type'],
            'name': port['name'],
            'isAvailable': true,
            'currentUserId': null,
            'currentPackage': null,
            'sessionStartTime': null,
            'createdAt': ServerValue.timestamp,
          });
        }
      }
    } catch (e) {
      print('Error initializing ports: $e');
      rethrow;
    }
  }

  // Alternative method to force recreate ports (use this if you need to reset)
  static Future<void> forceInitializePorts() async {
    try {
      final portsRef = _database.ref(_portsNode);

      final ports = [
        {
          'id': 'mobile_port_1',
          'type': MOBILE_PORT,
          'name': 'Mobile Charging Port 1',
        },
        {
          'id': 'mobile_port_2',
          'type': MOBILE_PORT,
          'name': 'Mobile Charging Port 2',
        },
        {'id': 'ev_port_1', 'type': EV_PORT, 'name': 'EV Charging Port 1'},
      ];

      for (final port in ports) {
        await portsRef.child(port['id']!).set({
          'id': port['id'],
          'type': port['type'],
          'name': port['name'],
          'isAvailable': true,
          'currentUserId': null,
          'currentPackage': null,
          'sessionStartTime': null,
          'createdAt': ServerValue.timestamp,
        });
      }
    } catch (e) {
      print('Error force initializing ports: $e');
      rethrow;
    }
  }

  // Get port availability status with error handling
  static Stream<DatabaseEvent> getPortsStream() {
    return _database.ref(_portsNode).onValue;
  }

  // Get specific port type availability with error handling
  static Stream<DatabaseEvent> getPortsByTypeStream(String portType) {
    return _database
        .ref(_portsNode)
        .orderByChild('type')
        .equalTo(portType)
        .onValue;
  }

  // Check if any port of specific type is available
  static Future<bool> isPortTypeAvailable(String portType) async {
    final snapshot =
        await _database
            .ref(_portsNode)
            .orderByChild('type')
            .equalTo(portType)
            .get();
    if (!snapshot.exists) return false;
    final ports = snapshot.children;
    return ports.any((port) => port.child('isAvailable').value == true);
  }

  // Get available port of specific type
  static Future<DataSnapshot?> getAvailablePort(String portType) async {
    final snapshot =
        await _database
            .ref(_portsNode)
            .orderByChild('type')
            .equalTo(portType)
            .get();
    if (!snapshot.exists) return null;
    for (final port in snapshot.children) {
      if (port.child('isAvailable').value == true) {
        return port;
      }
    }
    return null;
  }

  // Reserve a port for charging
  static Future<String?> reservePort(
    String portType,
    String userId,
    String packageName,
  ) async {
    final availablePort = await getAvailablePort(portType);
    if (availablePort == null) return null;
    final portId = availablePort.child('id').value as String;

    // Update port status
    await _database.ref('$_portsNode/$portId').update({
      'isAvailable': false,
      'currentUserId': userId,
      'currentPackage': packageName,
      'sessionStartTime': ServerValue.timestamp,
    });

    return portId;
  }

  // Release a port after charging is complete
  static Future<bool> releasePort(String portId, String userId) async {
    try {
      // No authentication/user check needed with open rules
      await _database.ref('$_portsNode/$portId').update({
        'isAvailable': true,
        'currentUserId': null,
        'currentPackage': null,
        'sessionStartTime': null,
      });

      return true;
    } catch (e) {
      print('Error releasing port: $e');
      return false;
    }
  }

  // Get port details by ID
  static Future<DataSnapshot?> getPortById(String portId) async {
    final doc = await _database.ref('$_portsNode/$portId').get();
    return doc.exists ? doc : null;
  }

  // Returns true if the user has an active order (charging session)
  static Future<bool> hasActiveSession(String userId) async {
    final snapshot =
        await FirebaseDatabase.instance
            .ref('orders')
            .orderByChild('userId')
            .equalTo(userId)
            .get();
    if (!snapshot.exists) return false;
    for (final child in snapshot.children) {
      final data = Map<String, dynamic>.from(child.value as Map);
      if (data['status'] == 'Active' || data['status'] == 'Charging Started') {
        return true;
      }
    }
    return false;
  }

  // Returns the DataSnapshot of the user's active order, or null if none
  static Future<DataSnapshot?> getUserActiveSession(String userId) async {
    final snapshot =
        await FirebaseDatabase.instance
            .ref('orders')
            .orderByChild('userId')
            .equalTo(userId)
            .get();
    if (!snapshot.exists) return null;
    for (final child in snapshot.children) {
      final data = Map<String, dynamic>.from(child.value as Map);
      if (data['status'] == 'Active' || data['status'] == 'Charging Started') {
        return child;
      }
    }
    return null;
  }
}
