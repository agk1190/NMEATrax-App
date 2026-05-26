import 'package:flutter/material.dart';
import 'dart:io';

import 'package:nmeatrax_app/classes.dart';
import 'replay_shared_state.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReplayCsvData>(
      valueListenable: replayCsvNotifier,
      builder: (context, csvData, __) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewportConstraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewportConstraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: <Widget>[
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            csvData.filePath.path == "null" ? "Open a file to view data" : csvData.filePath.path.substring(csvData.filePath.path.lastIndexOf(Platform.pathSeparator), csvData.filePath.path.length),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic
                            ),
                          ),
                        ),
                        const Spacer(),
                        ValueListenableBuilder<int>(
                          valueListenable: curLineNumNotifier,
                          builder: (context, curLineNum, _) => Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text("Line $curLineNum", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                          ),
                        ),
                      ],
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: curLineNumNotifier,
                      builder: (context, curLineNum, _) => Expanded(
                        child: ListData(csvHeaderData: csvData.headers, csvListData: csvData.rows, curLineNum: curLineNum, mainContext: context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ValueListenableBuilder<int>(
                      valueListenable: curLineNumNotifier,
                      builder: (context, curLineNum, ___) => Slider(
                        value: curLineNum.toDouble(),
                        onChanged: onSliderChanged,
                        label: curLineNum.toString(),
                        max: csvData.maxLine.toDouble(),
                        min: 0,
                        divisions: csvData.maxLine > 0 ? csvData.maxLine : null,
                        activeColor: Theme.of(context).colorScheme.primary,
                        inactiveColor: Theme.of(context).colorScheme.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}

class DataAppBar extends StatelessWidget {
  const DataAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
          ),
          icon: Icon(Icons.file_open_outlined, color: Theme.of(context).colorScheme.onPrimary,),
          label: Text("CSV", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
          onPressed: getCSV,
        ),
        const Spacer(),
        IconButton(
          onPressed: decrCurLineNum,
          icon: const Icon(Icons.arrow_circle_left_outlined),
          color: Theme.of(context).colorScheme.primary,
          iconSize: 35,
        ),
        IconButton(
          onPressed: incrCurLineNum,
          icon: const Icon(Icons.arrow_circle_right_outlined),
          color: Theme.of(context).colorScheme.primary,
          iconSize: 35,
        ),
      ],
    );
  }
}

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
  final BuildContext mainContext;

  @override
  Widget build(BuildContext context) {
    if (csvListData.isEmpty) {
      return const Center(child: Text('No CSV data loaded'));
    }

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
                  Expanded(child: Text('${csvHeaderData.elementAt(index)}:', textAlign: TextAlign.right, style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface))),
                  Expanded(child: Text(' ${UnitFunctions.returnInPreferredUnit(csvHeaderData.elementAt(index), csvListData.elementAt(curLineNum)[index])}${UnitFunctions.unitOf(csvHeaderData.elementAt(index))}', textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(mainContext).colorScheme.onSurface),))
                ],
              )
          );
        },
      ),
    );
  }
}