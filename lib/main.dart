import 'dart:io';
import 'package:file_picker/file_picker.dart';
// import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:flutter_map/flutter_map.dart'; // Suitable for most situations
// import 'package:flutter_map/plugin_api.dart'; // Only import if required functionality is not exposed by default
import 'package:latlong2/latlong.dart';

ColorScheme myLightColors = const ColorScheme(
  brightness: Brightness.light, 
  primary: Color(0xFF0050C7), 
  primaryContainer: Color.fromARGB(255, 118, 176, 241),
  onPrimary: Color.fromARGB(255, 219, 217, 217), 
  secondary: Color.fromARGB(255, 87, 144, 236),
  onSecondary: Color.fromARGB(255, 194, 194, 194),
  error: Color(0xFFFF50C7), 
  onError: Colors.black,
  background: Color.fromARGB(255, 240, 240, 240),
  onBackground: Color.fromARGB(255, 22, 22, 22), 
  surface: Color.fromARGB(255, 231, 231, 231),
  onSurface: Color.fromARGB(255, 219, 219, 219),
);

ColorScheme myDarkColors = const ColorScheme(
  brightness: Brightness.dark, 
  primary: Color(0xFF0050C7), 
  primaryContainer: Color.fromARGB(255, 6, 38, 80),
  onPrimary: Color.fromARGB(255, 219, 217, 217), 
  secondary: Color.fromARGB(255, 87, 144, 236),
  onSecondary: Color.fromARGB(255, 194, 194, 194),
  error: Color(0xFFFF50C7), 
  onError: Colors.black,
  background: Color.fromARGB(255, 36, 36, 36),
  onBackground: Color.fromARGB(255, 219, 219, 219), 
  surface: Color.fromARGB(255, 80, 76, 76),
  onSurface: Color.fromARGB(255, 219, 219, 219),
);

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

  // https://www.kindacode.com/article/flutter-ways-to-make-a-dark-light-mode-toggle/ - dark mode toggle
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier, 
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'NMEATrax Replay',
          theme: ThemeData(colorScheme: myLightColors),
          darkTheme: ThemeData(colorScheme: myDarkColors),
          // themeMode: ThemeMode.dark,
          themeMode: currentMode,
          home: const MyHomePage(title: 'NMEATrax Replay App'),
        );
      });
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
  String analyzedResults = "";
  int errCount = 0;
  final mapController = MapController();

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
  Widget build(BuildContext mainContext) {
    return MaterialApp(
      title: 'NMEATrax Replay App',
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          // backgroundColor: Theme.of(context).canvasColor,
          backgroundColor: Theme.of(context).colorScheme.background,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            iconTheme: Theme.of(context).primaryIconTheme,
            title: Text('NMEATrax Replay App', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
            bottom: TabBar(
              indicatorColor: Theme.of(context).colorScheme.secondary,
              tabs: const [
                Tab(icon: Icon(Icons.directions_boat_sharp)),
                Tab(icon: Icon(Icons.analytics)),
                Tab(icon: Icon(Icons.map)),
                Tab(icon: Icon(Icons.settings)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              Column(children: <Widget>[
                const SizedBox(height: 10,),
                ListData(csvHeaderData: csvHeaderData, csvListData: csvListData, curLineNum: curLineNum, mainContext: context),
                const SizedBox(height: 20),
                Slider(
                      value: curLineNum.toDouble(),
                      onChanged: _onSliderChanged,
                      label: curLineNum.toString(),
                      max: maxLines.toDouble(),
                      min: 1,
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Theme.of(context).colorScheme.primaryContainer,
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(3.0, 0, 3.0, 0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.onBackground, width: 2,),
                  ),
                  child: Text(
                    curLineNum.toString(), 
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                ),
                ButtonBar(
                  alignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _decrCurLineNum, 
                      child: Text(
                        "Decrease", 
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary, 
                          fontWeight: FontWeight.bold,
                          fontSize: 16
                        ),
                      )
                    ),
                    TextButton(
                      onPressed: _incrCurLineNum, 
                      child: Text(
                        "Increase", 
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16
                        ),
                      )
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _getCSV,
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(Theme.of(context).colorScheme.primary),
                  ),
                  child: const Icon(Icons.file_upload), 
                ),
              ],),
              SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 30,),
                    ElevatedButton(
                      onPressed: _analyzeData, 
                      style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Theme.of(context).colorScheme.primary)), 
                      child: const Text("Analyze All")
                    ),
                    const SizedBox(height: 10,),
                    Text(
                      "Results:\n$errCount Violations Found", 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16, 
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                      textAlign: TextAlign.center
                    ),
                    const SizedBox(height: 10,),
                    Text(
                      analyzedResults,
                      style: TextStyle(color: Theme.of(context).colorScheme.onBackground),  
                    ),
                  ],
                ),
              ),
              Stack(
                children: [
                  FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      center: LatLng(48.668069, -123.40451),
                      zoom: 16.0,
                      maxZoom: 18.0,
                      maxBounds: LatLngBounds(
                        LatLng(-90.0, -180.0),
                        LatLng(90.0, 180.0),
                      ),
                      keepAlive: true,
                      interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    nonRotatedChildren: [
                      AttributionWidget.defaultWidget(
                        source: '© OpenStreetMap contributors',
                        onSourceTapped: () {},
                      ),
                    ],
                    children: [
                      TileLayer(
                        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        // userAgentPackageName: 'dev.fleaflet.flutter_map.example',
                        userAgentPackageName: 'com.nmeatrax.app',
                      ),
                      // MarkerLayer(
                      //   markers: [
                      //     Marker(
                      //       point: LatLng(48.66807, -123.405),
                      //       width: 80,
                      //       height: 80,
                      //       builder: (context) => FlutterLogo(),
                      //     ),
                      //   ],
                      // ),
                      PolylineLayer(
                        polylineCulling: false,
                        polylines: [
                          Polyline(
                            points: [LatLng(48.668069, -123.40451), LatLng(48.642347, -123.333999)],
                            color: Colors.blue,
                            strokeWidth: 3,
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
              SingleChildScrollView(
                child: SettingsList(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  darkTheme: SettingsThemeData(
                    settingsSectionBackground: Theme.of(context).colorScheme.background,
                    settingsListBackground: Theme.of(context).colorScheme.background,
                    titleTextColor: Theme.of(context).colorScheme.onBackground,
                  ),
                  lightTheme: SettingsThemeData(
                    settingsSectionBackground: Theme.of(context).colorScheme.background,
                    settingsListBackground: Theme.of(context).colorScheme.background,
                    titleTextColor: Theme.of(context).colorScheme.onBackground,
                  ),
                  platform: DevicePlatform.android,
                  sections: [
                    SettingsSection(
                      title: const Text(
                        "Analyze - Lower Limits", 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 22,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      //https://stackoverflow.com/a/61674640 .map()
                      tiles: csvHeaderData.map((e) => SettingsTile.navigation(
                          leading: Icon(Icons.settings_applications, color: Theme.of(context).colorScheme.onBackground),
                          title: Text("Lower $e Limit", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                          value: Text(lowerLimits[e].toString(), style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                          onPressed: (context) {
                            showInputDialog(mainContext, "Lower $e Limit", e, false);
                          },
                        )
                      ).toList(),
                    ),
                    SettingsSection(
                      title: const Text(
                        "Analyze - Upper Limits", 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 22,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      tiles: csvHeaderData.map((e) => SettingsTile.navigation(
                          leading: Icon(Icons.settings_applications, color: Theme.of(context).colorScheme.onBackground),
                          title: Text("Upper $e Limit", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                          value: Text(upperLimits[e].toString(), style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                          onPressed: (context) {
                            showInputDialog(mainContext, "Upper $e Limit", e, true);
                          },
                        )
                      ).toList(),
                    ),
                    SettingsSection(
                      title: const Text(
                        "App Theme", 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 22,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      tiles: <SettingsTile>[
                        SettingsTile.switchTile(
                          onToggle: (value) {
                              MyApp.themeNotifier.value =
                                MyApp.themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                          },
                          initialValue: MyApp.themeNotifier.value == ThemeMode.light ? false : true,
                          leading: Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.onBackground),
                          title: Text('Dark Mode', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                        ),
                      ],
                    ),
                  ],
                ),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(title),
      content: TextField(
        autofocus: true,
        onChanged: (value) {
          setState(() {
            try {
              input = int.parse(value);
            } on Exception {
              // do nothing
            }
          });
        },
        onSubmitted: (value) {
          setState(() {
            try {
              if (upper) {
                upperLimits[e] = int.parse(value);
              } else {
                lowerLimits[e] = int.parse(value);
              }
            } on Exception {
              // do nothing
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
    required this.mainContext,
  });

  final List csvHeaderData;
  final List<List> csvListData;
  final int curLineNum;
  final dynamic mainContext;

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
                Text("${csvListData[0][index]}:", textAlign: TextAlign.right, style: TextStyle(color: Theme.of(mainContext).colorScheme.onBackground)),
                Text(" ${csvListData[curLineNum][index]}", textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(mainContext).colorScheme.onBackground),)
              ],
            )
        );
      },
    );
  }
}
