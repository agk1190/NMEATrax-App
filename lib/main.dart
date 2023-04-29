import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';

Future<List<List<dynamic>>> _loadCSV(File filePath) async {
    String csvData = await filePath.readAsString();
    List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(csvData);
    return rowsAsListOfValues;
}

Future<File> _getFilePath() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null) {
      File file = File(result.files.single.path!);
      return file;
    } else {
      // User canceled the picker
      return File("null");
    }
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NMEATrax Replay',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'NMEATrax Replay App', showValueIndicator: ShowValueIndicator.always,),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, this.showValueIndicator});

  final String title;
  final ShowValueIndicator? showValueIndicator;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<List<dynamic>> csvListData = [];
  List<dynamic> csvHeaderData = [];
  int curLineNum = 1;
  File csvFilePath = File("c");
  num maxLines = 1;

  void _onSliderChanged(double value) {
    setState(() {
      curLineNum = value.toInt();
    });
  }

  void _getCSV() async {
    csvFilePath = await _getFilePath();
    if (csvFilePath.path != "null") {
      maxLines = csvFilePath.readAsLinesSync().length - 1;
      _loadCSV(csvFilePath).then((rows) {
        if (rows.isNotEmpty) {
          csvListData = rows;
          csvHeaderData = rows[0];
          setState(() {});
        }
      });
    }
  }

  void _decrCurLineNum() {
    setState(() {
      curLineNum--;
    });
  }

  void _incrCurLineNum() {
    setState(() {
      curLineNum++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NMEATrax Replay App',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('NMEATrax Replay App'),
        ),
        body: Column(children: <Widget>[
          ListData(csvHeaderData: csvHeaderData, csvListData: csvListData, curLineNum: curLineNum),
          const SizedBox(height: 20),
          Slider(
                value: curLineNum.toDouble(),
                onChanged: _onSliderChanged,
                label: curLineNum.toString(),
                max: maxLines.toDouble(),
                min: 1,
          ),
          Text(curLineNum.toString()),
          ButtonBar(
            alignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: _decrCurLineNum, child: const Text("Decrease")),
              TextButton(onPressed: _incrCurLineNum, child: const Text("Increase")),
            ],
          )
        ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _getCSV,
          tooltip: 'Open CSV',
          child: const Icon(Icons.folder_open),
        ),
      ),
    );
  }
}

class ListData extends StatelessWidget {
  const ListData({
    super.key,
    required this.csvHeaderData,
    required this.csvListData,
    required this.curLineNum,
  });

  final List csvHeaderData;
  final List<List> csvListData;
  final int curLineNum;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: csvHeaderData.length,
      itemBuilder: (BuildContext context, int index) {
        return Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Text(
            '${csvListData[0][index]}: ${csvListData[curLineNum][index]}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        );
      },
    );
  }
}
