import 'package:flutter/material.dart';

import 'package:nmeatrax_app/classes.dart';
import 'replay_shared_state.dart';

class AnalyzePage extends StatelessWidget {
  const AnalyzePage({super.key, required this.onOpenDataTab});

  final VoidCallback onOpenDataTab;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          const SizedBox(height: 15),
          Text(
            'Results:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: analyzeVisibleNotifier,
            builder: (context, analyzeVisible, _) => Visibility(
              visible: analyzeVisible,
              child: ValueListenableBuilder<List<NmeaViolation>>(
                valueListenable: analyzedDataNotifier,
                builder: (context, analyzedData, __) => Text(
                  '${analyzedData.length} Violation${analyzedData.length == 1 ? '' : 's'} Found',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<List<NmeaViolation>>(
            valueListenable: analyzedDataNotifier,
            builder: (context, analyzedData, _) => ListAnalyzedData(
              analyzedData: analyzedData,
              mainContext: context,
              action: (value) {
                setCurLineNum(value);
                onOpenDataTab();
              },
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}

class ListAnalyzedData extends StatelessWidget {
  const ListAnalyzedData({
    super.key,
    required this.analyzedData,
    required this.action,
    required this.mainContext,
  });

  final List<NmeaViolation> analyzedData;
  final Function(int) action;
  final dynamic mainContext;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<NmeaViolation>> groupedViolations = {};

    for (var violation in analyzedData) {
      if (!groupedViolations.containsKey(violation.name)) {
        groupedViolations[violation.name] = [];
      }
      groupedViolations[violation.name]!.add(violation);
    }
    return ListView(
      shrinkWrap: true,
      children: groupedViolations.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(40, 2, 40, 2),
          child: Card(
            color: Theme.of(mainContext).colorScheme.surfaceContainer,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("${entry.key} x ${entry.value.length}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(mainContext).colorScheme.onSurface)),
                ),
                SizedBox(
                  width: 200,
                  height: entry.value.length > 3 ? 126 : null,
                  child: ListView.builder(
                    shrinkWrap: true,
                    // physics: const NeverScrollableScrollPhysics(),
                    itemCount: entry.value.length,
                    itemBuilder: (context, index) {
                      final violation = entry.value[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(0, 5, 0, 5),
                        child: ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(Theme.of(mainContext).colorScheme.surfaceContainerHigh)
                          ),
                          onPressed:() => action(violation.line),
                          // child: Text('${violation.value} @ ${violation.line}', style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
                          child: Text('${UnitFunctions.returnInPreferredUnit(violation.name, violation.value)}${UnitFunctions.unitOf(violation.name)} @ ${violation.line}', style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class AnalyzeDataAppBar extends StatelessWidget {
  const AnalyzeDataAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: analyzeVisibleNotifier,
          builder: (context, analyzeVisible, _) => Visibility(
            visible: analyzeVisible,
            child: ValueListenableBuilder<List<NmeaViolation>>(
              valueListenable: analyzedDataNotifier,
              builder: (context, analyzedData, __) => Text(
                '${analyzedData.length} Violation${analyzedData.length == 1 ? '' : 's'}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
          ),
          onPressed: () {
            analyzeData();
            analyzeVisibleNotifier.value = true;
          },
          child: Text('Refresh', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        ),
      ],
    );
  }
}