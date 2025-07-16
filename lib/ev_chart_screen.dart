import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

class EVChartScreen extends StatefulWidget {
  const EVChartScreen({super.key});

  @override
  EVChartScreenState createState() => EVChartScreenState();
}

class EVChartScreenState extends State<EVChartScreen> {
  Map<String, double> ampereTotals = {};
  Map<String, int> sessionCounts = {};
  bool isLoading = true;
  String chartType = 'Ampere'; // 'Ampere' or 'Sessions'

  @override
  void initState() {
    super.initState();
    fetchChartData();
  }

  Future<void> fetchChartData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final dbRef = FirebaseDatabase.instance.ref('orders');
      final snapshot =
          await dbRef.orderByChild('userId').equalTo(user.uid).get();

      final Map<String, double> ampereData = {};
      final Map<String, int> sessionData = {};

      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        if ((data['portType'] ?? 'ev').toString().toLowerCase() == 'ev') {
          final pkg = data['packageName']?.toString() ?? 'Unknown';
          final consumedAmpere =
              double.tryParse(data['consumedAmpere']?.toString() ?? '0') ?? 0;

          ampereData.update(pkg, (value) => value + consumedAmpere,
              ifAbsent: () => consumedAmpere);
          sessionData.update(pkg, (value) => value + 1, ifAbsent: () => 1);
        }
      }

      setState(() {
        ampereTotals = ampereData;
        sessionCounts = sessionData;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chart data: $e')),
        );
      }
    }
  }

  List<BarChartGroupData> getBarGroups() {
    final dataMap = chartType == 'Ampere' ? ampereTotals : sessionCounts;
    int i = 0;
    return dataMap.entries.map((entry) {
      return BarChartGroupData(
        x: i++,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            width: 20,
            color: Colors.teal,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        showingTooltipIndicators: [0],
      );
    }).toList();
  }

  Widget bottomTitles(double value, TitleMeta meta) {
    final dataMap = chartType == 'Ampere' ? ampereTotals : sessionCounts;
    if (value.toInt() >= dataMap.length) return const SizedBox.shrink();
    final pkgName = dataMap.keys.elementAt(value.toInt());
    final shortName = pkgName.split(' - ')[0];
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        shortName,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget leftTitles(double value, TitleMeta meta) {
    if (value % 1 != 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Text(
        value.toInt().toString(),
        style: const TextStyle(
          fontSize: 10,
          color: Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("EV Charging Chart"),
        backgroundColor: Colors.teal,
        actions: [
          DropdownButton<String>(
            value: chartType,
            underline: const SizedBox(),
            dropdownColor: Colors.teal[50],
            icon: const Icon(Icons.analytics, color: Colors.white),
            onChanged: (value) {
              if (value != null) {
                setState(() => chartType = value);
              }
            },
            items: ['Ampere', 'Sessions'].map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(
                  type,
                  style: const TextStyle(color: Colors.black),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (ampereTotals.isEmpty && sessionCounts.isEmpty)
              ? const Center(child: Text('No EV charging data available'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        chartType == 'Ampere'
                            ? 'Total Ampere Consumed per Package'
                            : 'Number of EV Charging Sessions per Package',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barGroups: getBarGroups(),
                            titlesData: FlTitlesData(
                              show: true,
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  getTitlesWidget: leftTitles,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: bottomTitles,
                                  reservedSize: 42,
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final dataMap =
                                      chartType == 'Ampere' ? ampereTotals : sessionCounts;
                                  final pkgName = dataMap.keys.elementAt(group.x.toInt());
                                  final value = rod.toY.toInt();
                                  return BarTooltipItem(
                                    '${chartType == 'Ampere' ? 'Ampere' : 'Sessions'}: $value\n$pkgName',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  );
                                },
                                tooltipPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                tooltipBorderRadius: BorderRadius.circular(8),
                                tooltipBorder: BorderSide(
                                  color: Colors.white.withAlpha(51),
                                  width: 1,
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
