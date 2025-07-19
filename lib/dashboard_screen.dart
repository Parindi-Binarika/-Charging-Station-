import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'history_screen.dart';
import 'packages_screen.dart';
import 'ev_package_screen.dart';
import 'ev_history_screen.dart';
import 'chart_view_screen.dart';
import 'ev_chart_screen.dart';
import 'login_screen.dart';
import 'port_availability_service.dart' as port_service;
import 'port_status_widget.dart';

// Mobile charging session widget
import 'widgets/dashboard_charging_widget.dart';
// EV charging session widget
import 'widgets/dashboard_ampere_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  // GlobalKey for Mobile Charging Widget
  final GlobalKey<DashboardChargingWidgetState> chargingWidgetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    port_service.PortAvailabilityService.initializePorts();
    _checkActiveSession();
  }

  Future<void> _checkActiveSession() async {
    if (currentUserId == null) return;

    try {
      final snapshot =
          await FirebaseDatabase.instance
              .ref('orders')
              .orderByChild('userId')
              .equalTo(currentUserId)
              .once();

      final data = snapshot.snapshot.value;
      if (data == null) return;

      final orders = _safeCastToMap(data);
      if (orders.isEmpty) return;

      final activeOrderEntry = orders.entries.firstWhere((entry) {
        final order = _safeCastToMap(entry.value);
        return order['status'] == 'Active' ||
            order['status'] == 'Charging Started';
      }, orElse: () => MapEntry('', null));

      if (activeOrderEntry.key != null &&
          chargingWidgetKey.currentState != null) {
        final order = _safeCastToMap(activeOrderEntry.value);
        chargingWidgetKey.currentState!.startCharging(
          orderId: activeOrderEntry.key!,
          packageName: order['packageName']?.toString() ?? '',
          portId: order['portId']?.toString() ?? '',
          durationMinutes: (order['durationMinutes'] as num?)?.toInt() ?? 0,
          portType: order['portType']?.toString() ?? '',
        );
      }
    } catch (e) {
      debugPrint('Error checking active session: $e');
    }
  }

  Map<String, dynamic> _safeCastToMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<dynamic, dynamic>) {
      return value.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  List<Widget> get _pages => [
    _DashboardHomeScreen(chargingWidgetKey: chargingWidgetKey),
    PackagesScreen(chargingWidgetKey: chargingWidgetKey),
    const HistoryScreen(),
    const ChartViewScreen(),
    EVPackageScreen(chargingWidgetKey: chargingWidgetKey),
    const EVHistoryScreen(),
    const EVChartScreen(),
  ];

  final List<String> _titles = [
    "Dashboard",
    "Select Mobile Charging Package",
    "Mobile Charging History",
    "Mobile Charging Chart",
    "Select EV Charging Package",
    "EV Charging History",
    "EV Charging Chart",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F4C5C),
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.teal[800],
        elevation: 0,
        actions: [
          if (currentUserId != null)
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 5)).asyncMap(
                (_) =>
                    port_service.PortAvailabilityService.getUserActiveSession(
                      currentUserId!,
                    ),
              ),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final data = snapshot.data;
                  if (data != null && data.value != null) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Charging',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal[800]),
              child: const Text(
                'Smart Charging Station',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _drawerItem(icon: Icons.dashboard, text: 'Dashboard', index: 0),
            const Divider(),
            _drawerItem(
              icon: Icons.bolt,
              text: 'Select Mobile Charging Package',
              index: 1,
            ),
            _drawerItem(
              icon: Icons.history,
              text: 'Mobile Charging History',
              index: 2,
            ),
            _drawerItem(
              icon: Icons.bar_chart,
              text: 'Mobile Charging Chart',
              index: 3,
            ),
            const Divider(),
            _drawerItem(
              icon: Icons.electric_car,
              text: 'Select EV Charging Package',
              index: 4,
            ),
            _drawerItem(
              icon: Icons.ev_station,
              text: 'EV Charging History',
              index: 5,
            ),
            _drawerItem(
              icon: Icons.insights,
              text: 'EV Charging Chart',
              index: 6,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // For EV Charging Status (ampere-based)
          const DashboardAmpereWidget(),
          // For Mobile Charging Status
          DashboardChargingWidget(
            key: chargingWidgetKey,
            onChargingComplete: () {
              setState(() {});
            },
          ),
          // Main content
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String text,
    required int index,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: _selectedIndex == index ? Colors.teal[800] : null,
      ),
      title: Text(text),
      selected: _selectedIndex == index,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        Navigator.pop(context);
      },
    );
  }
}

