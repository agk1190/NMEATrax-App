import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:eventflux/eventflux.dart';

import 'classes.dart';
import 'downloads.dart';
import 'main.dart';
import 'wifi.dart';
import 'communications.dart';

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
  DateTime lastDataReceived = DateTime.now();
  Timer? connectionTimeoutTimer;
  Timer? reconnectTimer;
  // bool reconnecting = false;
  EngineData engineData = EngineData(id: 0);
  GpsData gpsData = GpsData(id: 0);
  FluidLevel fluidLevel = FluidLevel(id: 0);
  TransmissionData transmissionData = TransmissionData(id: 0);
  DepthData depthData = DepthData(id: 0);
  TemperatureData temperatureData = TemperatureData(id: 0);
  late TabController _tabController;
  Map<String, DateTime> lastDataTime = {};

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
        case 1:
          speedUnit = SpeedUnit.kn;
        case 2:
          speedUnit = SpeedUnit.mi;
        case 3:
          speedUnit = SpeedUnit.ms;
          break;
        default:
          speedUnit = SpeedUnit.kn;
      }
    });
  }

  // Connect to nmea data stream
  void connectToNmeaDataStream() async {
    engineData.errors = <String>[]; // Clear any existing errors
    if (!nmeaDevice.connected) {
      final validIP = await Ping(connectURL, count: 1).stream.first;
      if (validIP.summary == null && validIP.error == null) {
        EventFlux.instance.connect(
          EventFluxConnectionType.get,
          'http://$connectURL/NMEATrax',
          onSuccessCallback: (EventFluxResponse? response) {
            nmeaDevice.connected = true;
            setState(() {
              getOptions();
              if (Platform.isAndroid) {KeepScreenOn.turnOn();}
              savePrefs();
              // if (!reconnecting) {
              //   startHeartbeat();
              //   reconnecting = false;
              // }
              startHeartbeat();
            });
            response?.stream?.listen((event) {
              updateFromEvent(event);
            });
          },
          autoReconnect: false,
          reconnectConfig: ReconnectConfig(
            mode: ReconnectMode.linear,
            interval: Duration(seconds: 5),
            maxAttempts: 5,
          ),
          onError: (p0) {
            setState(() {
              nmeaDevice.connected = false;
              engineData.errors = <String>[];
              engineData.errors!.add("Error connecting to data stream");
            });
          },
        );
      } else {
        setState(() {
          nmeaDevice.connected = false;
          engineData.errors = <String>[];
          engineData.errors!.add("Bad IP Address");
        });
      }
    }
  }

  void updateFromEvent(EventFluxData event) async {
    String msgId;
    Map<String, dynamic> nmeaData;
    try {
      msgId = jsonDecode(event.data).values.first;
      nmeaData = jsonDecode(event.data).values.last;
    } on Exception {
      return;
    }
    // print(event.data);

    switch (msgId) {
      case '127488':
      case '127489':
        engineData = engineData.updateFromJson(nmeaData);
        lastDataTime['engine'] = DateTime.now();
        break;
      case '127258':
      case '129026':
      case '129029':
        gpsData = gpsData.updateFromJson(nmeaData);
        lastDataTime['gps'] = DateTime.now();
        break;
      case '127505':
        fluidLevel = fluidLevel.updateFromJson(nmeaData);
        lastDataTime['fluid'] = DateTime.now();
        break;
      case '127493':
        transmissionData = transmissionData.updateFromJson(nmeaData);
        lastDataTime['transmission'] = DateTime.now();
        break;
      case '130312':
        temperatureData = temperatureData.updateFromJson(nmeaData);
        lastDataTime['temperature'] = DateTime.now();
        break;
      case '128267':
        depthData = depthData.updateFromJson(nmeaData);
        lastDataTime['depth'] = DateTime.now();
        break;
      // case '161616':
      //   engineData = engineData.updateErrorsFromJson(nmeaData);
      //   break;
      case '000000':
        // heartbeat message
        break;
      case 'email':
        // emailMessages.add(nmeaData['msg']);
        emailMessagesNotifier.value = List.from(emailMessagesNotifier.value)..add(nmeaData['msg']);
        break;
      default:
    }

    lastDataReceived = DateTime.now();

    // if (_tabController.index != 2) {
      setState(() {});
    // }
  }

  // Disconnect from nmea data stream
  void disconnectFromNmeaDataStream() {
    EventFlux.instance.disconnect();
    setState(() {
      if (Platform.isAndroid) {KeepScreenOn.turnOff();}
      connectionTimeoutTimer?.cancel();
      reconnectTimer?.cancel();
      clearData();
      nmeaDevice = NmeaDevice();
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
    downloadList = <String>[];
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
                    color: Theme.of(context).colorScheme.onPrimary,
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
                        value: returnAfterConversion(depthData.depth, ConversionType.depth), 
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
                                  children: recModeOptions.map((String value) {
                                    return RadioListTile(
                                      title: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                      value: value,
                                      groupValue: recModeEnum[nmeaDevice.recMode],
                                      onChanged: (String? value) {
                                        setOptions("recMode=${recModeEnum.keys.firstWhere((element) => recModeEnum[element] == value)}");
                                        Navigator.of(context).pop();
                                      },
                                    );
                                  }).toList(),
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
                                  "WiFi Mode: ",
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
                    Visibility(   // More Settings
                      visible: moreSettingsVisible,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            ListTile(
                              trailing: Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.onSurface,),
                              title: Text("WiFi Settings", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
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
            onPressed: () {
              if (nmeaDevice.connected) {
                disconnectFromNmeaDataStream();
                nmeaDevice.connected = false;
              } else {
                showConnectDialog(context, "IP Address");
              }
            },
            label: nmeaDevice.connected ? const Text("Disconnect", style: TextStyle(color: Colors.white)) : const Text("Connect", style: TextStyle(color: Colors.white)),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
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
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            newApPrompt(context);
                            setOptions("newAP=true");
                          }, 
                          child: Text(
                            "New AP", 
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.normal,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.blue,
                            ),
                          )
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: wifiModeOptions.map((String value) {
                      return RadioListTile(
                        title: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                        value: value,
                        groupValue: newWifiModeValue,
                        onChanged: (String? value) {
                          setState(() {
                            newWifiModeValue = value;
                            fieldsChanged += 1;
                          });
                        },
                      );
                    }).toList(),
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

  Future<dynamic> newApPrompt(BuildContext context) {
    return showDialog(
      context: context, 
      builder: (context) {
        return AlertDialog(
          title: Text('WiFi Manager', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
          content: Text("Please go to $connectURL in your web browser to reconfigure the Access Point to connect to.", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  }, 
                  child: Text("Close", style: TextStyle(color: Theme.of(context).colorScheme.primary),),
                ),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    if (!await launchUrl(Uri.parse('http://$connectURL'))) {
                      throw Exception('Could not launch http://$connectURL');
                    }
                  },
                  child: Text("Go", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                ),
              ],
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

    //https://www.appsdeveloperblog.com/alert-dialog-with-a-text-field-in-flutter/
  showConnectDialog(BuildContext context, String title) {
    final TextEditingController urlController = TextEditingController();
    urlController.text = connectURL;

    void confirmURL() {
      setState(() {
        connectURL = urlController.text;
        connectToNmeaDataStream();
      });
      Navigator.of(context, rootNavigator: true).pop();
    }

    Widget confirmButton = ElevatedButton(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
      ),
      child: Text("Connect", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
      onPressed: () {
        confirmURL();
      },
    );
    AlertDialog alert = AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(title),
      content: TextFormField(
        controller: urlController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        autofocus: true,
        onFieldSubmitted: (value) {
          confirmURL();
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
