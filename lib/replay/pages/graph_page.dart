import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'replay_shared_state.dart';
import 'package:nmeatrax_app/classes.dart';

class GraphPage extends StatelessWidget {
  const GraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReplayCsvData>(
      valueListenable: replayCsvNotifier,
      builder: (context, csvData, _) {
        return ValueListenableBuilder<List<int>>(
          valueListenable: selectedGraphColumnsNotifier,
          builder: (context, selectedCols, _) {
            if (csvData.rows.isEmpty || selectedCols.isEmpty) {
              return const Center(child: Text('No data selected'));
            }

            final List<Color> colors = [
              Colors.blue,
              Colors.red,
              Colors.green,
              Colors.orange,
              Colors.purple,
              Colors.teal,
              Colors.pink,
              Colors.amber,
            ];

            final List<LineChartBarData> bars = selectedCols.map((colIdx) {
              final spots = <FlSpot>[];
              for (int i = 0; i < csvData.rows.length; i++) {
                final dynamic val = UnitFunctions.returnInPreferredUnit(csvData.headers[colIdx], csvData.rows[i][colIdx]);
                if (val is num) {
                  spots.add(FlSpot(i.toDouble(), val.toDouble()));
                }
              }
              return LineChartBarData(
                spots: spots,
                color: colors[selectedCols.indexOf(colIdx) % colors.length],
                dotData: const FlDotData(show: false),
              );
            }).toList();

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: LineChart(
                LineChartData(
                  lineBarsData: bars,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideVertically: true,
                    ),
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

class GraphAppBar extends StatefulWidget {
  const GraphAppBar({super.key});

  @override
  State<GraphAppBar> createState() => _GraphAppBarState();
}

class _GraphAppBarState extends State<GraphAppBar> {
  void _showColumnSelector(BuildContext context, ReplayCsvData csvData) async {
    if (csvData.headers.isEmpty) return;

    // Work on a local copy so we can cancel
    List<int> tempSelected = List<int>.from(selectedGraphColumnsNotifier.value);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select graph columns'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: csvData.headers.length,
                  itemBuilder: (context, idx) {
                    final bool checked = tempSelected.contains(idx);
                    return CheckboxListTile(
                      title: Text(csvData.headers[idx].toString()),
                      value: checked,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelected.add(idx);
                          } else {
                            tempSelected.remove(idx);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    selectedGraphColumnsNotifier.value = List<int>.from(tempSelected);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReplayCsvData>(
      valueListenable: replayCsvNotifier,
      builder: (context, csvData, _) {
        return ElevatedButton.icon(
          onPressed: csvData.headers.isEmpty ? null : () => _showColumnSelector(context, csvData),
          icon: const Icon(Icons.tune),
          label: const Text('Select columns'),
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
            foregroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.onPrimary),
          ),
        );
      },
    );
  }
}