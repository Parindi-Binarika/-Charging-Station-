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
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Text('No $displayName ports found');
        }

        final portsMap = Map<String, dynamic>.from(
          snapshot.data!.snapshot.value as Map,
        );
        final ports = portsMap.values.toList();
        int availablePorts =
            ports.where((port) => port['isAvailable'] == true).length;
        int totalPorts = ports.length;

        // Force EV port to always show 1/1
        if (portType == PortAvailabilityService.EV_PORT) {
          totalPorts = 1;
          availablePorts = availablePorts > 0 ? 1 : 0;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Available: $availablePorts / $totalPorts',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
