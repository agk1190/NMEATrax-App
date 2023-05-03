import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:settings_ui/settings_ui.dart';

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
      home: const MyHomePage(title: 'NMEATrax Replay App'),
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
  // List<dynamic> dataParameters = ['RPM','Engine Temp (C)','Oil Temp (C)','Oil Pressure (kpa)','Fuel Rate (L/h)','Fuel Level (%)','Leg Tilt (%)','Speed (kn)','Heading (*)','Depth (ft)','Water Temp (C)','Battery Voltage (V)','Latitude','Longitude','Magnetic Variation (*)'];
  // List<List<dynamic>> limits = [[0,0,0,300,0,10,0,0,0,5,2,12,0,0,47,-125,16,0],[3800,80,115,700,50,100,100,25,359,1000,20,15,1000,0,49,-122,17,0]];
  String analyzedResults = "";
  int errCount = 0;
  bool sta = false;
  var lowerLimits = <String, int>{
    'RPM':0,
    'Engine Temp (C)':0,
    'Oil Temp (C)':0,
    'Oil Pressure (kpa)':300,
    'Fuel Rate (L/h)':0,
    'Fuel Level (%)':10,
    'Leg Tilt (%)':0,
    'Speed (kn)':0,
    'Heading (*)':0,
    'Depth (ft)':5,
    'Water Temp (C)':2,
    'Battery Voltage (V)':12,
    'Engine Hours (h)':0,
    'Latitude':47,
    'Longitude':-125,
    'Magnetic Variation (*)':16,
  };
  var upperLimits = <String, int>{
    'RPM':3800,
    'Engine Temp (C)':80,
    'Oil Temp (C)':115,
    'Oil Pressure (kpa)':700,
    'Fuel Rate (L/h)':50,
    'Fuel Level (%)':100,
    'Leg Tilt (%)':100,
    'Speed (kn)':25,
    'Heading (*)':360,
    'Depth (ft)':1000,
    'Water Temp (C)':20,
    'Battery Voltage (V)':15,
    'Engine Hours (h)':10000,
    'Latitude':49,
    'Longitude':-122,
    'Magnetic Variation (*)':17,
  };

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
      if (curLineNum > 1) {
        curLineNum--;
      }
    });
  }

  void _incrCurLineNum() {
    setState(() {
      if (curLineNum != maxLines){
        curLineNum++;
      }
    });
  }

  void _analyzeData() {
    int i = 0;
    errCount = 0;
    analyzedResults = "";
    for (var row in csvListData) {
      if (i > 0) {
        int j = 0;
        for (var col in row) {
          if (col is! String && j!=12 && j!=13 && j!=17) {
            if (col < lowerLimits[csvHeaderData[j]] || col > upperLimits[csvHeaderData[j]]) {
              analyzedResults += csvHeaderData[j] + ": " + col.toString() + " @ line " + i.toString() + "\n";
              errCount++;
            }
          }
          j++;
        }
      }
      i++;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NMEATrax Replay App',
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('NMEATrax Replay App'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.directions_boat_sharp)),
                Tab(icon: Icon(Icons.analytics)),
                Tab(icon: Icon(Icons.settings)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              Column(children: <Widget>[
                const SizedBox(height: 10,),
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
                ),
                ElevatedButton(onPressed: _getCSV, child: const Icon(Icons.file_upload)),
              ],),
              SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 30,),
                    ElevatedButton(onPressed: _analyzeData, child: const Text("Analyze All")),
                    const SizedBox(height: 10,),
                    Text("Results:\n$errCount Violations Found", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                    const SizedBox(height: 10,),
                    Text(analyzedResults),
                  ],
                ),
              ),
              SettingsList(
                platform: DevicePlatform.android,
                sections: [
                  SettingsSection(
                    title: const Text("Analyze - Lower Limits", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),),
                    // tiles: <SettingsTile>[
                    //   // SettingsTile.switchTile(
                    //   //   onToggle: (value) {sta = !sta; setState(() {});},
                    //   //   initialValue: sta,
                    //   //   leading: Icon(Icons.format_paint),
                    //   //   title: Text('Enable custom theme'),
                    //   // ),
                    // ],
                    
                    //https://stackoverflow.com/a/61674640 .map()
                    tiles: csvHeaderData.map((e) => SettingsTile.navigation(
                        leading: const Icon(Icons.settings_applications),
                        title: Text("Lower $e Limit"),
                        value: Text(lowerLimits[e].toString()),
                        onPressed: (context) {
                          showInputDialog(context, "Lower $e Limit", e, false);
                        },
                      )
                    ).toList(),
                  ),
                  SettingsSection(
                    title: const Text("Analyze - Upper Limits", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),),
                    tiles: csvHeaderData.map((e) => SettingsTile.navigation(
                        leading: const Icon(Icons.settings_applications),
                        title: Text("Upper $e Limit"),
                        value: Text(upperLimits[e].toString()),
                        onPressed: (context) {
                          showInputDialog(context, "Upper $e Limit", e, true);
                        },
                      )
                    ).toList(),
                  ),
                ],
              ),
            ]
          ),
        ),
      )
    );
  }
  
  //https://www.appsdeveloperblog.com/alert-dialog-with-a-text-field-in-flutter/
  showInputDialog(BuildContext context, String title, dynamic e, bool upper) {
    int input = 0;

    Widget confirmButton = ElevatedButton(
      child: const Text("OK"),
      onPressed: () {
        setState(() {
          if (upper) {
            upperLimits[e] = input;
          } else {
            lowerLimits[e] = input;
          }
        });
        //https://stackoverflow.com/a/50683571 for nav.pop
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
    AlertDialog alert = AlertDialog(
      title: Text(title),
      content: TextField(
        autofocus: true,
        onChanged: (value) {
          setState(() {
            input = int.parse(value);
          });
        },
        onSubmitted: (value) {
          setState(() {
            if (upper) {
            upperLimits[e] = int.parse(value);
          } else {
            lowerLimits[e] = int.parse(value);
          }
          });
          Navigator.of(context, rootNavigator: true).pop();
        },
        // decoration: const InputDecoration(
        //   prefixIcon: Icon(
        //     Icons.playlist_add,
        //     size: 18.0,
        //   ),
        // ),
      ),
      actions: [
        confirmButton,
      ],
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
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
          // child: Text(
          //   '${csvListData[0][index]}: ${csvListData[curLineNum][index]}',
          //   textAlign: TextAlign.center,
          //   style: const TextStyle(fontSize: 16),
          // ),
          child: 
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("${csvListData[0][index]}:", textAlign: TextAlign.right, ),
                Text(" ${csvListData[curLineNum][index]}", textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.bold),)
              ],
            )
        );
      },
    );
  }
}
