import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'port_availability_service.dart' as port_service;
import 'package:appnew/payment/Mobile_Payment.dart';
import 'widgets/dashboard_charging_widget.dart';
import 'services/charging_service.dart';

class PackagesScreen extends StatefulWidget {
  final GlobalKey<DashboardChargingWidgetState>? chargingWidgetKey;
  const PackagesScreen({super.key, this.chargingWidgetKey});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isLoading = false;

  final List<Map<String, dynamic>> packages = [
    {
      'name': 'Basic Package',
      'price': 100,
      'duration': 1, //for developmemt, i keep this as 1 min.....
      'description': 'Perfect for quick charging sessions',
      'features': ['Fast charging', '1 hour duration', 'Standard support'],
    },
    {
      'name': 'Standard Package',
      'price': 250,
      'duration': 180, // 3 hours in minutes
      'description': 'Ideal for extended charging needs',
      'features': [
        'Fast charging',
        '3 hours duration',
        'Priority support',
        'Usage statistics',
      ],
    },
    {
      'name': 'Premium Package',
      'price': 500,
      'duration': 360, // 6 hours in minutes
      'description': 'Best value for long charging sessions',
      'features': [
        'Ultra-fast charging',
        '6 hours duration',
        '24/7 support',
        'Detailed analytics',
        'Booking priority',
      ],
    },
  ];

  Future<void> _selectPackage(Map<String, dynamic> package) async {
    if (currentUserId == null) {
      _showErrorDialog('Please log in to select a package.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check for active session
      final hasActive = await port_service
          .PortAvailabilityService.hasActiveSession(currentUserId!);
      if (hasActive) {
        _showErrorDialog('You already have an active charging session.');
        return;
      }

      // Check port availability
      final isAvailable = await port_service
          .PortAvailabilityService.isPortTypeAvailable(
        port_service.PortAvailabilityService.MOBILE_PORT,
      );

      if (!isAvailable) {
        _showErrorDialog('No mobile charging ports available.');
        return;
      }

      // Confirm selection
      final confirmed = await _showConfirmationDialog(package);
      if (!confirmed) return;

      // Reserve port
      final portId = await port_service.PortAvailabilityService.reservePort(
        port_service.PortAvailabilityService.MOBILE_PORT,
        currentUserId!,
        package['name'],
      );

      if (portId != null) {
        _navigateToPaymentScreen(package, portId);
      } else {
        _showErrorDialog('Failed to reserve port.');
      }
    } catch (e) {
      _showErrorDialog('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToPaymentScreen(Map<String, dynamic> package, String portId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Mobile_Payment(
              package: package,
              portId: portId,
              userId: currentUserId!,
              onPaymentSuccess: () async {
                // Start charging session after payment
                await ChargingService.startChargingSession(
                  userId: currentUserId!,
                  package: package,
                  portId: portId,
                  portType: port_service.PortAvailabilityService.MOBILE_PORT,
                  chargingWidgetKey: widget.chargingWidgetKey,
                );
                if (mounted) {
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              },
            ),
      ),
    );
  }

  Future<bool> _showConfirmationDialog(Map<String, dynamic> package) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Confirm ${package['name']}'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Price: LKR ${package['price']}'),
                    Text('Duration: ${package['duration']} mins'),
                    const SizedBox(height: 10),
                    const Text('Proceed to payment?'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[800],
                    ),
                    child: const Text('Continue'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F4C5C), Color(0xFF1A6B7A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            _buildPortStatus(),
            if (currentUserId != null) _buildActiveSessionWarning(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: packages.length,
                itemBuilder: (context, index) {
                  return _PackageCard(
                    package: packages[index],
                    onSelect: () => _selectPackage(packages[index]),
                    isLoading: _isLoading,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortStatus() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: StreamBuilder<DatabaseEvent>(
        stream: port_service.PortAvailabilityService.getPortsByTypeStream(
          port_service.PortAvailabilityService.MOBILE_PORT,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Row(
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(width: 16),
                Text(
                  'Checking port availability...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 16),
                Text(
                  'Error checking availability',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            );
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Text(
              'No Mobile Charging Ports found',
              style: TextStyle(color: Colors.white),
            );
          }

          final ports = (snapshot.data!.snapshot.value as Map).values.toList();
          final availablePorts =
              ports.where((port) => port['isAvailable'] == true).length;
          final hasAvailable = availablePorts > 0;

          return Row(
            children: [
              Icon(
                hasAvailable ? Icons.check_circle : Icons.cancel,
                color: hasAvailable ? Colors.green : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mobile Charging Ports',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Available: $availablePorts / ${ports.length}',
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
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
                  color: hasAvailable ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  hasAvailable ? 'Available' : 'All Busy',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveSessionWarning() {
    return FutureBuilder<bool>(
      future: port_service.PortAvailabilityService.hasActiveSession(
        currentUserId!,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Complete your active session before selecting a new package.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final VoidCallback onSelect;
  final bool isLoading;

  const _PackageCard({
    required this.package,
    required this.onSelect,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  package['name'],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4C5C),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal[800],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '\$${package['price']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              package['description'],
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.teal[800], size: 20),
                const SizedBox(width: 8),
                Text(
                  '${package['duration']} mins',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F4C5C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Features:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            ...package['features']
                .map<Widget>(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          feature,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            const SizedBox(height: 20),
            _buildSelectButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectButton() {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DatabaseEvent>(
      stream:
          currentUserId != null
              ? port_service.PortAvailabilityService.getPortsByTypeStream(
                port_service.PortAvailabilityService.MOBILE_PORT,
              )
              : null,
      builder: (context, snapshot) {
        final ports = snapshot.data?.snapshot.value ?? {};
        final hasAvailable = (ports as Map).values.any(
          (port) => port['isAvailable'] == true,
        );

        return FutureBuilder<bool>(
          future:
              currentUserId != null
                  ? port_service.PortAvailabilityService.hasActiveSession(
                    currentUserId,
                  )
                  : Future.value(false),
          builder: (context, activeSessionSnapshot) {
            final hasActiveSession = activeSessionSnapshot.data ?? false;
            final canSelect = hasAvailable && !hasActiveSession && !isLoading;

            return SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSelect ? onSelect : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSelect ? Colors.teal[800] : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          !hasAvailable
                              ? 'No Ports Available'
                              : hasActiveSession
                              ? 'Session Active'
                              : 'Select Package',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            );
          },
        );
      },
    );
  }
}
