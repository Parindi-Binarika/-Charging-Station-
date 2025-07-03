import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chart_view_screen.dart';

// mobile history_screen (only Mobile history)
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  String sortOption = 'Latest';

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  void fetchOrders() async {
    try {
      final String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User is not logged in.');

      final dbRef = FirebaseDatabase.instance.ref('orders');
      final snapshot = await dbRef.orderByChild('userId').equalTo(userId).get();

      final List<Map<String, dynamic>> loadedOrders = [];
      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        // Use 'portType' to filter for Mobile, and 'packageName'/'durationMinutes'
        if ((data['portType'] ?? 'mobile') == 'mobile' ||
            (data['portType'] ?? 'Mobile') == 'Mobile') {
          loadedOrders.add({
            'id': child.key,
            'package': data['packageName'] ?? 'N/A',
            'status': data['status'] ?? 'N/A',
            'type': data['portType'] ?? 'Mobile',
            'price': data['price'] ?? 'N/A',
            'duration': data['durationMinutes'] ?? 0,
            'timestamp': DateTime.fromMillisecondsSinceEpoch(
              (data['createdAt'] is int)
                  ? data['createdAt']
                  : int.tryParse(data['createdAt'].toString()) ?? 0,
            ),
          });
        }
      }

      loadedOrders.sort(
        (a, b) =>
            sortOption == 'Latest'
                ? b['timestamp'].compareTo(a['timestamp'])
                : a['timestamp'].compareTo(b['timestamp']),
      );

      setState(() {
        orders = loadedOrders;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading orders: $e")));
    }
  }

  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd • hh:mm a').format(date);
  }

  Icon getTypeIcon(String type) {
    // Only Mobile type is shown
    return const Icon(Icons.phone_android, color: Colors.teal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Charging History'),
        backgroundColor: Colors.teal,
        actions: [
          // Sort dropdown only
          DropdownButton<String>(
            value: sortOption,
            underline: const SizedBox(),
            dropdownColor: Colors.teal[50],
            icon: const Icon(Icons.sort, color: Colors.white),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  sortOption = value;
                  isLoading = true;
                });
                fetchOrders();
              }
            },
            items:
                ['Latest', 'Oldest'].map((sort) {
                  return DropdownMenuItem(value: sort, child: Text(sort));
                }).toList(),
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : orders.isEmpty
              ? const Center(child: Text('No mobile charging history found.'))
              : Column(
                children: [
                  // Summary card
                  if (orders.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.teal.withAlpha((0.3 * 255).toInt()),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${orders.length}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                              const Text('Total Sessions'),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${orders.fold<int>(0, (sum, order) => sum + (order['duration'] as int))}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                              const Text('Total Minutes'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: getTypeIcon(order['type']),
                            title: Text(
                              order['package'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text("Status: ${order['status']}"),
                                Text("Price: Rs.${order['price']}"),
                                Text("Duration: ${order['duration']} mins"),
                                const SizedBox(height: 2),
                                Text("Date: ${formatDate(order['timestamp'])}"),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChartViewScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('Chart View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
