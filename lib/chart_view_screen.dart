import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

class ChartViewScreen extends StatefulWidget {
  const ChartViewScreen({super.key});

  @override
  ChartViewScreenState createState() => ChartViewScreenState();
}

class ChartViewScreenState extends State<ChartViewScreen> {
  Map<String, int> packageCounts = {};
  Map<String, int> durationTotals = {};
  bool isLoading = true;
  String chartType = 'Count'; // 'Count'  'Duration'

  @override
  void initState() {
    super.initState();
    fetchChartData();
  }

  void fetchChartData() async {
    try {
      final String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() => isLoading = false);
        return;
      }

      final dbRef = FirebaseDatabase.instance.ref('orders');
      final snapshot = await dbRef.orderByChild('userId').equalTo(userId).get();

      final Map<String, int> counts = {};
      final Map<String, int> durations = {};

      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        if ((data['portType'] ?? 'mobile').toString().toLowerCase() ==
            'mobile') {
          final pkg = data['packageName']?.toString() ?? 'Unknown';
          final duration =
              int.tryParse(data['durationMinutes']?.toString() ?? '0') ?? 0;

          counts.update(pkg, (value) => value + 1, ifAbsent: () => 1);
          durations.update(
            pkg,
            (value) => value + duration,
            ifAbsent: () => duration,
          );
        }
      }

      setState(() {
        packageCounts = counts;
        durationTotals = durations;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chart data: $e')),
        );
      }
    }
  }

  List<BarChartGroupData> getBarGroups() {
    final dataMap = chartType == 'Count' ? packageCounts : durationTotals;
    int i = 0;
    return dataMap.entries.map((entry) {
      return BarChartGroupData(
        x: i++,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: Colors.teal,
            width: 18,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        showingTooltipIndicators: [0],
      );
    }).toList();
  }

  Widget bottomTitles(double value, TitleMeta meta) {
    final dataMap = chartType == 'Count' ? packageCounts : durationTotals;
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
        style: const TextStyle(fontSize: 10, color: Colors.black),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Charging Chart'),
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
            items:
                ['Count', 'Duration'].map((type) {
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
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : (packageCounts.isEmpty && durationTotals.isEmpty)
              ? const Center(child: Text('No mobile charging data available'))
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      chartType == 'Count'
                          ? 'Number of Mobile Charging Sessions per Package'
                          : 'Total Mobile Charging Duration per Package (minutes)',
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
                              //backgroundColor: const Color(0xFF0F4C5C),
                              getTooltipItem: (
                                group,
                                groupIndex,
                                rod,
                                rodIndex,
                              ) {
                                final dataMap =
                                    chartType == 'Count'
                                        ? packageCounts
                                        : durationTotals;
                                final pkgName = dataMap.keys.elementAt(
                                  group.x.toInt(),
                                );
                                final value = rod.toY.toInt();
                                return BarTooltipItem(
                                  '${chartType == 'Count' ? 'Sessions' : 'Minutes'}: $value\n$pkgName',
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
                                color: Colors.white.withAlpha(
                                  51,
                                ), // 0.2 * 255 ≈ 51
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
