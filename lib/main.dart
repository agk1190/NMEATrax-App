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
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Map<String, dynamic> nmeaData = {"rpm": "-273", "etemp": "-273", "otemp": "-273", "opres": "-273", "fuel_rate": "-273", "flevel": "-273", "efficiency": "-273", "leg_tilt": "-273", "speed": "-273", "heading": "-273", "depth": "-273", "wtemp": "-273", "battV": "-273", "ehours": "-273", "gear": "-", "lat": "-273", "lon": "-273", "mag_var": "-273", "time": "-"};
Map<String, dynamic> ntOptions = {"isMeters":false, "isDegF":false, "recInt":0, "timeZone":0, "recMode":0};
const Map<num, String> recModeEnum = {0:"Off", 1:"On", 2:"Auto by Speed", 3:"Auto by RPM", 4:"Auto by Speed", 5:"Auto by RPM"};
String connectURL = "192.168.1.231";
late SseChannel channel;
List<String> downloadList = [];
String emailData = "";
StreamSubscription? stream;
const _appVersion = '2.0.0';

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
  onPrimary: Color.fromARGB(255, 219, 219, 219), 
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
              applicationVersion: _appVersion,
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
  bool connected = false;
  final List<String> recModeOptions = <String>['Off', 'On', 'Auto by Speed', 'Auto by RPM'];

  Future<void> _getTheme() async {
    final SharedPreferences prefs = await _prefs;
    if (prefs.getBool('darkMode') == null) {return;}
    if (prefs.getBool('darkMode')!) {
      MyApp.themeNotifier.value = ThemeMode.dark;
    } else {
      MyApp.themeNotifier.value = ThemeMode.light;
    }
  }

  Future<void> _saveTheme(ThemeMode darkMode) async {
    final SharedPreferences prefs = await _prefs;

    setState(() {
      prefs.setBool('darkMode', darkMode==ThemeMode.dark? true : false);
    });
  }

  Future<void> _saveIP(String ip) async {
      final SharedPreferences prefs = await _prefs;

      setState(() {
        prefs.setString("ip", jsonEncode(ip));
      });
    }

  Future<void> _getIP() async {
    final SharedPreferences prefs = await _prefs;
    if (prefs.getString("ip") == null) {return;}
    connectURL = jsonDecode(prefs.getString("ip")!);
  }

  Future<void> getOptions() async {

    final response = await http.get(Uri.parse('http://$connectURL/get'));

    if (response.statusCode == 200) {
      ntOptions = jsonDecode(response.body);
      setState(() {});
    } else {
      throw Exception('Failed to get options');
    }

    final dlList = await http.get(Uri.parse('http://$connectURL/listDir'));

    if (dlList.statusCode == 200) {
      List<List<String>> converted = const CsvToListConverter(shouldParseNumbers: false).convert(dlList.body);
      downloadList = converted.elementAt(0);
      downloadList.removeAt(downloadList.length - 1);
    } else {
      throw Exception('Failed to get download list');
    }
  }

  Future<void> setOptions(String kvPair) async {
    final response = await http.post(Uri.parse('http://$connectURL/set?$kvPair'));
    // print(response.statusCode);
    if (response.statusCode == 200) {
      getOptions();
      setState(() {});
    }
  }
  
  @override
  void initState() {
    super.initState();
    _getTheme();
    _getIP();
    int i = 0;
    for (var element in nmeaData.values) {
      if (element == "-273" || element == "-273.0" || element == "-273.00") {
        var key = nmeaData.keys.elementAt(i);
        nmeaData[key] = '-';
      }
      i++;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext lcontext) {
    return MaterialApp(
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          drawer: Drawer(
            width: 200,
            backgroundColor: Theme.of(context).colorScheme.background,
            child: ListView(
              children: <Widget>[
                DrawerHeader(
                  decoration: const BoxDecoration(
                    image: DecorationImage(image: AssetImage('assets/images/nmeatraxLogo.png')),
                    color: Color(0xFF0050C7),
                  ),
                  child: Text('NMEATrax', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
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
                  applicationVersion: _appVersion,
                  aboutBoxChildren: const [
                    Text("For use with NMEATrax Vessel Monitoring System")
                  ],
                  child: Text('About app', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                ),
                Center(
                  child: ElevatedButton(
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Theme.of(context).colorScheme.primary),),
                    child: MyApp.themeNotifier.value == ThemeMode.light ? Icon(Icons.dark_mode_outlined, color: Theme.of(context).colorScheme.onPrimary,) : Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.onError,),
                    onPressed: () {
                      MyApp.themeNotifier.value =
                        MyApp.themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                      _saveTheme(MyApp.themeNotifier.value);
                    },
                  ),
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
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(nmeaData["time"], style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: nmeaData["speed"], title: "Knots", unit: " kn", mainContext: context,)),
                        Expanded(child: SizedNMEABox(value: nmeaData["depth"], title: "Depth", unit: " ft", mainContext: context,)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: nmeaData["rpm"], title: "RPM", unit: "", fontSize: 48, mainContext: context,),),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: nmeaData["etemp"], title: "Engine", unit: "\u2103", mainContext: context,),),
                        Expanded(child: SizedNMEABox(value: nmeaData["flevel"], title: "Fuel", unit: "%", mainContext: context,),),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: nmeaData["otemp"], title: "Oil", unit: "\u2103", mainContext: context,),),
                        Expanded(child: SizedNMEABox(value: nmeaData["opres"], title: "Oil", unit: " kpa", mainContext: context,),),
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
                        Expanded(child: SizedNMEABox(value: nmeaData["wtemp"], title: "Water Temp", unit: "\u2103", mainContext: context,),),
                      ],
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: nmeaData.keys.length,
                  itemBuilder: (BuildContext lcontext, int index) {
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
              SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0,8,0,24),
                      child: Text(
                        "NMEATrax Settings",
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 22,
                          decoration: TextDecoration.underline,
                          color: Theme.of(context).colorScheme.onBackground,
                          letterSpacing: 0.75,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          "Recording Mode",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                            fontSize: 18,
                          ),
                        ),
                        DropdownButton(
                          autofocus: false,
                          // value: recModeOptions.first,
                          value: recModeEnum[ntOptions["recMode"]],
                          // icon: const Icon(Icons.abc),
                          elevation: 8,
                          style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                          dropdownColor: Theme.of(context).colorScheme.background,
                          underline: Container(
                            height: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          items: recModeOptions.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setOptions("recMode=${recModeEnum.keys.firstWhere((element) => recModeEnum[element] == value)}");
                          },
                        ),
                      ],
                    ),
                    SettingsList(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      darkTheme: SettingsThemeData(
                        settingsSectionBackground: Theme.of(context).colorScheme.background,
                        settingsListBackground: Theme.of(context).colorScheme.surface,
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
                          tiles: [
                            // SettingsTile.navigation(
                            //   title: Text("Update", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                            //   onPressed: (context) {
                            //     getOptions();
                            //   },
                            // ),
                            SettingsTile.switchTile(
                              title: Text("Depth in Meters?", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                              initialValue: ntOptions["isMeters"],
                              onToggle: (value) {
                                setOptions("isMeters=$value");
                              },
                            ),
                            SettingsTile.switchTile(
                              title: Text("Temperature in Fahrenheit?", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                              initialValue: ntOptions["isDegF"],
                              onToggle: (value) {
                                setOptions("isDegF=$value");
                              },
                            ),
                            SettingsTile(
                              title: Text("Time Zone", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                              value: Text(ntOptions["timeZone"].toString(), style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                              onPressed: (lContext) {
                                showInputDialog(context, "Timezone", ntOptions["timeZone"], "timeZone");
                              },
                            ),
                            SettingsTile(
                              title: Text("Recording Interval (seconds)", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                              value: Text(ntOptions["recInt"].toString(), style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                              onPressed: (lContext) {
                                showInputDialog(context, "Recording Interval", ntOptions["recInt"], "recInt");
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                    ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: MaterialStatePropertyAll(Theme.of(context).colorScheme.primary),
                      ),
                      onPressed: () {
                        getOptions();
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadsPage()));
                      },
                      child: const Text('Voyage Recordings', style: TextStyle(fontSize: 18),),
                    ),
                  ]
                ),
              ),
            ]
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              if (connected) {
                setState(() {connected = false;});                
                sseUnsubscribe();
              } else {
                showConnectDialog(context, "IP Address");
              }
            },
            label: connected ? const Text("Disconnect") : const Text("Connect"),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

    //https://www.appsdeveloperblog.com/alert-dialog-with-a-text-field-in-flutter/
  showConnectDialog(BuildContext context, String title) {
    String input = connectURL;

    Widget confirmButton = ElevatedButton(
      child: const Text("Connect"),
      onPressed: () {
        setState(() {
          connectURL = input;
          sseSubscribe();
        });
        //https://stackoverflow.com/a/50683571 for nav.pop
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
    AlertDialog alert = AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(title),
      content: TextFormField(
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        autofocus: true,
        initialValue: connectURL,
        onChanged: (value) {
          setState(() {
            try {
              input = value;
            } on Exception {
              // do nothing
            }
          });
        },
        onFieldSubmitted: (value) {
          setState(() {
            connectURL = value;
            sseSubscribe();
          });
          Navigator.of(context, rootNavigator: true).pop();
        },
        // decoration: const InputDecoration(
        //   prefixIcon: Icon(
        //     Icons.language,
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

  showInputDialog(BuildContext context, String title, var setting, String parameter) {
    int input = 0;

    Widget confirmButton = ElevatedButton(
      child: const Text("Set"),
      onPressed: () {
        setState(() {
          setOptions("$parameter=$input");
        });
        //https://stackoverflow.com/a/50683571 for nav.pop
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
    AlertDialog alert = AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(title),
      content: TextFormField(
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        autofocus: true,
        initialValue: setting.toString(),
        onChanged: (value) {
          setState(() {
            try {
              input = int.parse(value);
            } on Exception {
              // do nothing
            }
          });
        },
        onFieldSubmitted: (value) {
          setState(() {
            setOptions("$parameter=$input");
          });
          Navigator.of(context, rootNavigator: true).pop();
        },
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

  sseSubscribe() async {
    channel = SseChannel.connect(Uri.parse('http://$connectURL/NMEATrax'));
    try {
      connected = true;
      if (connected) {
        stream = channel.stream.listen((message) {
          int i = 0;
          if (message.toString().substring(2, 5) != "rpm") {
          } else {
            nmeaData = jsonDecode(message);
            for (String element in nmeaData.values) {
              try {
                if (element.substring(0, 4) == "-273") {
                  var key = nmeaData.keys.elementAt(i);
                  nmeaData[key] = '-';
                }
                
              } on RangeError {
                // do nothing
              }
              i++;
            }
          }
          if (mounted) {
            setState(() {});
          } else {
            if (Platform.isAndroid) {KeepScreenOn.turnOff();}
          }
        });
      }
    } on SocketException {
      // do nothing
    }
    connected = true;
    _saveIP(connectURL);
    getOptions();
    if (Platform.isAndroid) {KeepScreenOn.turnOn();}
  }

  sseUnsubscribe() async {
    connected = false;
    if (Platform.isAndroid) {KeepScreenOn.turnOff();}
    stream?.pause();
    // stream?.cancel();
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
    'Latitude':50.0,
    'Longitude':-122.0,
    'Magnetic Variation (*)':20.0,
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
  }

  @override
  Widget build(BuildContext mainContext) {
    return MaterialApp(
      title: 'NMEATrax Replay',
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          drawer: Drawer(
            width: 200,
            backgroundColor: Theme.of(context).colorScheme.background,
            child: ListView(
              children: <Widget>[
                DrawerHeader(
                  decoration: const BoxDecoration(
                    image: DecorationImage(image: AssetImage('assets/images/nmeatraxLogo.png')),
                    color: Color(0xFF0050C7),
                  ),
                  child: Text('NMEATrax', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
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
                  applicationVersion: _appVersion,
                  aboutBoxChildren: const [
                    Text("For use with NMEATrax Vessel Monitoring System")
                  ],
                  child: Text('About app', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                ),
                Center(
                  child: ElevatedButton(
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Theme.of(context).colorScheme.primary),),
                    child: MyApp.themeNotifier.value == ThemeMode.light ? Icon(Icons.dark_mode_outlined, color: Theme.of(context).colorScheme.onPrimary,) : Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.onError,),
                    onPressed: () {
                      MyApp.themeNotifier.value =
                        MyApp.themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                      _saveTheme(MyApp.themeNotifier.value);
                    },
                  ),
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
                              _saveTheme(MyApp.themeNotifier.value);
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
  final double fontSize;
  final dynamic mainContext;

  const SizedNMEABox({
    Key? key,
    required this.value,
    required this.title,
    required this.unit,
    this.fontSize = 24,
    required this.mainContext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
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
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                    color: Theme.of(mainContext).colorScheme.onBackground,
                    fontSize: fontSize,
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

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  
  Future<void> getFilesList() async {
    final dlList = await http.get(Uri.parse('http://$connectURL/listDir'));

    if (dlList.statusCode == 200) {
      List<List<String>> converted = const CsvToListConverter(shouldParseNumbers: false).convert(dlList.body);
      downloadList = converted.elementAt(0);
      downloadList.removeAt(downloadList.length - 1);
      setState(() {});
    } else {
      throw Exception('Failed to get download list');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Voyage Recordings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: RefreshIndicator(
        onRefresh: getFilesList,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text("Tap on the file you wish to download"),
            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return StatefulBuilder(
                          builder: (aContext, setState) {
                            return AlertDialog(
                              title: const Text("Email Progress"),
                              content: Text(emailData),
                              actions: [
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {emailData = "";});
                                    SseChannel email = SseChannel.connect(Uri.parse('http://$connectURL/NMEATrax'));
                                    try {
                                      email.stream.listen((message) {
                                        if (message.toString().substring(2, 5) != "rpm") {
                                          if (aContext.mounted) {
                                            setState(() {
                                              emailData += message;
                                              emailData += "\r\n";
                                            });
                                          }
                                        }
                                      });
                                    } on SocketException {
                                      // do nothing
                                    }
                                    Future.delayed(const Duration(seconds: 2), () {
                                      http.post(Uri.parse("http://$connectURL/set?email=true"));
                                    },);
                                  },
                                  child: const Text("Send Email"),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    
                                    Navigator.of(context, rootNavigator: true).pop();
                                  },
                                  child: const Text("Close"),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                  child: const Text("Email Files"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Downloading all files...", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ));}
                    for (var file in downloadList) {
                      await downloadData(file);
                    }
                    if (mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Downloaded all files!", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ));}
                  },
                  child: const Text("Download All"),
                ),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Are you sure?"),
                          actions: [
                              ElevatedButton(
                                onPressed: () {
                                  http.post(Uri.parse("http://$connectURL/set?eraseData=true"));
                                  downloadList.clear();
                                  if (mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text("Erased all recordings", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                                    duration: const Duration(seconds: 5),
                                    backgroundColor: Theme.of(context).colorScheme.surface,
                                  ));}
                                  Navigator.of(context, rootNavigator: true).pop();
                                  setState(() {});
                                },
                              child: const Text("Yes"),
                            )
                          ],
                        );
                      },
                    );
                  },
                  child: const Text("Erase All"),
                ),
                // ElevatedButton(
                //   onPressed: getFilesList,
                //   child: const Text("Refresh")
                // ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: downloadList.length,
                itemBuilder: (BuildContext context, int index) {
                  return ListTile(
                    mouseCursor: MaterialStateMouseCursor.clickable,
                    hoverColor: Theme.of(context).colorScheme.surface,
                    leading: downloadList.elementAt(index).substring(downloadList.elementAt(index).length - 3) == 'gpx' ? const Icon(Icons.location_on) : const Icon(Icons.insert_drive_file),
                    title: Text(downloadList.elementAt(index)),
                    onTap: () async {
                      String s = await downloadData(downloadList.elementAt(index));
                      if (mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(s, style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                        duration: const Duration(seconds: 5),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                      ));}
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> downloadData(String fileName) async {
    String fileExt = fileName.substring(fileName.length - 4);
    final dynamic directory;
    final http.StreamedResponse streamedResponse;

    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }

    try {
      final request = http.Request('GET', Uri.parse('http://$connectURL/sdCard/$fileName'));
      streamedResponse = await request.send();
    } catch (e) {
      return "Error. Could not connect to NMEATrax.";
    }
    if (streamedResponse.statusCode == 200) {
      if (Platform.isAndroid) {
        directory = "/storage/emulated/0/Download";
      } else {
        directory = await getDownloadsDirectory();
      }
      
      fileName = fileName.substring(0, fileName.length - 4);

      String filePath = Platform.isAndroid ? "$directory/$fileName$fileExt" : "${directory?.path}\\$fileName$fileExt";

      File file = File(filePath);
      
      int i = 1;
      while (file.existsSync()) {
        if (i == 1) {
          fileName += " ($i)";
        } else {
          fileName = fileName.substring(0, fileName.length - 4);
          fileName += " ($i)";
        }
        i++;
        filePath = Platform.isAndroid ? "$directory/$fileName$fileExt" : "${directory?.path}\\$fileName$fileExt";
        file = File(filePath);
      }
      
      await streamedResponse.stream.pipe(file.openWrite());
      
      return "$fileName$fileExt saved to $filePath";
    } else {
      return "Error. Could not get $fileName$fileExt";
    }
  }
}