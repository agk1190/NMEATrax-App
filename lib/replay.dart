import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart'; // Suitable for most situations
// import 'package:flutter_map/plugin_api.dart'; // Only import if required functionality is not exposed by default
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gpx/gpx.dart';
import 'package:csv/csv.dart';
import 'package:settings_ui/settings_ui.dart';

import 'classes.dart';
import 'main.dart';

const _appVersion = '2.0.0';

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

class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key});

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {

  List<List<dynamic>> csvListData = [];
  List<dynamic> csvHeaderData = [];
  List<List<LatLng>> gpxLL = [[const LatLng(0, 0)]];
  List<List<String>> analyzedData = [];
  int curLineNum = 0;
  File csvFilePath = File("c");
  File gpxFilePath = File("c");
  num maxLines = 1;
  int errCount = 0;
  final mapController = MapController();
  final homeCoords = const LatLng(48.668070, -123.404493);
  int selectedLimit = 0;
  List<int> gpxNum = [];
  List<dynamic> gpxColors = [const Color(0xFF0050C7)];
  bool markerVisibility = false;
  int gpxToCsvOffset = 0;
  int gpxToCsvLineNum = 0;
  bool linkedFiles = false;

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
      if (curLineNum - gpxToCsvOffset >= 0) {
        gpxToCsvLineNum = curLineNum - gpxToCsvOffset;
      } else {
        gpxToCsvLineNum = 0;
      }
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
            int latIndex = csvHeaderData.indexWhere((element) => element == "Latitude");
            if (row.elementAt(latIndex) != '-' && gpxToCsvOffset == 0) {gpxToCsvOffset = i;}
            j = 0;
            i++;
          }
          setState(() {
            curLineNum = 0;
            gpxToCsvLineNum = 0;
            maxLines = csvListData.length - 1;
          });
        }
      });
    }
    gpxLL.clear();
    gpxLL.add([const LatLng(0, 0)]);
    gpxNum.clear();
    String cut = csvFilePath.path.substring(0, csvFilePath.path.lastIndexOf('.'));
    linkedFiles = true;
    _getGPX(File('$cut.gpx'));
  }

  void _getGPX(File filePath) async {
    if (filePath.existsSync()) {
      gpxFilePath = filePath;
    } else {
      gpxFilePath = await _getFilePath(['gpx', 'xml']);
    }
    if (gpxFilePath.path != "null") {
      _loadGPX(gpxFilePath).then((rows) {
        if (rows.isNotEmpty) {
          int idx = 0;
          if (gpxNum.isNotEmpty) {
            idx = gpxNum.length;
            gpxLL.add([const LatLng(0, 0)]);
          }
          if (gpxLL.isEmpty) {
            gpxLL.add([const LatLng(0, 0)]);
          }
          if (gpxLL.elementAt(idx).isNotEmpty) {gpxLL.elementAt(idx).clear();}
          for (Wpt wpt in rows) {
            gpxLL.elementAt(idx).add(LatLng(wpt.lat!, wpt.lon!));
          }
          setState(() {
            gpxNum.add(idx + 1);
            if (idx > 0 && idx >= gpxColors.length) {
              gpxColors.add(Color.fromARGB(255, Random().nextInt(255), Random().nextInt(255), Random().nextInt(255)));
            }
          });
        }
      });
    }
  }

  void _decrCurLineNum() {
    setState(() {
      if (curLineNum > 0) {
        curLineNum--;
        if (curLineNum - gpxToCsvOffset >= 0) {
          gpxToCsvLineNum = curLineNum - gpxToCsvOffset;
        } else {
          gpxToCsvLineNum = 0;
        }
      }
    });
  }

  void _incrCurLineNum() {
    setState(() {
      if (curLineNum != maxLines){
        curLineNum++;
        if (curLineNum - gpxToCsvOffset >= 0) {
          gpxToCsvLineNum = curLineNum - gpxToCsvOffset;
        } else {
          gpxToCsvLineNum = 0;
        }
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
    setState(() {
      lowerLimits = jsonDecode(prefs.getString("lower")!);
      upperLimits = jsonDecode(prefs.getString("upper")!);
    });
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
            systemOverlayStyle: SystemUiOverlayStyle(systemNavigationBarColor: Theme.of(context).colorScheme.background),
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
                    Text(csvFilePath.toString(), style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontSize: 14, fontWeight: FontWeight.w400),),
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
                alignment: AlignmentDirectional.topStart,
                children: [
                  Scaffold(
                    body: FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        center: homeCoords,
                        zoom: 13.0,
                        maxZoom: 18.0,
                        maxBounds: LatLngBounds(
                          const LatLng(-90.0, -180.0),
                          const LatLng(90.0, 180.0),
                        ),
                        keepAlive: true,
                        interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate & ~InteractiveFlag.flingAnimation,
                        onLongPress: (tapPosition, point) {
                          if (gpxLL[0].first != const LatLng(0,0)) {
                            mapController.move(gpxLL[0].first, 13);
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
                          userAgentPackageName: 'com.nmeatrax.app',
                          errorTileCallback: (tile, error, stackTrace) {},
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: gpxLL[0].length > 1 ? gpxLL.first.elementAt(gpxToCsvLineNum) : homeCoords,
                              width: 80,
                              height: 80,
                              builder: (context) {
                                if (markerVisibility) {
                                  return const Icon(Icons.directions_ferry);
                                } else {
                                  return const Text("");
                                }
                              },
                            ),
                          ],
                        ),
                        buildPolylinesLayer()
                      ],
                    ),
                    floatingActionButton: FloatingActionButton(
                      onPressed: () => _getGPX(File("c")),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.add),
                    ),
                  ),
                  Column(
                    children: [
                      Visibility(
                        visible: linkedFiles,
                        child: Slider(
                          value: curLineNum.toDouble(),
                          onChanged: _onSliderChanged,
                          label: curLineNum.toString(),
                          max: maxLines.toDouble(),
                          min: 0,
                          activeColor: Theme.of(context).colorScheme.primary,
                          inactiveColor: Theme.of(context).colorScheme.primaryContainer,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          height: 60,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              Visibility(
                                visible: linkedFiles,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                                  child: ElevatedButton(
                                    style: ButtonStyle(
                                      backgroundColor: MaterialStatePropertyAll(Theme.of(context).colorScheme.primary),
                                    ),
                                    onPressed: () => setState(() {markerVisibility = !markerVisibility;}), 
                                    child: const Icon(Icons.location_pin)
                                  ),
                                ),
                              ),
                              buildElevatedButtonRow(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 20),
                      child: Text(
                        "Analysis Limits",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    DropdownMenu(
                      initialSelection: upperLimits.keys.first,
                      menuStyle: MenuStyle(
                        backgroundColor: MaterialStatePropertyAll(Theme.of(context).colorScheme.surface),
                      ),
                      textStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                      enableSearch: false,
                      enableFilter: false,
                      dropdownMenuEntries: upperLimits.keys.map<DropdownMenuEntry<dynamic>>((String value) {
                        return DropdownMenuEntry<String>(
                          value: value,
                          label: value,
                        );
                      }).toList(),
                      onSelected: (value) {
                        setState(() {
                          final List mySet = Set.from(upperLimits.keys).toList();
                          int myIndex = mySet.indexOf(value);
                          selectedLimit = myIndex;
                        });
                      },
                    ),
                    SettingsList(
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
                            "Lower Limit", 
                            style: TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          tiles: [
                            SettingsTile.navigation(
                              title: Text(
                                lowerLimits.values.elementAt(selectedLimit).toString(),
                                style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                              ),
                              onPressed: (lcontext) {
                                showInputDialog(context, "Enter lower limit", false);
                              },
                            ),
                          ],
                        ),
                        SettingsSection(
                          title: const Text(
                            "Upper Limit", 
                            style: TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          tiles: [
                            SettingsTile.navigation(
                              title: Text(
                                upperLimits.values.elementAt(selectedLimit).toString(),
                                style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                              ),
                              onPressed: (lcontext) {
                                showInputDialog(context, "Enter upper limit", true);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ]
                ),
              ),
            ]
          ),
        ),
      ),
    );
  }

  PolylineLayer buildPolylinesLayer() {
    List<Polyline> polylines = [];
    int colorIndex = 0;
    for (List<LatLng> track in gpxLL) {
      final Polyline polyline = Polyline(
        points: track,
        color: gpxColors[colorIndex],
        strokeWidth: 3.0,
      );
      polylines.add(polyline);
      colorIndex++;
    }

    return PolylineLayer(
      polylineCulling: false,
      polylines: polylines,
    );
  }

  Widget buildElevatedButtonRow() {
    return ListView.builder(
      shrinkWrap: true,
      scrollDirection: Axis.horizontal,
      itemCount: gpxNum.length,
      itemBuilder: (lcontext, index) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStatePropertyAll(gpxColors[index]),
            ),
            onPressed: () {
              mapController.move(gpxLL.elementAt(index).first, 13);
            },
            onLongPress: () {
              setState(() {
                markerVisibility = false;
                curLineNum = 0;
                gpxToCsvLineNum = 0;
                gpxToCsvOffset = 0;
                gpxLL.removeAt(index);
                gpxNum.removeAt(index);
                if (gpxLL.isEmpty) {
                  linkedFiles = false;
                  gpxLL.add([const LatLng(0, 0)]);
                }
              });
            },
            child: const Icon(Icons.route_outlined),
          ),
        );
      },
    );
  }

  //https://www.appsdeveloperblog.com/alert-dialog-with-a-text-field-in-flutter/
  showInputDialog(BuildContext context, String title, bool upper) {
    double input = 0;

    Widget confirmButton = ElevatedButton(
      child: const Text("OK"),
      onPressed: () {
        setState(() {
          if (upper) {
            upperLimits[upperLimits.keys.elementAt(selectedLimit)] = input;
            _saveLimits("upper", upperLimits);
          } else {
            lowerLimits[lowerLimits.keys.elementAt(selectedLimit)] = input;
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
                upperLimits[upperLimits.keys.elementAt(selectedLimit)] = double.parse(value);
                _saveLimits("upper", upperLimits);
              } else {
                lowerLimits[lowerLimits.keys.elementAt(selectedLimit)] = double.parse(value);
                _saveLimits("lower", lowerLimits);
              }
            } on Exception {
              // do nothing
            }
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
}
