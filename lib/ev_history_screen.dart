import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../services/ampere_service.dart';
import 'ev_chart_screen.dart';

class EVHistoryScreen extends StatefulWidget {
  const EVHistoryScreen({super.key});

  @override
  EVHistoryScreenState createState() => EVHistoryScreenState();
}

class EVHistoryScreenState extends State<EVHistoryScreen> {
  List<Map<String, dynamic>> evOrders = [];
  bool isLoading = true;
  String sortOption = 'Latest';
  StreamSubscription<DatabaseEvent>? _evOrdersSubscription;

  @override
  void initState() {
    super.initState();
    fetchEVOrders();
  }

  @override
  void dispose() {
    _evOrdersSubscription?.cancel();
    super.dispose();
  }

  void fetchEVOrders() async {
    try {
      final String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      final dbRef = FirebaseDatabase.instance.ref('orders');
      final snapshot = await dbRef.orderByChild('userId').equalTo(userId).get();

      final List<Map<String, dynamic>> loadedOrders = [];
      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        // Filter for EV orders based on `portType` and include ampere-related data
        if ((data['portType'] ?? 'ev') == 'ev') {
          loadedOrders.add({
            'id': child.key,
            'package': data['packageName'] ?? 'N/A',
            'status': data['status'] ?? 'N/A',
            'price': data['price'] ?? 'N/A',
            'ampereLimit': data['ampereLimit'] ?? 0,
            'consumedAmpere': data['consumedAmpere'] ?? 0,
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

      if (mounted) {
        setState(() {
          evOrders = loadedOrders;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load EV history: $e")),
        );
      }
    }
  }

  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd • hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EV Charging History'),
        backgroundColor: Colors.teal,
        actions: [
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
                fetchEVOrders();
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
              : evOrders.isEmpty
              ? const Center(child: Text('No EV charging history found.'))
              : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: evOrders.length,
                      itemBuilder: (context, index) {
                        final order = evOrders[index];
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
                            leading: const Icon(
                              Icons.ev_station,
                              color: Colors.teal,
                            ),
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
                                Text("Price: ${order['price']}"),
                                Text("Ampere Limit: ${order['ampereLimit']}A"),
                                Text(
                                  "Consumed Ampere: ${order['consumedAmpere']}A",
                                ),
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
                            builder: (_) => const EVChartScreen(),
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
