import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'port_availability_service.dart';

class PortStatusWidget extends StatelessWidget {
  final String portType;
  final String displayName;

  const PortStatusWidget({
    super.key,
    required this.portType,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: PortAvailabilityService.getPortsByTypeStream(portType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Center(child: Text('No $displayName ports found'));
        }

        final portsMap = Map<String, dynamic>.from(
          snapshot.data!.snapshot.value as Map,
        );
        final ports = portsMap.values.toList();

        final availablePorts =
            ports
                .where((port) => port != null && port['isAvailable'] == true)
                .length;
        final totalPorts = ports.length;

        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                portType == PortAvailabilityService.MOBILE_PORT
                    ? Icons.smartphone
                    : Icons.electric_car,
                size: 40,
                color: availablePorts > 0 ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Available: $availablePorts / $totalPorts',
                      style: Theme.of(context).textTheme.bodyMedium,
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
                  color: availablePorts > 0 ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  availablePorts > 0 ? 'Available' : 'Busy',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminSetupScreen extends StatefulWidget {
  const AdminSetupScreen({super.key});

  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  bool _isInitializing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PortStatusWidget(
              portType: PortAvailabilityService.MOBILE_PORT,
              displayName: 'Mobile Ports',
            ),
            const SizedBox(height: 16),
            const PortStatusWidget(
              portType: PortAvailabilityService.EV_PORT,
              displayName: 'Vehicle Ports',
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed:
                  _isInitializing
                      ? null
                      : () async {
                        setState(() => _isInitializing = true);
                        try {
                          await PortAvailabilityService.forceInitializePorts();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Ports initialized successfully!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isInitializing = false);
                          }
                        }
                      },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child:
                  _isInitializing
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text('Initialize Charging Ports'),
            ),
          ],
        ),
      ),
    );
  }
}
