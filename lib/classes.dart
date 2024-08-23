import 'package:flutter/material.dart';

class ListData extends StatelessWidget {
  const ListData({
    super.key,
    required this.csvHeaderData,
    required this.csvListData,
    required this.curLineNum,
    required this.mainContext,
  });

  final List csvHeaderData;
  final List<List> csvListData;
  final int curLineNum;
  final dynamic mainContext;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: csvHeaderData.length,
        itemBuilder: (BuildContext context, int index) {
          return Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: 
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: Text(csvHeaderData.elementAt(index) + ':', textAlign: TextAlign.right, style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface))),
                  Expanded(child: Text(' ${csvListData.elementAt(curLineNum)[index]}', textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(mainContext).colorScheme.onSurface),))
                ],
              )
          );
        },
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
                          child: Text('${violation.value} @ ${violation.line}', style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
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

class SizedNMEABox extends StatelessWidget {
  final String value;
  final String title;
  final String unit;
  final double fontSize;
  final dynamic mainContext;

  const SizedNMEABox({
    super.key,
    required this.value,
    required this.title,
    required this.unit,
    this.fontSize = 24,
    required this.mainContext,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Card(
        color: Theme.of(mainContext).colorScheme.surfaceContainerLow,
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(title, style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
              Text("$value$unit", style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Theme.of(mainContext).colorScheme.onSurface),),
            ],
          ),
        )
      ),
    );
  }
}

enum ConversionType {depth, temp}

class NmeaViolation {
  final String name;
  final double value;
  final int line;

  NmeaViolation({required this.name, required this.value, required this.line});
}