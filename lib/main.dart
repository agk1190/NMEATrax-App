import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:flutter_map/flutter_map.dart'; // Suitable for most situations
// import 'package:flutter_map/plugin_api.dart'; // Only import if required functionality is not exposed by default
import 'package:latlong2/latlong.dart';
import 'package:gpx/gpx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sse_channel/sse_channel.dart';

Map<String, dynamic> nmeaData = {"rpm": "-273", "etemp": "-273", "otemp": "-273", "opres": "-273", "fuel_rate": "-273", "flevel": "-273", "efficiency": "-273", "leg_tilt": "-273", "speed": "-273", "heading": "-273", "depth": "-273", "wtemp": "-273", "battV": "-273", "ehours": "-273", "gear": "-", "lat": "-273", "lon": "-273", "mag_var": "-273", "time": "-"};
// bool nmeaFlag = false;
String connectURL = "192.168.1.232";
SseChannel? channel;
String buttonText = "Start";

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

Future<List<dynamic>> _loadGPX(File filePath) async {
  String gpxData = await filePath.readAsString();
  var gpxWPTs = GpxReader().fromString(gpxData);
  var trackpts = gpxWPTs.trks[0].trksegs[0].trkpts;
  trackpts.removeWhere((element) => element.lat == 0);
  return trackpts;
}

Future<File> _getFilePath(List<String> ext) async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ext);
    if (result != null) {
      File file = File(result.files.single.path!);
      return file;
    } else {
      // User canceled the picker
      return File("null");
    }
}

void main() {
  runApp(const MyApp());
}

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
          title: 'NMEATrax App',
          theme: ThemeData(colorScheme: myLightColors),
          darkTheme: ThemeData(colorScheme: myDarkColors),
          themeMode: currentMode,
          home: const HomePage(),
          initialRoute: '/live',
          routes: {
            '/live':(context) => const LivePage(),
            '/replay':(context) => const ReplayPage(),
          },
        );
      });
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NMEATrax App'),
      ),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF0050C7),
              ),
              child: Text('NMEATrax App'),
            ),
            ListTile(
              title: const Text('Live'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/live');
              },
            ),
            ListTile(
              title: const Text('Replay'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/replay');
              },
            ),
            const AboutListTile(
              icon: Icon(
                Icons.info,
              ),
              applicationIcon: Icon(
                Icons.directions_boat,
              ),
              applicationName: 'NMEATrax',
              applicationVersion: '1.0.0',
              aboutBoxChildren: [
                Text("For use with NMEATrax Vessel Monitoring System")
              ],
              child: Text('About app'),
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text('Home Page'),
      ),
    );
  }
}

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  Future<void> _getTheme() async {
    final SharedPreferences prefs = await _prefs;
    if (prefs.getBool('darkMode') == null) {return;}
    if (prefs.getBool('darkMode')!) {
      MyApp.themeNotifier.value = ThemeMode.dark;
    } else {
      MyApp.themeNotifier.value = ThemeMode.light;
    }
  }

  @override
  void initState() {
    super.initState();
    _getTheme();
    // Timer.periodic(const Duration(seconds: 1), (Timer t) => setState((){}));
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          drawer: Drawer(
            backgroundColor: Theme.of(context).colorScheme.background,
            child: ListView(
              children: <Widget>[
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0050C7),
                  ),
                  child: Text('NMEATrax App', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                ),
                ListTile(
                  textColor: Theme.of(context).colorScheme.onBackground,
                  iconColor: Theme.of(context).colorScheme.onBackground,
                  title: const Text('Live'),
                  leading: const Icon(Icons.bolt),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/live');
                  },
                ),
                ListTile(
                  textColor: Theme.of(context).colorScheme.onBackground,
                  iconColor: Theme.of(context).colorScheme.onBackground,
                  title: Text('Replay', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                  leading: const Icon(Icons.timeline),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/replay');
                  },
                ),
                AboutListTile(
                  icon: Icon(
                    color: Theme.of(context).colorScheme.onBackground,
                    Icons.info,
                  ),
                  applicationIcon: const Icon(
                    Icons.directions_boat,
                  ),
                  applicationName: 'NMEATrax',
                  applicationVersion: '1.0.0',
                  aboutBoxChildren: const [
                    Text("For use with NMEATrax Vessel Monitoring System")
                  ],
                  child: Text('About app', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                ),
              ],
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          backgroundColor: Theme.of(context).colorScheme.background,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            iconTheme: Theme.of(context).primaryIconTheme,
            title: Text('NMEATrax Live', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
            // leading: Icon(Icons.bolt),
            bottom: TabBar(
              indicatorColor: Theme.of(context).colorScheme.secondary,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard)),
                Tab(icon: Icon(Icons.list)),
                Tab(icon: Icon(Icons.settings)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedNMEABox(value: nmeaData["speed"], title: "Knots", unit: " kn", width: 120, mainContext: context,),
                        Expanded(child: SizedNMEABox(value: nmeaData["rpm"], title: "RPM", unit: "", mainContext: context,),),
                        SizedNMEABox(value: nmeaData["depth"], title: "Depth", unit: " ft", width: 120, mainContext: context,),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: nmeaData["etemp"], title: "Engine", unit: "\u2103", mainContext: context,),),
                        Expanded(child: SizedNMEABox(value: nmeaData["otemp"], title: "Oil", unit: "\u2103", mainContext: context,),),
                        Expanded(child: SizedNMEABox(value: nmeaData["opres"], title: "Oil", unit: " kpa", mainContext: context,),),
                        Expanded(child: SizedNMEABox(value: nmeaData["flevel"], title: "Fuel", unit: "%", mainContext: context,),),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: nmeaData["fuel_rate"], title: "Fuel Rate", unit: " L/h", mainContext: context,),),
                        Expanded(child: SizedNMEABox(value: nmeaData["efficiency"], title: "Efficiency", unit: " L/km", mainContext: context,),),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: nmeaData["leg_tilt"], title: "Leg Tilt", unit: "%", mainContext: context,),),
                        Expanded(child: SizedNMEABox(value: nmeaData["heading"], title: "Heading", unit: "\u00B0", mainContext: context,),),
                        Expanded(child: SizedNMEABox(value: nmeaData["wtemp"], title: "Water Temp", unit: "\u2103", mainContext: context,),),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: nmeaData["time"], title: "Time Stamp", unit: "", mainContext: context,),),
                      ],
                    ),
                    TextField(
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                      onChanged: (value) {
                        connectURL = value;
                      },
                      onSubmitted: (value) {
                        connectURL = value;
                      },
                    ),
                    ElevatedButton(
                      onPressed: sseSubscribe,
                      child: Text(buttonText),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: nmeaData.keys.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Expanded(child: Text(dataModel.jsonData.keys.elementAt(index), textAlign: TextAlign.right, style: TextStyle(color: Theme.of(mainContext).colorScheme.onBackground))),
                            Expanded(child: Text(nmeaData.keys.elementAt(index), textAlign: TextAlign.right, style: TextStyle(color: Theme.of(context).colorScheme.onBackground))),
                            Expanded(child: Text(nmeaData.values.elementAt(index), textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onBackground),))
                          ],
                        ),
                    );
                  },
                ),
              ),
              const Placeholder(),
            ]
          ),
        ),
      ),
    );
  }
}

