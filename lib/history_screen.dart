import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chart_view_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  String sortOption = 'Latest';
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final dbRef = FirebaseDatabase.instance.ref('orders');
      final snapshot = await dbRef
          .orderByChild('userId')
          .equalTo(userId)
          .get()
          .timeout(const Duration(seconds: 15));

      final List<Map<String, dynamic>> loadedOrders = [];
      
      for (final child in snapshot.children) {
        try {
          final data = _parseOrderData(child);
          if (_isMobileOrder(data)) {
            loadedOrders.add(data);
          }
        } catch (e) {
          debugPrint('Error parsing order ${child.key}: $e');
        }
      }

      _sortOrders(loadedOrders);

      setState(() {
        orders = loadedOrders;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load orders. Please try again.';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  // Add this method in your HistoryScreenState class
Map<String, dynamic> _parseOrderData(DataSnapshot child) {
  try {
    final rawData = child.value;
    if (rawData == null) throw Exception('Null order data received');

    // Safe type conversion
    final Map<dynamic, dynamic> rawMap = rawData as Map;
    final data = Map<String, dynamic>.fromEntries(
      rawMap.entries.map((e) => MapEntry(e.key.toString(), e.value))
    );

    // Parse timestamp safely
    final timestamp = data['createdAt'];
    DateTime orderDate;
    
    if (timestamp is int) {
      orderDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      orderDate = DateTime.fromMillisecondsSinceEpoch(int.tryParse(timestamp) ?? 0);
    } else {
      orderDate = DateTime.now();
    }

    return {
      'id': child.key ?? 'unknown_id',
      'package': data['packageName']?.toString() ?? 'Unknown Package',
      'status': data['status']?.toString() ?? 'Unknown',
      'type': data['portType']?.toString() ?? 'Mobile',
      'price': _parsePrice(data['price']),
      'duration': _parseDuration(data['durationMinutes']),
      'timestamp': orderDate,
    };
  } catch (e) {
    debugPrint('Error parsing order ${child.key}: $e');
    return {
      'id': 'error_${child.key}',
      'package': 'Error parsing data',
      'status': 'Error',
      'type': 'Mobile',
      'price': 'N/A',
      'duration': 0,
      'timestamp': DateTime.now(),
    };
  }
}

  bool _isMobileOrder(Map<String, dynamic> order) {
    final type = order['type']?.toString().toLowerCase() ?? '';
    return type.contains('mobile') || type.isEmpty;
  }

  void _sortOrders(List<Map<String, dynamic>> orders) {
    orders.sort((a, b) => sortOption == 'Latest'
        ? b['timestamp'].compareTo(a['timestamp'])
        : a['timestamp'].compareTo(b['timestamp']));
  }

  int _parseDuration(dynamic duration) {
    if (duration == null) return 0;
    if (duration is int) return duration;
    if (duration is double) return duration.toInt();
    if (duration is String) return int.tryParse(duration) ?? 0;
    return 0;
  }

  String _parsePrice(dynamic price) {
    if (price == null) return 'N/A';
    if (price is num) return price.toStringAsFixed(2);
    if (price is String) {
      return double.tryParse(price)?.toStringAsFixed(2) ?? 'N/A';
    }
    return 'N/A';
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    try {
      if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (timestamp is String) {
        return DateTime.fromMillisecondsSinceEpoch(int.tryParse(timestamp) ?? 0);
      }
      return DateTime.now();
    } catch (e) {
      debugPrint('Error parsing timestamp: $e');
      return DateTime.now();
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd • hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Charging History'),
        backgroundColor: Colors.teal[800],
        actions: [
          DropdownButton<String>(
            value: sortOption,
            underline: const SizedBox(),
            dropdownColor: Colors.teal[50],
            icon: const Icon(Icons.sort, color: Colors.white),
            onChanged: (value) {
              if (value != null) {
                setState(() => sortOption = value);
                _sortOrders(orders);
              }
            },
            items: ['Latest', 'Oldest'].map((sort) {
              return DropdownMenuItem(
                value: sort,
                child: Text(
                  sort,
                  style: TextStyle(
                    color: Colors.teal[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchOrders,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return const Center(
        child: Text(
          'No mobile charging history found.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        _buildSummaryCard(),
        Expanded(child: _buildOrderList()),
        _buildChartButton(),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final totalMinutes = orders.fold<int>(
      0,
      (sum, order) => sum + (order['duration'] as int),
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('${orders.length}', 'Total Sessions'),
          _buildSummaryItem('$totalMinutes', 'Total Minutes'),
          _buildSummaryItem(
            '${orders.where((o) => o['status'] == 'Completed').length}',
            'Completed',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.teal[800],
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildOrderList() {
    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.teal),
              title: Text(
                order['package'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text("Status: ${order['status']}"),
                  Text("Price: Rs.${order['price']}"),
                  Text("Duration: ${order['duration']} mins"),
                  const SizedBox(height: 2),
                  Text("Date: ${_formatDate(order['timestamp'])}"),
                ],
              ),
              trailing: Icon(
                order['status'] == 'Completed'
                    ? Icons.check_circle
                    : Icons.error,
                color: order['status'] == 'Completed'
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChartButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
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
        label: const Text('View Usage Chart'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal[800],
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}