import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gpx/gpx.dart';
import 'package:csv/csv.dart';

import 'classes.dart';
import 'main.dart';

class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key});

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> with SingleTickerProviderStateMixin {

  List<List<dynamic>> csvListData = [];
  List<dynamic> csvHeaderData = [];
  List<List<LatLng>> gpxLL = [[const LatLng(0, 0)]];
  List<NmeaViolation> analyzedData = [];
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
  bool analyzeVisible = false;
  late TabController _tabController;

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  Map<String, dynamic> lowerLimits = <String, dynamic>{
    'RPM':0.0,
    'Engine Temp':273.15,
    'Oil Temp':273.15,
    'Oil Pressure':300.0,
    'Fuel Rate':0.0,
    'Fuel Level':10.0,
    'Fuel Efficiency':0.0,
    'Leg Tilt':0.0,
    'Speed':0.0,
    'Heading':0.0,
    'Depth':1.0,
    'Water Temp':275.15,
    'Battery Voltage':12.0,
    'Engine Hours':0.0,
    'Latitude':47.0,
    'Longitude':-125.0,
    'Magnetic Variation':0.0,
  };
  Map<String, dynamic> upperLimits = <String, dynamic>{
    'RPM':5200.0,
    'Engine Temp':353.15,
    'Oil Temp':388.15,
    'Oil Pressure':700.0,
    'Fuel Rate':50.0,
    'Fuel Level':100.0,
    'Fuel Efficiency':4.0,
    'Leg Tilt':100.0,
    'Speed':15.4333,
    'Heading':360.0,
    'Depth':304.8000000012192,
    'Water Temp':298.15,
    'Battery Voltage':15.0,
    'Engine Hours':3600000.0,
    'Latitude':50.0,
    'Longitude':-122.0,
    'Magnetic Variation':20.0,
  };

  Future<File> getFilePath(List<String> ext) async {
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

  Future<List<List<dynamic>>> loadCSV(File filePath) async {
    String csvData = await filePath.readAsString();
    List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(csvData);
    return rowsAsListOfValues;
  }

  Future<List<Wpt>> loadGPX(File filePath) async {
    String gpxData = await filePath.readAsString();
    var gpxWPTs = GpxReader().fromString(gpxData);
    var trackpts = gpxWPTs.trks[0].trksegs[0].trkpts;
    trackpts.removeWhere((element) => element.lat == 0);
    return trackpts;
  }
  
  void onSliderChanged(double value) {
    setState(() {
      curLineNum = value.toInt();
    });
  }

  void getCSV() async {
    gpxLL.clear();
    gpxNum.clear();
    if (gpxLL.isEmpty) {
      gpxLL.add([const LatLng(0, 0)]);
    }
    csvFilePath = await getFilePath(['csv']);
    if (csvFilePath.path != "null") {
      loadCSV(csvFilePath).then((rows) {
        if (rows.isNotEmpty) {
          csvListData = rows;
          csvHeaderData = rows[0];
          List<String> temp = [];
          for (String header in csvHeaderData) {
            if (header.contains(' (')) {
              temp.add(header.split(' (').first);
            } else {
              temp.add(header);
            }
          }
          csvHeaderData = temp;
          csvListData.removeAt(0);
          int i = 0;
          int j = 0;
          List<Wpt> waypoints = [];
          for (var row in csvListData) {
            for (var value in row) {
              if (value is! String) {
                if ((-273.0).compareTo(value) == 0) {
                  csvListData[i][j] = "-";
                }
                if (j == csvHeaderData.indexOf("Time Stamp")) {
                  if (csvListData[i][j] == 0) {
                    csvListData[i][j] = "-";
                  } else {
                    csvListData[i][j] = DateFormat('h:mm:ss a EEE MMM dd yyyy').format(DateTime.fromMillisecondsSinceEpoch(csvListData[i][j] * 1000, isUtc: false));
                  }
                }
              }
              j++;
            }
            j = 0;
            i++;

            if (row.elementAt(csvHeaderData.indexOf("Latitude")) != '-') {
              waypoints.add(Wpt(lat: row.elementAt(csvHeaderData.indexOf("Latitude")), lon: row.elementAt(csvHeaderData.indexOf("Longitude"))));
            }

          }
          setState(() {
            if (waypoints.isNotEmpty) {importGPX(waypoints);}
            curLineNum = 0;
            maxLines = csvListData.length - 1;
            errCount = 0;
            analyzedData.clear();
            analyzeVisible = false;
          });
        }
      });
    }
  }

  void getGPXfromCSV() async {
    csvFilePath = await getFilePath(['csv']);
    if (csvFilePath.path != "null") {
      loadCSV(csvFilePath).then((rows) {
        if (rows.isNotEmpty) {
          List<Wpt> waypoints = [];
          final headersRow = rows.first;
          rows.removeAt(0);
          for (var row in rows) {
            if (row.elementAt(headersRow.indexOf("Latitude")) != -273 && row.elementAt(headersRow.indexOf("Latitude")) != "-") {
              waypoints.add(Wpt(lat: row.elementAt(headersRow.indexOf("Latitude")), lon: row.elementAt(headersRow.indexOf("Longitude"))));
            }
          }
          if (waypoints.isNotEmpty) {importGPX(waypoints);}
        }
      });
    }
  }

  void getGPX(File filePath) async {
    gpxFilePath = await getFilePath(['gpx']);
    if (gpxFilePath.path.contains('.csv')) {return;}

    if (gpxFilePath.path != "null") {
      loadGPX(gpxFilePath).then((rows) {
        importGPX(rows);
      });
    }
  }

  void importGPX(List<Wpt> rows) {
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
  }

  void decrCurLineNum() {
    setState(() {
      if (curLineNum > 0) {
        curLineNum--;
      }
    });
  }

  void incrCurLineNum() {
    setState(() {
      if (curLineNum != maxLines){
        curLineNum++;
      }
    });
  }

  void analyzeData() {
    int i = 0;
    errCount = 0;
    analyzedData.clear();
    for (List<dynamic> row in csvListData) {
      int j = 0;
      for (dynamic col in row) {
        if (col is! String) {
          if ((col < lowerLimits[csvHeaderData[j]] || col > upperLimits[csvHeaderData[j]]) && col != -273.0) {
            if (!(csvHeaderData[j] == "Oil Pressure" && (col == 0 || col == 4))) {
              setState(() {
                analyzedData.add(NmeaViolation(name: csvHeaderData.elementAt(j), value: col, line: i));
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

  Future<void> savePrefs() async {
    final SharedPreferences prefs = await _prefs;
    setState(() {
      prefs.setBool('darkMode', MyApp.themeNotifier.value == ThemeMode.dark ? true : false);
      prefs.setString("lower", jsonEncode(lowerLimits));
      prefs.setString("upper", jsonEncode(upperLimits));
      prefs.setBool('isMeters', depthUnit == DepthUnit.meters ? true : false);
      prefs.setBool('isCelsius', tempUnit == TempUnit.celsius ? true : false);
      prefs.setBool('isLitre', fuelUnit == FuelUnit.litre ? true : false);
      prefs.setInt('speedUnit', speedUnit.index);
    });
  }

  Future<void> getPrefs() async {
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
    _tabController = TabController(length: 4, vsync: this, animationDuration: Durations.short4);
    getPrefs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          drawer: NmeaDrawer(
            option1Action: () {
              Navigator.pushReplacementNamed(context, '/live');
            },
            option2Action: () {
              Navigator.pushReplacementNamed(context, '/replay');
            },
            option3Action: () {
              Navigator.pushReplacementNamed(context, '/files');
            },
            toggleThemeAction: () {
              setState(() {
                MyApp.themeNotifier.value =
                  MyApp.themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                savePrefs();
              });
            },
            depthChanged: (selection) {
              setState(() {
                depthUnit = selection.first;
                savePrefs();
              });
            },
            tempChanged: (selection) {
              setState(() {
                tempUnit = selection.first;
                savePrefs();
              });
            },
            speedChanged: (selection) {
              setState(() {
                speedUnit = selection.first;
                savePrefs();
              });
            },
            fuelChanged: (selection) {
              setState(() {
                fuelUnit = selection.first;
                savePrefs();
              });
            },
            pressureChanged: (selection) {
              setState(() {
                pressureUnit = selection.first;
                savePrefs();
              });
            },
            useDepthOffsetChanged: (selection) {
              setState(() {
                useDepthOffset = selection!;
                savePrefs();
              });
            },
            appVersion: MyApp.appVersion,
            currentThemeMode: MyApp.themeNotifier.value,
            mainContext: context
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            systemOverlayStyle: SystemUiOverlayStyle(systemNavigationBarColor: Theme.of(context).colorScheme.surfaceContainer),
            backgroundColor: Theme.of(context).colorScheme.primary,
            iconTheme: Theme.of(context).primaryIconTheme,
            title: Text('NMEATrax Replay', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
            bottom: TabBar(
              controller: _tabController,
              onTap: (value) => setState(() {
                _tabController.animateTo(value);
                analyzeData();
                analyzeVisible = true;
                if (value != 3) {
                  selectedLimit = 0;
                }
              }),
              indicatorColor: Colors.white,
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
                color: Theme.of(mainContext).colorScheme.surfaceContainer,
                child: switch (_tabController.index) {
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
            controller: _tabController,
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
                                    csvFilePath.path == "null" ? "Open a file to view data" : csvFilePath.path.substring(csvFilePath.path.lastIndexOf(Platform.pathSeparator), csvFilePath.path.length),
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
                              onChanged: onSliderChanged,
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
                    ListAnalyzedData(
                      analyzedData: analyzedData,
                      mainContext: context,
                      action: (value) {
                        setState(() {
                          curLineNum = value;
                          _tabController.animateTo(0);
                        });
                      },
                    ),
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          height: 60,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
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
                      width: 250,
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
                    const SizedBox(height: 20),
                    ListTile(
                      title: Text(
                        "Lower Limit",
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface,),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 50),
                      leading: Icon(Icons.vertical_align_bottom, color: Theme.of(context).colorScheme.onSurface,),
                      trailing: Text(
                        UnitFunctions.returnInPreferredUnit(lowerLimits.keys.elementAt(selectedLimit), lowerLimits.values.elementAt(selectedLimit)).toString(), 
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      onTap: () => showInputDialog(context, "Enter lower limit", false),
                    ),
                    ListTile(
                      title: Text(
                        "Upper Limit",
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface,),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 50),
                      leading: Icon(Icons.vertical_align_top_outlined, color: Theme.of(context).colorScheme.onSurface,),
                      trailing: Text(
                        UnitFunctions.returnInPreferredUnit(upperLimits.keys.elementAt(selectedLimit), upperLimits.values.elementAt(selectedLimit)).toString(), 
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      onTap: () => showInputDialog(context, "Enter upper limit", true),
                    ),
                    // SettingsList(
                    //   physics: const NeverScrollableScrollPhysics(),
                    //   shrinkWrap: true,
                    //   darkTheme: SettingsThemeData(
                    //     settingsSectionBackground: Theme.of(context).colorScheme.surface,
                    //     settingsListBackground: Theme.of(context).colorScheme.surface,
                    //     titleTextColor: Theme.of(context).colorScheme.onSurface,
                    //   ),
                    //   lightTheme: SettingsThemeData(
                    //     settingsSectionBackground: Theme.of(context).colorScheme.surface,
                    //     settingsListBackground: Theme.of(context).colorScheme.surface,
                    //     titleTextColor: Theme.of(context).colorScheme.onSurface,
                    //   ),
                    //   platform: DevicePlatform.android,
                    //   sections: [
                    //     SettingsSection(
                    //       title: const Text(
                    //         "Lower Limit", 
                    //         style: TextStyle(
                    //           fontSize: 18,
                    //         ),
                    //       ),
                    //       tiles: [
                    //         SettingsTile.navigation(
                    //           title: Text(
                    //             // lowerLimits.values.elementAt(selectedLimit).toString(),
                    //             UnitFunctions.returnInPreferredUnit(lowerLimits.keys.elementAt(selectedLimit), lowerLimits.values.elementAt(selectedLimit)).toString(),
                    //             style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    //           ),
                    //           onPressed: (lcontext) {
                    //             showInputDialog(context, "Enter lower limit", false);
                    //           },
                    //         ),
                    //       ],
                    //     ),
                    //     SettingsSection(
                    //       title: const Text(
                    //         "Upper Limit", 
                    //         style: TextStyle(
                    //           fontSize: 18,
                    //         ),
                    //       ),
                    //       tiles: [
                    //         SettingsTile.navigation(
                    //           title: Text(
                    //             // upperLimits.values.elementAt(selectedLimit).toString(),
                    //             UnitFunctions.returnInPreferredUnit(upperLimits.keys.elementAt(selectedLimit), upperLimits.values.elementAt(selectedLimit)).toString(),
                    //             style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    //           ),
                    //           onPressed: (lcontext) {
                    //             showInputDialog(context, "Enter upper limit", true);
                    //           },
                    //         ),
                    //       ],
                    //     ),
                    //   ],
                    // ),
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
          onPressed: () => getCSV(),
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
            analyzeData();
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
          label: Text("CSV", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
          onPressed: () => getGPXfromCSV(),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: ElevatedButton.icon(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
            ),
            icon: Icon(Icons.location_on, color: Theme.of(context).colorScheme.onPrimary,),
            label: Text("GPX", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
            onPressed: () => getGPX(File("null")),
          ),
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
            savePrefs();
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
                // curLineNum = 0;
                gpxLL.removeAt(index);
                gpxNum.removeAt(index);
                if (gpxLL.isEmpty) {
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
            upperLimits[upperLimits.keys.elementAt(selectedLimit)] = UnitFunctions.convertToBaseUnit(input, upperLimits, selectedLimit);
            savePrefs();
          } else {
            lowerLimits[lowerLimits.keys.elementAt(selectedLimit)] = UnitFunctions.convertToBaseUnit(input, lowerLimits, selectedLimit);
            savePrefs();
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
                upperLimits[upperLimits.keys.elementAt(selectedLimit)] = UnitFunctions.convertToBaseUnit(double.parse(value), upperLimits, selectedLimit);
                savePrefs();
              } else {
                lowerLimits[lowerLimits.keys.elementAt(selectedLimit)] = UnitFunctions.convertToBaseUnit(double.parse(value), lowerLimits, selectedLimit);
                savePrefs();
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