class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key});

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {

  List<List<dynamic>> csvListData = [];
  List<dynamic> csvHeaderData = [];
  List<LatLng> gpxLL = [LatLng(0, 0)];
  List<List<String>> analyzedData = [];
  int curLineNum = 0;
  File csvFilePath = File("c");
  File gpxFilePath = File("c");
  num maxLines = 1;
  int errCount = 0;
  final mapController = MapController();
  bool _isVisible = true;
  final homeCoords = LatLng(48.668070, -123.404493);

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  var lowerLimits = <String, dynamic>{
    'RPM':0.0,
    'Engine Temp (C)':0.0,
    'Oil Temp (C)':0.0,
    'Oil Pressure (kpa)':300.0,
    'Fuel Rate (L/h)':0.0,
    'Fuel Level (%)':10.0,
    'Fuel Efficiency (L/km)':0.0,
    'Leg Tilt (%)':0.0,
    'Speed (kn)':0.0,
    'Heading (*)':0.0,
    'Depth (ft)':5.0,
    'Water Temp (C)':2.0,
    'Battery Voltage (V)':12.0,
    'Engine Hours (h)':0.0,
    'Latitude':47.0,
    'Longitude':-125.0,
    'Magnetic Variation (*)':0.0,
  };
  var upperLimits = <String, dynamic>{
    'RPM':5200.0,
    'Engine Temp (C)':80.0,
    'Oil Temp (C)':115.0,
    'Oil Pressure (kpa)':700.0,
    'Fuel Rate (L/h)':50.0,
    'Fuel Level (%)':100.0,
    'Fuel Efficiency (L/km)':4.0,
    'Leg Tilt (%)':100.0,
    'Speed (kn)':30.0,
    'Heading (*)':360.0,
    'Depth (ft)':1000.0,
    'Water Temp (C)':20.0,
    'Battery Voltage (V)':15.0,
    'Engine Hours (h)':10000.0,
    'Latitude':49.0,
    'Longitude':-122.0,
    'Magnetic Variation (*)':17.0,
  };

  void _onSliderChanged(double value) {
    setState(() {
      curLineNum = value.toInt();
    });
  }

  void _getCSV() async {
    csvFilePath = await _getFilePath(['csv']);
    if (csvFilePath.path != "null") {
      _loadCSV(csvFilePath).then((rows) {
        if (rows.isNotEmpty) {
          csvListData = rows;
          csvHeaderData = rows[0];
          csvListData.removeAt(0);
          int i = 0;
          int j = 0;
          for (var row in csvListData) {
            for (var value in row) {
              if (value is! String) {
                if ((-273.0).compareTo(value) == 0) {
                  csvListData[i][j] = "-";
                }
              }
              j++;
            }
            j = 0;
            i++;
          }
          setState(() {
            curLineNum = 0;
            maxLines = csvListData.length - 1;
          });
        }
      });
    }
  }

  void _getGPX() async {
    gpxFilePath = await _getFilePath(['gpx', 'xml']);
    if (gpxFilePath.path != "null") {
      _loadGPX(gpxFilePath).then((rows) {
        if (rows.isNotEmpty) {
          gpxLL.clear();
          for (Wpt wpt in rows) {
            gpxLL.add(LatLng(wpt.lat!, wpt.lon!));
          }
          setState(() {
            _isVisible = false;
          });
        }
      });
    }
  }

  void _decrCurLineNum() {
    setState(() {
      if (curLineNum > 0) {
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
    analyzedData.clear();
    for (var row in csvListData) {
      int j = 0;
      for (var col in row) {
        if (col is! String) {
          if ((col < lowerLimits[csvHeaderData[j]] || col > upperLimits[csvHeaderData[j]]) && col != -273.0) {
            analyzedData.add([csvHeaderData[j] + ':', ' $col @ line $i']);
            errCount++;
          }
        }
        j++;
      }
      i++;
    }
    setState(() {});
  }

  Future<void> _saveTheme(ThemeMode darkMode) async {
    final SharedPreferences prefs = await _prefs;

    setState(() {
      prefs.setBool('darkMode', darkMode==ThemeMode.dark? true : false);
    });
  }

  Future<void> _saveLimits(String label, var limits) async {
    final SharedPreferences prefs = await _prefs;

    setState(() {
      prefs.setString(label, jsonEncode(limits));
    });
  }

  Future<void> _getTheme() async {
    final SharedPreferences prefs = await _prefs;
    if (prefs.getBool('darkMode') == null) {return;}
    if (prefs.getBool('darkMode')!) {
      MyApp.themeNotifier.value = ThemeMode.dark;
    } else {
      MyApp.themeNotifier.value = ThemeMode.light;
    }
  }

  Future<void> _getLimits() async {
    final SharedPreferences prefs = await _prefs;
    if (prefs.getString("lower") == null) {return;}
    if (prefs.getString("upper") == null) {return;}
    lowerLimits = jsonDecode(prefs.getString("lower")!);
    upperLimits = jsonDecode(prefs.getString("upper")!);
  }
  
  @override
  void initState() {
    super.initState();
    _getTheme();
    _getLimits();
    // Timer.periodic(const Duration(seconds: 1), (Timer t) => setState((){}));
  }

  @override
  Widget build(BuildContext mainContext) {
    return MaterialApp(
      title: 'NMEATrax Replay',
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          drawer: Drawer(
            backgroundColor: Theme.of(context).colorScheme.background,
            child: ListView(
              children: <Widget>[
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0050C7),
                  ),
                  child: Text('NMEATrax App', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                ),
                ListTile(
                  textColor: Theme.of(context).colorScheme.onBackground,
                  iconColor: Theme.of(context).colorScheme.onBackground,
                  title: const Text('Live'),
                  leading: const Icon(Icons.bolt),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/live');
                  },
                ),
                ListTile(
                  textColor: Theme.of(context).colorScheme.onBackground,
                  iconColor: Theme.of(context).colorScheme.onBackground,
                  title: Text('Replay', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                  leading: const Icon(Icons.timeline),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/replay');
                  },
                ),
                AboutListTile(
                  icon: Icon(
                    color: Theme.of(context).colorScheme.onBackground,
                    Icons.info,
                  ),
                  applicationIcon: const Icon(
                    Icons.directions_boat,
                  ),
                  applicationName: 'NMEATrax',
                  applicationVersion: '1.0.0',
                  aboutBoxChildren: const [
                    Text("For use with NMEATrax Vessel Monitoring System")
                  ],
                  child: Text('About app', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                ),
              ],
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          backgroundColor: Theme.of(context).colorScheme.background,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            iconTheme: Theme.of(context).primaryIconTheme,
            title: Text('NMEATrax Replay', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
            // leading: Icon(Icons.bolt),
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
              SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 10,),
                    Text("Data", style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontSize: 24, fontWeight: FontWeight.w400),),
                    const SizedBox(height: 10,),
                    ListData(csvHeaderData: csvHeaderData, csvListData: csvListData, curLineNum: curLineNum, mainContext: context),
                    const SizedBox(height: 20),
                    Slider(
                          value: curLineNum.toDouble(),
                          onChanged: _onSliderChanged,
                          label: curLineNum.toString(),
                          max: maxLines.toDouble(),
                          min: 0,
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
                    const SizedBox(height: 50,),
                  ],
                ),
              ),
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
                    ListAnalyzedData(analyzedData: analyzedData, mainContext: context),
                    const SizedBox(height: 50,),
                  ],
                ),
              ),
              Stack(
                children: [
                  Scaffold(
                    body: FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        center: homeCoords,
                        zoom: 13.0,
                        maxZoom: 18.0,
                        maxBounds: LatLngBounds(
                          LatLng(-90.0, -180.0),
                          LatLng(90.0, 180.0),
                        ),
                        keepAlive: true,
                        interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate & ~InteractiveFlag.flingAnimation,
                        onTap: (tapPosition, point) {
                          setState(() {
                            _isVisible = !_isVisible;
                          });
                        },
                        onLongPress: (tapPosition, point) {
                          if (gpxLL.first != LatLng(0,0)) {
                            mapController.move(gpxLL.first, 13);
                          } else {
                            mapController.move(homeCoords, 13);
                          }
                          
                        },
                      ),
                      nonRotatedChildren: const [
                        RichAttributionWidget(
                          alignment: AttributionAlignment.bottomLeft,
                          showFlutterMapAttribution: false,
                          attributions: [
                            TextSourceAttribution(
                              'OpenStreetMap contributors',
                            ),
                          ],
                        ),
                      ],
                      children: [
                        TileLayer(
                          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                          // userAgentPackageName: 'dev.fleaflet.flutter_map.example',
                          userAgentPackageName: 'com.nmeatrax.app',
                          errorTileCallback: (tile, error, stackTrace) {},
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
                              points: gpxLL,
                              color: Theme.of(context).colorScheme.primary,
                              strokeWidth: 3,
                            ),
                          ],
                        )
                      ],
                    ),
                    floatingActionButton: Visibility(
                      visible: _isVisible,
                      child: FloatingActionButton(
                        onPressed: _getGPX,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.file_upload),
                      ),
                    ),
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
                            showInputDialog(context, "Lower $e Limit", e, false);
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
                            showInputDialog(context, "Upper $e Limit", e, true);
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
                              _saveTheme(MyApp.themeNotifier.value);
                          },
                          initialValue: MyApp.themeNotifier.value == ThemeMode.light ? false : true,
                          leading: Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.onBackground),
                          title: Text('Dark Mode', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                        ),
                        // SettingsTile.navigation(title: Text('App Version 1.1', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),)),
                      ],
                    ),
                  ],
                ),
              ),
            ]
          ),
        ),
      ),
    );
  }

  //https://www.appsdeveloperblog.com/alert-dialog-with-a-text-field-in-flutter/
  showInputDialog(BuildContext context, String title, dynamic e, bool upper) {
    double input = 0;

    Widget confirmButton = ElevatedButton(
      child: const Text("OK"),
      onPressed: () {
        setState(() {
          if (upper) {
            upperLimits[e] = input;
            _saveLimits("upper", upperLimits);
          } else {
            lowerLimits[e] = input;
            _saveLimits("lower", lowerLimits);
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
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        autofocus: true,
        onChanged: (value) {
          setState(() {
            try {
              input = double.parse(value);
            } on Exception {
              // do nothing
            }
          });
        },
        onSubmitted: (value) {
          setState(() {
            try {
              if (upper) {
                upperLimits[e] = double.parse(value);
                _saveLimits("upper", upperLimits);
              } else {
                lowerLimits[e] = double.parse(value);
                _saveLimits("lower", lowerLimits);
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
  final double width;
  final dynamic mainContext;

  const SizedNMEABox({
    Key? key,
    required this.value,
    required this.title,
    required this.unit,
    this.width = 100,
    required this.mainContext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(4.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(color: Theme.of(mainContext).colorScheme.onBackground, fontSize: 14),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(mainContext).colorScheme.onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                    color: Theme.of(mainContext).colorScheme.onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

sseSubscribe() async {
  try {
    channel = SseChannel.connect(Uri.parse('http://$connectURL/events'));
  } catch (e) {
    // print("Caught $e");
  }
  // buttonText = "Stop";
  channel!.stream.listen((message) {
    nmeaData = jsonDecode(message);
    // nmeaFlag = true;
    for (var element in nmeaData.values) {
      if (element == "-273") {
        element = '-';
      }
    }});
}
