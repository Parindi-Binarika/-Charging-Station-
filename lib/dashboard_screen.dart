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
import 'widgets/dashboard_charging_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  final GlobalKey<DashboardChargingWidgetState> chargingWidgetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    port_service.PortAvailabilityService.initializePorts();
  }

  List<Widget> get _pages => [
    _DashboardHomeScreen(chargingWidgetKey: chargingWidgetKey),
    const PackagesScreen(),
    const HistoryScreen(),
    const ChartViewScreen(),
    const EVPackageScreen(),
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
          DashboardChargingWidget(key: chargingWidgetKey),
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
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.9 * 255).toInt()),
                    fontSize: 16,
                  ),
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
            FutureBuilder(
              future:
                  FirebaseDatabase.instance
                      .ref('orders')
                      .orderByChild('userId')
                      .equalTo(currentUserId)
                      .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasData && snapshot.data != null) {
                  final snap = snapshot.data;
                  List<Map<String, dynamic>> activeOrders = [];
                  if (snap != null) {
                    for (final child in snap.children) {
                      final data = Map<String, dynamic>.from(
                        child.value as Map,
                      );
                      if (data['status'] == 'Active' ||
                          data['status'] == 'Charging Started') {
                        activeOrders.add({...data, 'id': child.key});
                      }
                    }
                  }
                  if (activeOrders.isEmpty) return const SizedBox.shrink();
                  final order = activeOrders.first;
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
                                  // Mark order as completed and release port
                                  await FirebaseDatabase.instance
                                      .ref('orders/${order['id']}')
                                      .update({
                                        'status': 'Completed',
                                        'completedAt': ServerValue.timestamp,
                                      });
                                  await port_service
                                      .PortAvailabilityService.releasePort(
                                    order['portId'],
                                    currentUserId,
                                  );

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
                }
                return const SizedBox.shrink();
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
