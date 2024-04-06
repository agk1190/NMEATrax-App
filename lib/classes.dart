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
                  Expanded(child: Text(csvHeaderData.elementAt(index) + ':', textAlign: TextAlign.right, style: TextStyle(color: Theme.of(mainContext).colorScheme.onBackground))),
                  Expanded(child: Text(' ${csvListData.elementAt(curLineNum)[index]}', textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(mainContext).colorScheme.onBackground),))
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
    required this.mainContext,
  });

  final List<List> analyzedData;
  final dynamic mainContext;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: analyzedData.length,
      itemBuilder: (BuildContext context, int index) {
        return Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: Text(analyzedData.elementAt(index)[0], textAlign: TextAlign.right, style: TextStyle(color: Theme.of(mainContext).colorScheme.onBackground))),
                Expanded(child: Text(analyzedData.elementAt(index)[1], textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(mainContext).colorScheme.onBackground),))
              ],
            ),
        );
      },
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
      // height: fontSize == 24 ? 80 : 100,
      child: Card(
        color: Theme.of(mainContext).colorScheme.surface,
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
