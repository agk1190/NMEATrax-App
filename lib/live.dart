import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:csv/csv.dart';

import 'classes.dart';
import 'downloads.dart';
import 'main.dart';
import 'wifi.dart';
import 'communications.dart';
import 'device_connection.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> with SingleTickerProviderStateMixin {
  Map<num, String> recModeEnum = {0:"Off", 1:"On", 2:"Auto by Speed", 3:"Auto by RPM", 4:"Auto by Speed", 5:"Auto by RPM"};
  Map<bool, String> wifiModeEnum = {false:"Client", true:"Host"};
  final List<String> recModeOptions = <String>['Off', 'On', 'Auto by Speed', 'Auto by RPM'];
  final List<String> wifiModeOptions = <String>['Client', 'Host'];
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  bool moreSettingsVisible = false;
  bool isDisconnecting = false;
  Timer? connectionTimeoutTimer;
  Timer? reconnectTimer;
  // bool reconnecting = false;
  late TabController _tabController;
  ConnectionMode lastConnectionMode = ConnectionMode.bluetooth;

  Future<void> savePrefs() async {
    final SharedPreferences prefs = await _prefs;
    setState(() {
      prefs.setBool('darkMode', MyApp.themeNotifier.value == ThemeMode.dark ? true : false);
      prefs.setString("ip", jsonEncode(connectURL));
      prefs.setBool('isMeters', depthUnit == DepthUnit.meters ? true : false);
      prefs.setBool('isCelsius', tempUnit == TempUnit.celsius ? true : false);
      prefs.setBool('isLitre', fuelUnit == FuelUnit.litre ? true : false);
      prefs.setBool('useOffset', useDepthOffset);
      prefs.setInt('speedUnit', speedUnit.index);
      prefs.setBool('lastConnectionModeBle', lastConnectionMode == ConnectionMode.bluetooth ? true : false);
    });
  }

  Future<void> getPrefs() async {
    final SharedPreferences prefs = await _prefs;
    if (prefs.getBool('darkMode') == null) {return;}
    if (prefs.getString("ip") == null) {return;}
    if (prefs.getBool("isMeters") == null) {return;}
    if (prefs.getBool("isCelsius") == null) {return;}
    if (prefs.getBool("isLitre") == null) {return;}
    if (prefs.getBool("useOffset") == null) {return;}
    if (prefs.getInt("speedUnit") == null) {return;}
    if (prefs.getBool("lastConnectionModeBle") == null) {return;}
    setState(() {
      prefs.getBool('darkMode')! == true ? MyApp.themeNotifier.value = ThemeMode.dark : MyApp.themeNotifier.value = ThemeMode.light;
      connectURL = jsonDecode(prefs.getString("ip")!);
      depthUnit = prefs.getBool('isMeters')! ? DepthUnit.meters : DepthUnit.feet;
      tempUnit = prefs.getBool('isCelsius')! ? TempUnit.celsius : TempUnit.fahrenheit;
      fuelUnit = prefs.getBool('isLitre')! ? FuelUnit.litre : FuelUnit.gallon;
      useDepthOffset = prefs.getBool('useOffset')!;
      int su = prefs.getInt('speedUnit')!;
      switch (su) {
        case 0:
          speedUnit = SpeedUnit.km;
          break;
        case 1:
          speedUnit = SpeedUnit.kn;
          break;
        case 2:
          speedUnit = SpeedUnit.mi;
          break;
        case 3:
          speedUnit = SpeedUnit.ms;
          break;
        default:
          speedUnit = SpeedUnit.kn;
      }
      lastConnectionMode = prefs.getBool('lastConnectionModeBle')! ? ConnectionMode.bluetooth : ConnectionMode.wifi;
    });
  }

  // Connect to nmea data stream
  void connectToNmeaDataStream() {
    engineData.errors = <String>[];
    DeviceConnection.create().connect(
      onDataStreamStarted: () {
        setState(() {
          if (Platform.isAndroid) {KeepScreenOn.turnOn();}
          savePrefs();
          startHeartbeat();
        });
      },
      onDataUpdated: () => setState(() {}),
      onSettingsUpdated: (data) => setState(() {
        nmeaDevice = nmeaDevice.updateFromJson(data);
      }),
      onDownloadsListUpdated: (_) {},
      onError: (msg) => setState(() {
        nmeaDevice.connected = false;
        engineData.errors = <String>[];
        engineData.errors!.add(msg);
      }),
    );
  }

  // Disconnect from nmea data stream
  void disconnectFromNmeaDataStream() {
    DeviceConnection.create().disconnect();
    setState(() {
      if (Platform.isAndroid) {KeepScreenOn.turnOff();}
      connectionTimeoutTimer?.cancel();
      reconnectTimer?.cancel();
      clearData();
      nmeaDevice = NmeaDevice();
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (isDeviceConnected) {
        return true; // Continue the loop
      }
      setState(() {
        isDisconnecting = false;
      });
      return false; // Stop the loop
    });
  }

  // Check if data is being received within the expected time frame
  void startHeartbeat() {
    connectionTimeoutTimer?.cancel();  // Cancel any existing heartbeat timer
    connectionTimeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final durationSinceLastData = now.difference(lastDataReceived);

      for (MapEntry<String, DateTime> msgName in lastDataTime.entries) {
        if (DateTime.now().difference(msgName.value).inSeconds > 5) {
          switch (msgName.key) {
            case 'engine':
              engineData = EngineData(id: 0);
              break;
            case 'gps':
              gpsData = GpsData(id: 0);
              break;
            case 'fluid':
              fluidLevel = FluidLevel(id: 0);
              break;
            case 'transmission':
              transmissionData = TransmissionData(id: 0);
              break;
            case 'temperature':
              temperatureData = TemperatureData(id: 0);
              break;
            case 'depth':
              depthData = DepthData(id: 0);
              break;
            default:
          }
          setState(() {});
        }
      }

      // Check if more than 5 seconds have passed without data
      if (durationSinceLastData.inSeconds >= 5) { // && !reconnecting
        // reconnecting = true;
        // reconnectDataStream();
        // print('Lost connection to data stream');
        disconnectFromNmeaDataStream();
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Connection Lost', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              content: const Text('Lost connection to data stream'),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Close', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    connectToNmeaDataStream();
                  },
                  child: Text('Reconnect', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                ),
              ],
            );
          },
        );
      }
    });
  }

  void clearData() {
    engineData = EngineData(id: 0);
    gpsData = GpsData(id: 0);
    fluidLevel = FluidLevel(id: 0);
    transmissionData = TransmissionData(id: 0);
    depthData = DepthData(id: 0);
    temperatureData = TemperatureData(id: 0);
    downloadList = List<Map<String, dynamic>>.empty(growable: true);
    nmeaDevice = NmeaDevice();
    if (Platform.isAndroid) {KeepScreenOn.turnOff();}
  }

  @override
  void initState() {
    getPrefs();
    super.initState();
    _tabController = TabController(length: 3, vsync: this, animationDuration: Durations.short4);
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(lcontext) {
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
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          drawer: NmeaDrawer(
            option1Action: () {
              // if (channel != null) disconnectWebSocket();
              if (nmeaDevice.connected) disconnectFromNmeaDataStream();
              Navigator.pushReplacementNamed(context, '/live');
            },
            option2Action: () {
              if (nmeaDevice.connected) disconnectFromNmeaDataStream();
              Navigator.pushReplacementNamed(context, '/replay');
            },
            option3Action: () {
              if (nmeaDevice.connected) disconnectFromNmeaDataStream();
              Navigator.pushReplacementNamed(context, '/files');
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
            toggleThemeAction: () {
              setState(() {
                MyApp.themeNotifier.value =
                  MyApp.themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
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
            systemOverlayStyle: SystemUiOverlayStyle(systemNavigationBarColor: Theme.of(context).colorScheme.surface),
            backgroundColor: Theme.of(context).colorScheme.primary,
            iconTheme: Theme.of(context).primaryIconTheme,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'NMEATrax Live',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(connectedDevice?.isConnected ?? false ? Icons.bluetooth_connected : Icons.bluetooth, color: connectedDevice?.isConnected ?? false ? Theme.of(context).colorScheme.onPrimary : Colors.grey,),
                Tooltip(
                  message: recModeEnum[nmeaDevice.recMode] ?? 'Recording Mode',
                  child: Icon(
                    switch (nmeaDevice.recMode) {
                      0 => Icons.motion_photos_off_outlined,
                      1 => Icons.motion_photos_on,
                      2 => Icons.motion_photos_auto,
                      3 => Icons.motion_photos_auto,
                      4 => Icons.motion_photos_auto_outlined,
                      5 => Icons.motion_photos_auto_outlined,
                      _ => Icons.motion_photos_off_outlined,
                    },
                    color: connectedDevice?.isConnected ?? false ? Theme.of(context).colorScheme.onPrimary : Colors.grey,
                  ),
                ),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              onTap: (value) => setState(() {
                _tabController.animateTo(value);
              }),
              indicatorColor: Colors.white,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard, color: Colors.white)),
                Tab(icon: Icon(Icons.navigation_rounded, color: Colors.white)),
                Tab(icon: Icon(Icons.settings, color: Colors.white)),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          displayTimeStamp(),
                        ],
                      ),
                    ),
                    Visibility(
                      visible: engineData.errors != null && engineData.errors!.isNotEmpty,
                      child: engineStatusChips(),
                    ),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(
                        value: returnAfterConversion(
                          gpsData.speedOverGround, ConversionType.speed), 
                          title: "Speed", 
                          unit: UnitFunctions.unitFor(ConversionType.speed), 
                          mainContext: context,
                          onDrag: (dy) {
                            setState(() {
                              int unitChange = (dy % 75).floor();
                              if (unitChange == 0) {
                                speedUnit = SpeedUnit.values[(speedUnit.index + 1) % SpeedUnit.values.length];
                              }
                            });
                          },
                        ),
                      SizedNMEABox(
                        value: returnAfterConversion(depthData.depthAdjusted, ConversionType.depth), 
                        title: "Depth", 
                        unit: UnitFunctions.unitFor(ConversionType.depth), 
                        mainContext: context,
                        onDrag: (dy) {
                          setState(() {
                            int unitChange = (dy % 25).floor();
                            if (unitChange == 0) {
                              depthUnit = depthUnit == DepthUnit.meters ? DepthUnit.feet : DepthUnit.meters;
                            }
                          });
                        },
                      ),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(value: returnAfterConversion(engineData.rpm, ConversionType.none), title: "RPM", unit: "", fontSize: 48, mainContext: context,),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(
                        value: returnAfterConversion(
                          engineData.coolantTemp, 
                          ConversionType.temp
                        ), 
                        title: "Engine", 
                        unit: UnitFunctions.unitFor(ConversionType.temp, leadingSpace: false), 
                        mainContext: context, 
                        onDrag: (dy) {
                          setState(() {
                            int unitChange = (dy % 25).floor();
                            if (unitChange == 0) {
                              tempUnit = tempUnit == TempUnit.celsius ? TempUnit.fahrenheit : TempUnit.celsius;
                            }
                          });
                        },
                      ),
                      SizedNMEABox(
                        value: returnAfterConversion(fluidLevel.level, ConversionType.none), 
                        title: "Fuel", 
                        unit: "%", 
                        mainContext: context,
                        onDrag: (dy) {
                          setState(() {
                            int unitChange = (dy % 25).floor();
                            if (unitChange == 0) {
                              fuelUnit = fuelUnit == FuelUnit.litre ? FuelUnit.gallon : FuelUnit.litre;
                            }
                          });
                        },
                      ),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(
                        value: returnAfterConversion(engineData.oilTemp, ConversionType.temp), 
                        title: "Oil", 
                        unit: UnitFunctions.unitFor(ConversionType.temp, leadingSpace: false), 
                        mainContext: context,
                        onDrag: (dy) {
                          setState(() {
                            int unitChange = (dy % 25).floor();
                            if (unitChange == 0) {
                              tempUnit = tempUnit == TempUnit.celsius ? TempUnit.fahrenheit : TempUnit.celsius;
                            }
                          });
                        },
                      ),
                      SizedNMEABox(
                        value: returnAfterConversion(engineData.oilPres, ConversionType.pressure), 
                        title: "Oil", 
                        unit: UnitFunctions.unitFor(ConversionType.pressure), 
                        mainContext: context,
                        onDrag: (dy) {
                          setState(() {
                            int unitChange = (dy % 25).floor();
                            if (unitChange == 0) {
                              pressureUnit = PressureUnit.values[(pressureUnit.index + 1) % PressureUnit.values.length];
                            }
                          });
                        },
                      ),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(
                        value: returnAfterConversion(engineData.fuelRate, ConversionType.fuelRate), 
                        title: "Fuel Rate", 
                        unit: UnitFunctions.unitFor(ConversionType.fuelRate), 
                        mainContext: context,
                        onDrag: (dy) {
                          setState(() {
                            int unitChange = (dy % 25).floor();
                            if (unitChange == 0) {
                              fuelUnit = fuelUnit == FuelUnit.litre ? FuelUnit.gallon : FuelUnit.litre;
                            }
                          });
                        },
                      ),
                      SizedNMEABox(
                        value: returnAfterConversion(engineData.efficieny, ConversionType.fuelEfficiency), 
                        title: "Efficiency", 
                        unit: UnitFunctions.unitFor(ConversionType.fuelEfficiency), 
                        mainContext: context,
                        onDrag: (dy) {
                          setState(() {
                            int unitChange = (dy % 25).floor();
                            if (unitChange == 0) {
                              fuelUnit = fuelUnit == FuelUnit.litre ? FuelUnit.gallon : FuelUnit.litre;
                            }
                          });
                        },
                      ),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(
                        value: returnAfterConversion(engineData.legTilt, ConversionType.none), 
                        title: "Leg Tilt", 
                        unit: "%", 
                        mainContext: context,
                      ),
                      SizedNMEABox(
                        value: returnAfterConversion(temperatureData.actualTemp, ConversionType.wTemp), 
                        title: "Water Temp", 
                        unit: UnitFunctions.unitFor(ConversionType.wTemp, leadingSpace: false), 
                        mainContext: context,
                        onDrag: (dy) {
                          setState(() {
                            int unitChange = (dy % 25).floor();
                            if (unitChange == 0) {
                              tempUnit = tempUnit == TempUnit.celsius ? TempUnit.fahrenheit : TempUnit.celsius;
                            }
                          });
                        },
                      ),
                    ]),
                  ],
                ),
              ),
              SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          displayTimeStamp(),
                        ],
                      ),
                    ),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(value: returnAfterConversion(gpsData.latitude, ConversionType.none, 6), title: "Latitude", unit: "°", mainContext: context,),
                      SizedNMEABox(value: returnAfterConversion(gpsData.longitude, ConversionType.none, 6), title: "Longitude", unit: "°", mainContext: context,),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(value: transmissionData.gear ?? '-', title: "Gear", unit: "", fontSize: 32, mainContext: context),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(
                        value: returnAfterConversion(gpsData.speedOverGround, ConversionType.speed), 
                        title: "Speed", 
                        unit: UnitFunctions.unitFor(ConversionType.speed), 
                        mainContext: context,
                        onDrag: (dy) {
                          setState(() {
                            int unitChange = (dy % 25).floor();
                            if (unitChange == 0) {
                              speedUnit = SpeedUnit.values[(speedUnit.index + 1) % SpeedUnit.values.length];
                            }
                          });
                        },
                      ),
                      SizedNMEABox(value: returnAfterConversion(gpsData.courseOverGround, ConversionType.none), title: "Course", unit: "°", mainContext: context,),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(value: returnAfterConversion(engineData.voltage, ConversionType.none, 2), title: "Voltage", unit: " V", mainContext: context,),
                      SizedNMEABox(value: returnAfterConversion(gpsData.magneticVariation, ConversionType.none, 2), title: "Magnetic Variation", unit: "°", mainContext: context,),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(value: returnAfterConversion(engineData.hours, ConversionType.none), title: "Engine Hours", unit: " h", mainContext: context,),
                    ]),
                  ],
                ),
              ),
              SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(    // heading
                      padding: const EdgeInsets.fromLTRB(0,8,0,24),
                      child: Text(
                        "NMEATrax Settings",
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 22,
                          // decoration: TextDecoration.underline,
                          color: Theme.of(context).colorScheme.onSurface,
                          letterSpacing: 0.75,
                        ),
                      ),
                    ),
                    Padding(    // Voyage Recordings Button
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
                        ),
                        onPressed: () {
                          getOptions();
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadsPage()));
                        },
                        child: Text('Voyage Recordings', style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onPrimary),),
                      ),
                    ),
                    Padding(    // Recording Mode
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerLow),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context, 
                            builder: (context) {
                              return AlertDialog(
                                backgroundColor: Theme.of(context).colorScheme.surface,
                                title: Text("Set Recording Mode", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    RadioGroup(
                                      groupValue: recModeEnum[nmeaDevice.recMode],
                                      onChanged: (String? value) {
                                        setOptions("recMode=${recModeEnum.keys.firstWhere((element) => recModeEnum[element] == value)}");
                                        Navigator.of(context).pop();
                                      }, 
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: recModeOptions.map((String value) {
                                          return RadioListTile(
                                            title: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                            value: value,
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                  // children: recModeOptions.map((String value) {
                                  //   return RadioListTile(
                                  //     title: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                  //     value: value,
                                  //     groupValue: recModeEnum[nmeaDevice.recMode],
                                  //     onChanged: (String? value) {
                                  //       setOptions("recMode=${recModeEnum.keys.firstWhere((element) => recModeEnum[element] == value)}");
                                  //       Navigator.of(context).pop();
                                  //     },
                                  //   );
                                  // }).toList(),
                                ),
                              );
                            },
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  "Recording Mode: ",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                              Text(
                                nmeaDevice.recMode != null ? "${recModeEnum[nmeaDevice.recMode]}" : '-',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(    // Recording Interval
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerLow),
                        ),
                        onPressed: () {
                          showInputDialog(context, "Set Recording Interval", nmeaDevice.recInterval, "recInt");
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                flex: 2,
                                child: Text(
                                  "Recording Interval: ",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  nmeaDevice.recInterval != null ? "${nmeaDevice.recInterval} seconds" : '-',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(    // WiFi Mode
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerLow),
                        ),
                        onPressed: () {
                          wiFiSettingsDialog(lcontext);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  "Host WiFi Mode: ",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  wifiModeEnum[nmeaDevice.isLocalAP] ?? '-',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(    // WiFi Mode
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerLow),
                        ),
                        onPressed: () {
                          communicationsMode(lcontext);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  "Communication Mode: ",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(nmeaDevice.commMode != null ?
                                  nmeaDevice.commMode == ConnectionMode.wifi ? "WiFi" : "Bluetooth" : '-',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Visibility(   // More Settings
                      visible: moreSettingsVisible,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            ListTile(
                              trailing: Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.onSurface,),
                              title: Text("Access Point Credentials", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const WifiPage()));
                              },
                            ),
                            ListTile(
                              trailing: Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.onSurface,),
                              title: Text("Firmware Update", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: Text("Start Firmware Update?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                      content: ElevatedButton(
                                        style: ButtonStyle(
                                          backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
                                        ),
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          setOptions('otaUpdate=true');
                                          if (!await launchUrl(Uri.parse('http://$connectURL/update'))) {
                                            throw Exception('Could not launch http://$connectURL/update');
                                          }
                                        },
                                        child: Text('Start', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            ListTile(
                              trailing: Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.onSurface,),
                              title: Text("Reboot", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: Text("Reboot NMEATrax?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                      content: ElevatedButton(
                                        style: ButtonStyle(
                                          backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
                                        ),
                                        onPressed: () async {
                                          setOptions('reboot=true');
                                          Navigator.of(context).pop();
                                        },
                                        child: Text('Reboot', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(    // More Settings Button
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton.icon(
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
                        ),
                        onPressed: () {setState(() {moreSettingsVisible = !moreSettingsVisible;});},
                        icon: Icon(
                          moreSettingsVisible ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        label: moreSettingsVisible
                          ? Text('Less Settings', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary))
                          : Text('More Settings', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary)),
                      ),
                    ),
                    Visibility(
                      visible: nmeaDevice.buildDate != null && nmeaDevice.buildDate != '',
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 25, 0, 8),
                        child: Text("Firmware v${nmeaDevice.firmware} built on ${nmeaDevice.buildDate}", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                      ),
                    ),
                  ]
                ),
              ),
            ]
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: isDisconnecting ? null : () async {
              final connection = DeviceConnection.create();
              if (connection.isConnected) {
                isDisconnecting = true;
                disconnectFromNmeaDataStream();
              } else {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (_) => _ConnectionTabDialog(
                    initialIpAddress: connectURL,
                    lastConnectionMode: lastConnectionMode,
                    onWifiConnect: (ipAddress) {
                      setState(() {
                        connectionMode = ConnectionMode.wifi;
                        lastConnectionMode = ConnectionMode.wifi;
                        connectURL = ipAddress;
                        connectToNmeaDataStream();
                      });
                    },
                    onDataStreamStarted: () {
                      setState(() {
                        if (Platform.isAndroid) {KeepScreenOn.turnOn();}
                        nmeaDevice.connected = true;
                        startHeartbeat();
                      });
                    },
                    onDataUpdated: () => setState(() {}),
                    onSettingsUpdated: (p0) => setState(() {
                      nmeaDevice = nmeaDevice.updateFromJson(p0);
                    }),
                    onDownloadsListUpdated: (_) {},
                  ),
                );
              }
            },
            label: isDeviceConnected ? const Text("Disconnect", style: TextStyle(color: Colors.white)) : const Text("Connect", style: TextStyle(color: Colors.white)),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Future<dynamic> communicationsMode(BuildContext lcontext) {
    ConnectionMode? commMode = nmeaDevice.commMode;
    return showDialog(
      context: lcontext,
      builder: (context) {
        return StatefulBuilder(
          builder: (aContext, setState) {
            return AlertDialog(
              title: Text('Communication Mode', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
              backgroundColor: Theme.of(context).colorScheme.surface,
              actionsAlignment: MainAxisAlignment.spaceBetween,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Communication Mode', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioGroup(
                        groupValue: commMode == null ? null : (commMode == ConnectionMode.wifi ? "WiFi" : "Bluetooth"),
                        onChanged: (String? value) {
                          setState(() {
                            commMode = value == "WiFi" ? ConnectionMode.wifi : ConnectionMode.bluetooth;
                          });
                        }, 
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: ["WiFi", "Bluetooth"].map((String value) {
                            return RadioListTile(
                              title: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                              value: value,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
                  ),
                  onPressed: () {
                    setOptions("commMode=${commMode == ConnectionMode.wifi ? "1" : "0"}");
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                  )
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<dynamic> wiFiSettingsDialog(BuildContext lcontext) {
    String wifiSSID = nmeaDevice.wifiSSID ?? '';
    String wifiPASS = nmeaDevice.wifiPass ?? '';
    String? newWifiModeValue = wifiModeEnum[nmeaDevice.isLocalAP];
    int fieldsChanged = 0;
    return showDialog(
      context: lcontext,
      builder: (context) {
        return StatefulBuilder(
          builder: (aContext, setState) {
            return AlertDialog(
              title: Text('WiFi Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
              backgroundColor: Theme.of(context).colorScheme.surface,
              actionsAlignment: MainAxisAlignment.spaceBetween,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('WiFi Mode', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioGroup(
                        groupValue: newWifiModeValue,
                        onChanged: (String? value) {
                          setState(() {
                            newWifiModeValue = value;
                            fieldsChanged += 1;
                          });
                        }, 
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: wifiModeOptions.map((String value) {
                            return RadioListTile(
                              title: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                              value: value,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    // children: wifiModeOptions.map((String value) {
                    //   return RadioListTile(
                    //     title: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                    //     value: value,
                    //     groupValue: newWifiModeValue,
                    //     onChanged: (String? value) {
                    //       setState(() {
                    //         newWifiModeValue = value;
                    //         fieldsChanged += 1;
                    //       });
                    //     },
                    //   );
                    // }).toList(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('SSID', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                  ),
                  TextFormField(
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_\-]')),
                      LengthLimitingTextInputFormatter(12),
                    ],
                    initialValue: nmeaDevice.wifiSSID,
                    autocorrect: false,
                    onChanged: (value) {
                      wifiSSID = value;
                      fieldsChanged += 2;
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Password', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                  ),
                  TextFormField(
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(15),
                    ],
                    initialValue: nmeaDevice.wifiPass,
                    autocorrect: false,
                    onChanged: (value) {
                      wifiPASS = value;
                      fieldsChanged += 4;
                    },
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.red)
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    eraseWifiPrompt(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Reset', style: TextStyle(color: Colors.black),),
                  )
                ),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
                  ),
                  onPressed: () {
                    if (wifiSSID.length < 2 || wifiPASS.length < 4 || newWifiModeValue == null) {
                      invalidWifiInputPopup(context);
                      return;
                    }
                    setOptions("wifiSSID=$wifiSSID");
                    setOptions("wifiPass=$wifiPASS");
                    setOptions("wifiMode=${wifiModeEnum.keys.firstWhere((element) => wifiModeEnum[element] == newWifiModeValue)}");
                    if (fieldsChanged != 0) {
                      Navigator.of(context).pop();
                      rebootRequiredPrompt(context);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                  )
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<dynamic> rebootRequiredPrompt(BuildContext context) {
    return showDialog(
      context: context, 
      builder: (context) {
        return AlertDialog(
          actionsAlignment: MainAxisAlignment.spaceBetween,
          title: Text('Reboot Required', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
          content: Text('A reboot is required to apply the changes', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              }, 
              child: Text("Later", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
            ),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
              ),
              onPressed: () {
                setOptions("reboot=true");
                Navigator.of(context).pop();
              },
              child: Text("Reboot", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
            ),
          ],
        );
      },
    );
  }

  Future<dynamic> invalidWifiInputPopup(BuildContext context) {
    return showDialog(
      context: context, 
      builder: (context) {
        return AlertDialog(
          title: Text('Invalid Input', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
          content: Text("Please enter a valid SSID, Password and select a WiFi Mode", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
          actions: [
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
              ),
              onPressed: () {
                Navigator.of(context).pop();
              }, 
              child: Text("OK", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
            ),
          ],
        );
      },
    );
  }

  Future<dynamic> eraseWifiPrompt(BuildContext context) {
    return showDialog(
      context: context, 
      builder: (context) {
        return AlertDialog(
          title: Text('Are you sure?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
          content: Text("Are you sure you want to erase all WiFi settings and reboot?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
          actions: [
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.red)
              ),
              onPressed: () {
                setOptions("eraseWiFi=true");
                Navigator.of(context).pop();
              }, 
              child: Text("Confirm", style: TextStyle(color: Colors.black),),
            ),
          ],
        );
      },
    );
  }

  engineStatusChips() {
    if (engineData.errors != null) {
    return SizedBox(  
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: engineData.errors!.length,
        itemBuilder: (lcontext, index) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
            child: Chip(
              elevation: 4,
              label: Text(engineData.errors!.elementAt(index)),
              backgroundColor: Theme.of(context).colorScheme.surface,
              labelStyle: const TextStyle(color: Colors.red),
              side: const BorderSide(color: Colors.red),
            ),
          );
        },
      ));
    } else {
      return const Text('');
    }
  }

  Text displayTimeStamp() {
    if (gpsData.unixTime == null) {
      return Text('-', style: TextStyle(color: Theme.of(context).colorScheme.onSurface));
    } else {
      return Text(DateFormat('h:mm:ss a EEE MMM dd yyyy').format(DateTime.fromMillisecondsSinceEpoch(gpsData.unixTime! * 1000, isUtc: false)), style: TextStyle(color: Theme.of(context).colorScheme.onSurface),);
    }
  }

  String returnAfterConversion(dynamic data, ConversionType type, [int decimalPlaces=0]) {
    if (data == -273) {return '-';}
    if (data == null) {return '-';}
    double value;
    if (data is int) {
      value = data.toDouble();
    } else {
      value = data;
    }
    
    switch (type) {
      case ConversionType.none:
        return value.toStringAsFixed(decimalPlaces);
      case ConversionType.temp:
        return (tempUnit == TempUnit.celsius ? value - 273.15 : ((value - 273.15) * (9/5) + 32)).toStringAsFixed(0);
      case ConversionType.wTemp:
        return (tempUnit == TempUnit.celsius ? value - 273.15 : ((value - 273.15) * (9/5) + 32)).toStringAsFixed(2);
      case ConversionType.depth:
        if (useDepthOffset) {
          return (depthUnit == DepthUnit.meters ? (value + depthData.offset!) : (value + depthData.offset!) * 3.280839895).toStringAsFixed(2);
        } else {
          return (depthUnit == DepthUnit.meters ? value : value * 3.280839895).toStringAsFixed(2);
        }
      case ConversionType.fuelRate:
        return (fuelUnit == FuelUnit.litre ? value : value * 0.26417205234375).toStringAsFixed(1);
      case ConversionType.fuelEfficiency:
        return (fuelUnit == FuelUnit.litre ? value : value * 2.35214583).toStringAsFixed(3);
      case ConversionType.pressure:
        switch (pressureUnit) {
          case PressureUnit.psi:
            return (value * 0.1450377377).toStringAsFixed(2);
          case PressureUnit.kpa:
            return value.toStringAsFixed(0);
          case PressureUnit.inHg:
            return (value * 0.296133971).toStringAsFixed(2);
          case PressureUnit.bar:
            return (value * 0.01).toStringAsFixed(2);
        }
      case ConversionType.speed:
        switch (speedUnit) {
          case SpeedUnit.km:
            return (value*3.6).toStringAsFixed(2);
          case SpeedUnit.kn:
            return (value * (3600/1852)).toStringAsFixed(2);
          case SpeedUnit.mi:
           return (value * 2.2369362920544025).toStringAsFixed(2);
          case SpeedUnit.ms:
            return (value).toStringAsFixed(2);
        }
    }
  }

  showInputDialog(BuildContext context, String title, var setting, String parameter) {
    final TextEditingController inputController = TextEditingController();
    inputController.text = setting.toString();

    void confirmValue() async {
      Navigator.of(context, rootNavigator: true).pop();
      await setOptions("$parameter=${inputController.text}");
      setState(() {});
    }

    Widget confirmButton = ElevatedButton(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
      ),
      child: Text("Set", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
      onPressed: () {
        confirmValue();
      },
    );
    AlertDialog alert = AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(title),
      content: TextFormField(
        controller: inputController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        autofocus: true,
        onFieldSubmitted: (value) {
          confirmValue();
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

class _ConnectionTabDialog extends StatefulWidget {
  final String initialIpAddress;
  final ConnectionMode lastConnectionMode;
  final Function(String) onWifiConnect;
  final Function() onDataStreamStarted;
  final Function() onDataUpdated;
  final Function(Map<String, dynamic>) onSettingsUpdated;
  final Function(List<Map<String, dynamic>>) onDownloadsListUpdated;

  const _ConnectionTabDialog({
    required this.initialIpAddress,
    required this.lastConnectionMode,
    required this.onWifiConnect,
    required this.onDataStreamStarted,
    required this.onDataUpdated,
    required this.onSettingsUpdated,
    required this.onDownloadsListUpdated,
  });

  @override
  State<_ConnectionTabDialog> createState() => _ConnectionTabDialogState();
}

class _ConnectionTabDialogState extends State<_ConnectionTabDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _connectionTabController;
  late final TextEditingController _ipController;

  @override
  void initState() {
    super.initState();
    _connectionTabController = TabController(length: 2, vsync: this);
    _connectionTabController.index = widget.lastConnectionMode == ConnectionMode.bluetooth ? 1 : 0;
    _ipController = TextEditingController(text: widget.initialIpAddress);
  }

  @override
  void dispose() {
    _connectionTabController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  void _connectWifi() {
    widget.onWifiConnect(_ipController.text);
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      title: Text(
        'Connect',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _connectionTabController,
              labelColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'WiFi'),
                Tab(text: 'Bluetooth'),
              ],
            ),
            SizedBox(
              height: 200,
              child: TabBarView(
                controller: _connectionTabController,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IP Address',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _ipController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: false,
                          ),
                          // autofocus: true,
                          onFieldSubmitted: (_) => _connectWifi(),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          onPressed: _connectWifi,
                          child: Text(
                            'Connect',
                            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _BleScanConnectPage(
                    onDataStreamStarted: widget.onDataStreamStarted,
                    onDataUpdated: widget.onDataUpdated,
                    onSettingsUpdated: widget.onSettingsUpdated,
                    onDownloadsListUpdated: widget.onDownloadsListUpdated,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // actions: [
      //   TextButton(
      //     onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      //     child: Text(
      //       'Close',
      //       style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      //     ),
      //   ),
      // ],
    );
  }
}

class _BleScanConnectPage extends StatefulWidget {
  final Function() onDataStreamStarted;
  final Function() onDataUpdated;
  final Function(Map<String, dynamic>) onSettingsUpdated;
  final Function(List<Map<String, dynamic>>) onDownloadsListUpdated;

  const _BleScanConnectPage({
    required this.onDataStreamStarted,
    required this.onDataUpdated,
    required this.onSettingsUpdated,
    required this.onDownloadsListUpdated,
  });

  @override
  State<_BleScanConnectPage> createState() => _BleScanConnectPageState();
}

class _BleScanConnectPageState extends State<_BleScanConnectPage> {
  final List<ScanResult> _foundDevices = [];
  bool _isScanning = true;
  bool _isConnecting = false;
  String _connectingToName = '';
  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  StreamSubscription<bool>? _isScanSub;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanResultsSub?.cancel();
    _isScanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void _startScan() {
    _scanResultsSub?.cancel();
    _isScanSub?.cancel();
    setState(() {
      _foundDevices.clear();
      _isScanning = true;
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.advertisementData.serviceUuids.contains(serviceUuid)) {
          final alreadyFound = _foundDevices.any(
            (e) => e.device.remoteId == r.device.remoteId,
          );
          if (!alreadyFound && mounted) {
            setState(() => _foundDevices.add(r));
          }
        }
      }
    });

    _isScanSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) setState(() => _isScanning = scanning);
    });
  }

  void _connectTo(ScanResult result) {
    FlutterBluePlus.stopScan();
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : 'NMEATrax';
    setState(() {
      _isConnecting = true;
      _connectingToName = name;
    });

    BLEServices.connectToDevice(
      result.device,
      () {
        widget.onDataStreamStarted();
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      },
      widget.onDataUpdated,
      widget.onSettingsUpdated,
      widget.onDownloadsListUpdated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<ScanResult>.from(_foundDevices)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    if (_isConnecting) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Connecting to $_connectingToName...',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      _isScanning ? 'Scanning for NMEATrax devices...' : 'No devices found.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final r = sorted[index];
                      final name = r.device.platformName.isNotEmpty
                          ? r.device.platformName
                          : 'NMEATrax';
                      return ListTile(
                        leading: Icon(
                          Icons.bluetooth,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          name,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                        subtitle: Text(
                          r.device.remoteId.str,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        trailing: Text(
                          '${r.rssi} dBm',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        onTap: () => _connectTo(r),
                      );
                    },
                  ),
          ),
          if (!_isScanning)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _startScan,
                child: Text(
                  'Scan Again',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