class _DashboardHomeScreen extends StatelessWidget {
  final GlobalKey<DashboardChargingWidgetState> chargingWidgetKey;

  const _DashboardHomeScreen({required this.chargingWidgetKey});

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal[700]!, Colors.teal[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to Smart Charging Station',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor port availability and manage your charging sessions',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Port Availability',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const PortStatusWidget(
            portType: port_service.PortAvailabilityService.MOBILE_PORT,
            displayName: 'Mobile Charging Ports',
          ),
          const PortStatusWidget(
            portType: port_service.PortAvailabilityService.EV_PORT,
            displayName: 'EV Charging Ports',
          ),
          const SizedBox(height: 24),
          if (currentUserId != null)
            StreamBuilder(
              stream:
                  FirebaseDatabase.instance
                      .ref('orders')
                      .orderByChild('userId')
                      .equalTo(currentUserId)
                      .onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const SizedBox.shrink();
                }

                try {
                  final data = _safeCastToMap(snapshot.data!.snapshot.value);
                  final activeOrders =
                      data.entries.where((entry) {
                        final order = _safeCastToMap(entry.value);
                        return order['status'] == 'Active' ||
                            order['status'] == 'Charging Started';
                      }).toList();

                  if (activeOrders.isEmpty) return const SizedBox.shrink();

                  final order = _safeCastToMap(activeOrders.first.value);
                  final orderId = activeOrders.first.key;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Charging Order',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha((0.1 * 255).toInt()),
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  order['portType'] ==
                                          port_service
                                              .PortAvailabilityService
                                              .MOBILE_PORT
                                      ? Icons.smartphone
                                      : Icons.electric_car,
                                  color: Colors.orange,
                                  size: 30,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Port: ${order['portId']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Package: ${order['packageName'] ?? order['package'] ?? ""}',
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(
                                            (0.8 * 255).toInt(),
                                          ),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Stop Charging'),
                                        content: const Text(
                                          'Are you sure you want to stop the current charging session?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: const Text('Stop Charging'),
                                          ),
                                        ],
                                      ),
                                );

                                if (confirmed == true) {
                                  await FirebaseDatabase.instance
                                      .ref('orders/$orderId')
                                      .update({
                                        'status': 'Completed',
                                        'completedAt': ServerValue.timestamp,
                                      });

                                  await port_service
                                      .PortAvailabilityService.releasePort(
                                    order['portId'],
                                    currentUserId,
                                  );

                                  chargingWidgetKey.currentState
                                      ?.cancelCharging();

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Charging session stopped successfully',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Stop Charging'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } catch (e) {
                  debugPrint('Error building active orders widget: $e');
                  return const SizedBox.shrink();
                }
              },
            ),
          const SizedBox(height: 24),
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.smartphone,
                  title: 'Mobile Charging',
                  subtitle: 'Select mobile package',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => PackagesScreen(
                              chargingWidgetKey: chargingWidgetKey,
                            ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.electric_car,
                  title: 'EV Charging',
                  subtitle: 'Select EV package',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => EVPackageScreen(
                              chargingWidgetKey: chargingWidgetKey,
                            ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _safeCastToMap(dynamic value) {
    if (value == null) return {};

    if (value is Map<dynamic, dynamic>) {
      return value.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.1 * 255).toInt()),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.teal[800]),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
