import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gpx/gpx.dart';
import 'package:csv/csv.dart';
import 'package:settings_ui/settings_ui.dart';

import 'classes.dart';
import 'main.dart';

const _appVersion = '4.1.0';

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
  File csvFilePath = File("null");
  File gpxFilePath = File("null");
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
  bool analyzeVisible = false;

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

  Future<File> _getFilePath(List<String> ext) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ext);
      if (result != null) {
        File file = File(result.files.single.path!);
        return file;
      } else {
        // User canceled the picker
        // return File("null");
        return csvFilePath;
      }
  }

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

  void _getCSV([bool linked = false]) async {
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
            errCount = 0;
            analyzedData.clear();
            analyzeVisible = false;
          });
        }
      });
      if (linked) {
        setState(() {
          gpxLL.clear();
          gpxLL.add([const LatLng(0, 0)]);
          gpxNum.clear();
          linkedFiles = true;
        });
        String cut = csvFilePath.path.substring(0, csvFilePath.path.lastIndexOf('.'));
        _getGPX(File('$cut.gpx'), true);
      } else {
        setState(() {
          linkedFiles = false;
          markerVisibility = false;
        });
      }
    }
  }

  void _getGPX(File filePath, [bool fromLinked = false]) async {
    if (fromLinked) {
      if (filePath.existsSync()) {
        gpxFilePath = filePath;
      } else {
        return;
      }
    } else {
      setState(() {
        linkedFiles = false;
        markerVisibility = false;
        gpxFilePath = File("null");
      });
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
            if (!(csvHeaderData[j] == "Oil Pressure (kpa)" && (col == 0 || col == 4))) {
              setState(() {
                analyzedData.add([csvHeaderData[j] + ':', ' $col @ line $i']);
                errCount++;
              });
            }
          }
        }
        j++;
      }
      i++;
    }
  }

  Future<void> _savePrefs() async {
    final SharedPreferences prefs = await _prefs;

    setState(() {
      prefs.setBool('darkMode', MyApp.themeNotifier.value == ThemeMode.dark ? true : false);
      prefs.setString("lower", jsonEncode(lowerLimits));
      prefs.setString("upper", jsonEncode(upperLimits));
    });
  }

  Future<void> _getPrefs() async {
    final SharedPreferences prefs = await _prefs;
    if (prefs.getBool('darkMode') == null) {return;}
    if (prefs.getString("lower") == null) {return;}
    if (prefs.getString("upper") == null) {return;}
    setState(() {
      lowerLimits = jsonDecode(prefs.getString("lower")!);
      upperLimits = jsonDecode(prefs.getString("upper")!);
      if (prefs.getBool('darkMode')!) {
        MyApp.themeNotifier.value = ThemeMode.dark;
      } else {
        MyApp.themeNotifier.value = ThemeMode.light;
      }
    });
  }
  
  @override
  void initState() {
    super.initState();
    _getPrefs();
  }

  @override
  Widget build(BuildContext mainContext) {
    return MaterialApp(
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
          ).copyWith(
            primary: const Color(0xFF0050C7),
            onPrimary: Colors.white,
          ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF0050C7),
          onPrimary: Colors.white,
        ),
      ),
      title: 'NMEATrax Replay',
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          drawer: Drawer(
            width: 200,
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: ListView(
              children: <Widget>[
                DrawerHeader(
                  decoration: const BoxDecoration(
                    image: DecorationImage(image: AssetImage('assets/images/nmeatraxLogo.png')),
                    color: Color(0xFF0050C7),
                  ),
                  child: Text('NMEATrax', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                ),
                ListTile(
                  textColor: Theme.of(context).colorScheme.onSurface,
                  iconColor: Theme.of(context).colorScheme.onSurface,
                  title: const Text('Live'),
                  leading: const Icon(Icons.bolt),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/live');
                  },
                ),
                ListTile(
                  textColor: Theme.of(context).colorScheme.onSurface,
                  iconColor: Theme.of(context).colorScheme.onSurface,
                  title: Text('Replay', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                  leading: const Icon(Icons.timeline),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/replay');
                  },
                ),
                AboutListTile(
                  icon: Icon(
                    color: Theme.of(context).colorScheme.onSurface,
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
                  child: Text('About app', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                ),
                Center(
                  child: ElevatedButton(
                    style: ButtonStyle(backgroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.primary),),
                    child: MyApp.themeNotifier.value == ThemeMode.light ? Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.onPrimary,) : Icon(Icons.light_mode, color: Theme.of(context).colorScheme.onPrimary,),
                    onPressed: () {
                      MyApp.themeNotifier.value =
                        MyApp.themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                      _savePrefs();
                    },
                  ),
                ),
              ],
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            systemOverlayStyle: SystemUiOverlayStyle(systemNavigationBarColor: Theme.of(context).colorScheme.surface),
            backgroundColor: Theme.of(context).colorScheme.primary,
            iconTheme: Theme.of(context).primaryIconTheme,
            title: Text('NMEATrax Replay', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
            bottom: TabBar(
              onTap: (value) => setState(() {}),
              indicatorColor: Theme.of(context).colorScheme.secondary,
              tabs: const [
                Tab(icon: Icon(Icons.directions_boat_sharp, color: Colors.white)),
                Tab(icon: Icon(Icons.analytics, color: Colors.white)),
                Tab(icon: Icon(Icons.map, color: Colors.white)),
                Tab(icon: Icon(Icons.settings, color: Colors.white)),
              ],
            ),
          ),
          bottomNavigationBar: Builder(
            builder: (context) {
              return BottomAppBar(
                color: Theme.of(mainContext).colorScheme.surfaceContainerLow,
                child: switch (DefaultTabController.of(context).index) {
                  0 => dataAppBar(context),
                  1 => analyzeAppBar(mainContext),
                  2 => mapAppBar(context),
                  3 => settingsAppBar(context),
                  int() => const Row(),
                }
              );
            }
          ),
          body: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              LayoutBuilder(
                builder: (BuildContext mainContext, BoxConstraints viewportConstraints) {
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
                                    csvFilePath.path == "null" ? "Open a file to view data" : csvFilePath.path.substring(csvFilePath.path.lastIndexOf(Platform.isWindows ? '\\' : '/'), csvFilePath.path.length),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      fontStyle: FontStyle.italic
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text("Line $curLineNum", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                ),
                              ],
                            ),
                            Expanded(child: ListData(csvHeaderData: csvHeaderData, csvListData: csvListData, curLineNum: curLineNum, mainContext: context)),
                            const SizedBox(height: 20),
                            Slider(
                              value: curLineNum.toDouble(),
                              onChanged: _onSliderChanged,
                              label: curLineNum.toString(),
                              max: maxLines.toDouble(),
                              min: 0,
                              divisions: maxLines.toInt(),
                              activeColor: Theme.of(context).colorScheme.primary,
                              inactiveColor: Theme.of(context).colorScheme.primaryContainer,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              ),
              SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 15),
                    Text(
                      "Results:",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16, 
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    ),
                    Visibility(
                      visible: analyzeVisible,
                      child: Text(
                        "$errCount Violation${errCount == 1 ? '' : 's'} Found", 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16, 
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center
                      ),
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
                        initialCenter: homeCoords,
                        initialZoom: 13.0,
                        maxZoom: 18.0,
                        cameraConstraint: const CameraConstraint.unconstrained(),
                        keepAlive: true,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate & ~InteractiveFlag.flingAnimation,
                        ),
                        onLongPress: (tapPosition, point) {
                          if (gpxLL[0].first != const LatLng(0,0)) {
                            mapController.move(gpxLL[0].first, 13);
                          } else {
                            mapController.move(homeCoords, 13);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                          userAgentPackageName: 'com.nmeatrax.app',
                          errorTileCallback: (tile, error, stackTrace) {},
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: linkedFiles ? gpxLL.first.elementAt(gpxToCsvLineNum) : homeCoords,
                              width: 80,
                              height: 80,
                              child: markerVisibility ? const Icon(Icons.directions_ferry) : const Text(""),
                            ),
                          ],
                        ),
                        buildPolylinesLayer(),
                        const RichAttributionWidget(
                          alignment: AttributionAlignment.bottomLeft,
                          showFlutterMapAttribution: false,
                          attributions: [
                            TextSourceAttribution(
                              'OpenStreetMap contributors',
                            ),
                          ],
                        ),
                      ],
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
                                      backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
                                    ),
                                    onPressed: () => setState(() {markerVisibility = !markerVisibility;}), 
                                    child: Icon(Icons.location_pin, color: Theme.of(context).colorScheme.onPrimary,)
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
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    DropdownMenu(
                      initialSelection: upperLimits.keys.first,
                      menuStyle: MenuStyle(
                        backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surface),
                        surfaceTintColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerHighest),
                      ),
                      textStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                      ),
                      enableSearch: false,
                      enableFilter: false,
                      dropdownMenuEntries: upperLimits.keys.map<DropdownMenuEntry<dynamic>>((String value) {
                        return DropdownMenuEntry<String>(
                          value: value,
                          label: value,
                          style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.onSurfaceVariant))
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
                        settingsSectionBackground: Theme.of(context).colorScheme.surface,
                        settingsListBackground: Theme.of(context).colorScheme.surface,
                        titleTextColor: Theme.of(context).colorScheme.onSurface,
                      ),
                      lightTheme: SettingsThemeData(
                        settingsSectionBackground: Theme.of(context).colorScheme.surface,
                        settingsListBackground: Theme.of(context).colorScheme.surface,
                        titleTextColor: Theme.of(context).colorScheme.onSurface,
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
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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

  Row dataAppBar(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
          ),
          icon: Icon(Icons.file_open_outlined, color: Theme.of(context).colorScheme.onPrimary,),
          label: Text("CSV", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
          onPressed: () => _getCSV(false),
        ),
        const Spacer(),
        IconButton(
          onPressed: _decrCurLineNum,
          icon: const Icon(Icons.arrow_circle_left_outlined),
          color: Theme.of(context).colorScheme.primary,
          iconSize: 35,
        ),
        IconButton(
          onPressed: _incrCurLineNum,
          icon: const Icon(Icons.arrow_circle_right_outlined),
          color: Theme.of(context).colorScheme.primary,
          iconSize: 35,
        ),
      ],
    );
  }

  Row analyzeAppBar(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Visibility(
          visible: analyzeVisible,
          child: Text(
            "${analyzedData.length} Violation${analyzedData.length == 1 ? '.' : 's.'}",
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          )
        ),
        const Spacer(),
        ElevatedButton(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
          ),
          onPressed: () {
            _analyzeData();
            setState(() {analyzeVisible = true;});
          },
          child: Text("Refresh", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
        ),
      ],
    );
  }

  Row mapAppBar(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(),
        ElevatedButton.icon(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
          ),
          icon: Icon(Icons.location_on, color: Theme.of(context).colorScheme.onPrimary,),
          label: Text("GPX", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
          onPressed: () => _getGPX(File("null")),
        ),
      ],
    );
  }

  Row settingsAppBar(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            MyApp.themeNotifier.value =
              MyApp.themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
            _savePrefs();
          },
          icon: MyApp.themeNotifier.value == ThemeMode.light ? Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.surface,) : Icon(Icons.light_mode, color: Theme.of(context).colorScheme.onPrimary,),
        ),
      ],
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
              backgroundColor: WidgetStatePropertyAll(gpxColors[index]),
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
            child: Icon(Icons.route_outlined, color: Theme.of(context).colorScheme.onPrimary,),
          ),
        );
      },
    );
  }

  //https://www.appsdeveloperblog.com/alert-dialog-with-a-text-field-in-flutter/
  showInputDialog(BuildContext context, String title, bool upper) {
    double input = 0;

    Widget confirmButton = ElevatedButton(
      style: ButtonStyle(
        backgroundColor:WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
      ),
      child: Text("OK", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
      onPressed: () {
        setState(() {
          if (upper) {
            upperLimits[upperLimits.keys.elementAt(selectedLimit)] = input;
            _savePrefs();
          } else {
            lowerLimits[lowerLimits.keys.elementAt(selectedLimit)] = input;
            _savePrefs();
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
                _savePrefs();
              } else {
                lowerLimits[lowerLimits.keys.elementAt(selectedLimit)] = double.parse(value);
                _savePrefs();
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
