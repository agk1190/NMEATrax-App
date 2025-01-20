import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:http/http.dart' as http;
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dart_ping/dart_ping.dart';

import 'classes.dart';
import 'downloads.dart';
import 'main.dart';

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> with SingleTickerProviderStateMixin {

  // Map<String, dynamic> ntOptions = {"recInt":0, "recMode":0, "wifiMode":0, "wifiSSID":"", "wifiPass":"", "buildDate":""};
  Map<num, String> recModeEnum = {0:"Off", 1:"On", 2:"Auto by Speed", 3:"Auto by RPM", 4:"Auto by Speed", 5:"Auto by RPM"};
  Map<bool, String> wifiModeEnum = {false:"Client", true:"Host"};
  final List<String> recModeOptions = <String>['Off', 'On', 'Auto by Speed', 'Auto by RPM'];
  final List<String> wifiModeOptions = <String>['Client', 'Host'];
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  // late StreamSubscription<String> subscription;
  bool moreSettingsVisible = false;
  WebSocketChannel? channel;
  // late BuildContext lcontext;
  DateTime lastDataReceived = DateTime.now();
  Timer? webSocketTimer;
  Timer? reconnectTimer;
  bool reconnecting = false;
  EngineData engineData = EngineData(id: 0);
  GpsData gpsData = GpsData(id: 0);
  FluidLevel fluidLevel = FluidLevel(id: 0);
  TransmissionData transmissionData = TransmissionData(id: 0);
  DepthData depthData = DepthData(id: 0);
  TemperatureData temperatureData = TemperatureData(id: 0);
  String? webSocketStatus;
  NmeaDevice nmeaDevice = NmeaDevice();
  late TabController _tabController;

  Future<void> savePrefs() async {
    final SharedPreferences prefs = await _prefs;
    setState(() {
      prefs.setBool('darkMode', MyApp.themeNotifier.value == ThemeMode.dark ? true : false);
      prefs.setString("ip", jsonEncode(connectURL));
      prefs.setBool('isMeters', depthUnit == DepthUnit.meters ? true : false);
      prefs.setBool('isCelsius', tempUnit == TempUnit.celsius ? true : false);
      prefs.setBool('isLitre', fuelUnit == FuelUnit.litre ? true : false);
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
    if (prefs.getInt("speedUnit") == null) {return;}
    setState(() {
      prefs.getBool('darkMode')! == true ? MyApp.themeNotifier.value = ThemeMode.dark : MyApp.themeNotifier.value = ThemeMode.light;
      connectURL = jsonDecode(prefs.getString("ip")!);
      depthUnit = prefs.getBool('isMeters')! ? DepthUnit.meters : DepthUnit.feet;
      tempUnit = prefs.getBool('isCelsius')! ? TempUnit.celsius : TempUnit.fahrenheit;
      fuelUnit = prefs.getBool('isLitre')! ? FuelUnit.litre : FuelUnit.gallon;
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

  Future<void> getOptions() async {
    dynamic response;
    try {
      response = await http.get(Uri.parse('http://$connectURL/get'));

      if (response.statusCode == 200) {
        // ntOptions = jsonDecode(response.body);
        nmeaDevice = nmeaDevice.updateFromJson(jsonDecode(response.body));
        setState(() {});
      } else {
        throw Exception('Failed to get options');
      }

      final dlList = await http.get(Uri.parse('http://$connectURL/listDir'));

      if (dlList.statusCode == 200) {
        List<List<String>> converted = const CsvToListConverter(shouldParseNumbers: false).convert(dlList.body);
        if (converted.isEmpty) {return;}
        downloadList = converted.elementAt(0);
        downloadList.removeAt(downloadList.length - 1);
      } else {
        throw Exception('Failed to get download list');
      }
    } on Exception {
      //
    }
  }

  Future<void> setOptions(String kvPair) async {
    try {
      final response = await http.post(Uri.parse('http://$connectURL/set?$kvPair'));
      if (response.statusCode == 200) {
        getOptions();
        setState(() {});
      }
    } on Exception {
      //
    }
  }

  // Function to connect the WebSocket
  void connectWebSocket() async {
    if (channel == null) {
      final validIP = await Ping(connectURL, count: 1).stream.first;
      if (validIP.summary == null && validIP.response != null) {
        
        channel = WebSocketChannel.connect(Uri.parse('ws://$connectURL/ws'));
        
        try {
          await channel?.ready;
        } on SocketException {
          setState(() {
            channel = null;
            webSocketStatus = 'No Websocket';
          });
          return;
        } on WebSocketChannelException {
          setState(() {
            channel = null;
            webSocketStatus = 'No Websocket';
          });
          return;
        }
        
        Map<String, DateTime> lastDataTime = {};
        channel!.stream.listen((message) async {
          // print(message);
          String msgId = '';
          Map<String, dynamic> data = {};
          try {
            msgId = jsonDecode(message).values.first;
            data = jsonDecode(message).values.last;
          } on Exception {
            return;
          }

          switch (msgId) {
            case '127488':
            case '127489':
              engineData = engineData.updateFromJson(data);
              lastDataTime['engine'] = DateTime.now();
              break;
            case '127258':
            case '129026':
            case '129029':
              gpsData = gpsData.updateFromJson(data);
              lastDataTime['gps'] = DateTime.now();
              break;
            case '127505':
              fluidLevel = fluidLevel.updateFromJson(data);
              lastDataTime['fluid'] = DateTime.now();
              break;
            case '127493':
              transmissionData = transmissionData.updateFromJson(data);
              lastDataTime['transmission'] = DateTime.now();
              break;
            case '130312':
              temperatureData = temperatureData.updateFromJson(data);
              lastDataTime['temperature'] = DateTime.now();
              break;
            case '128267':
              depthData = depthData.updateFromJson(data);
              lastDataTime['depth'] = DateTime.now();
              break;
            case '161616':
              engineData = engineData.updateErrorsFromJson(data);
              break;
            default:
          }

          for (MapEntry<String, DateTime> data in lastDataTime.entries) {
            if (DateTime.now().difference(data.value).inSeconds > 5) {
              switch (data.key) {
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
            }
          }

          lastDataReceived = DateTime.now();

          if (_tabController.index != 2) {
            setState(() {});
          }
          
        });
        setState(() {
          getOptions();
          if (Platform.isAndroid) {KeepScreenOn.turnOn();}
          savePrefs();
          // startHeartbeat();
          reconnecting = false;
        });
      } else {
        setState(() {
          channel = null;
        });
      }
    }
  }

  // Function to disconnect the WebSocket
  void disconnectWebSocket() {
    if (channel != null) {
      // If WebSocket is connected, close the connection
      channel!.sink.close();
      channel = null;
      setState(() {
        if (Platform.isAndroid) {KeepScreenOn.turnOff();}
        // nmeaData.updateAll((key, value) => value = "-");
        // evcErrorList = List.empty();
        webSocketTimer?.cancel();
        reconnectTimer?.cancel();
        clearData();
        nmeaDevice = NmeaDevice();
      });
    }
  }

  // Function to reconnect the WebSocket
  void reconnectWebSocket() {
    int reconnectAttempts = 0;
    webSocketTimer?.cancel();
    disconnectWebSocket();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reconnecting...', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LinearProgressIndicator(),
              Text('Last message at ${lastDataReceived.hour > 12 ? lastDataReceived.hour-12 : lastDataReceived.hour}:${lastDataReceived.minute.toString().padLeft(2, '0')} ${lastDataReceived.hour > 11 ? 'PM' : 'AM'}')
            ],
          ),
          actions: [
            ElevatedButton(
              style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)),
              onPressed: () {
                reconnectTimer!.cancel();
                webSocketTimer!.cancel();
                Navigator.of(context).pop();
                clearData();
              }, 
              child: Text("Cancel", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),)
            )
          ],
        );
      },
    );
    reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      reconnectAttempts++;
      connectWebSocket();
      setState(() {});
      if (channel != null || reconnectAttempts > 24) {
        setState(() {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
          reconnectTimer!.cancel();
          clearData();
        });
      }
    },);
  }

  // Check if data is being received within the expected time frame
  void startHeartbeat() {
    webSocketTimer?.cancel();  // Cancel any existing heartbeat timer
    webSocketTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final durationSinceLastData = now.difference(lastDataReceived);

      // Check if more than 2 seconds have passed without data
      if (durationSinceLastData.inSeconds >= 2 && !reconnecting) {
        reconnecting = true;
        reconnectWebSocket();
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
              if (channel != null) disconnectWebSocket();
              Navigator.pushReplacementNamed(context, '/live');
            },
            option2Action: () {
              if (channel != null) disconnectWebSocket();
              Navigator.pushReplacementNamed(context, '/replay');
            },
            option3Action: () {
              if (channel != null) disconnectWebSocket();
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(flex: 2, child: Text('NMEATrax Live', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),)),
                if (nmeaDevice.recMode == 0) const Flexible(
                  flex: 1,
                  child: Text(
                    "  Recording Off!",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ) else const Text(""),
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
                      SizedNMEABox(value: returnAfterConversion(gpsData.speedOverGround, ConversionType.speed), title: "Speed", unit: UnitFunctions.unitFor(ConversionType.speed), mainContext: context,),
                      SizedNMEABox(value: returnAfterConversion(depthData.depth, ConversionType.depth), title: "Depth", unit: UnitFunctions.unitFor(ConversionType.depth), mainContext: context,),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(value: returnAfterConversion(engineData.rpm, ConversionType.none), title: "RPM", unit: "", fontSize: 48, mainContext: context,),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(value: returnAfterConversion(engineData.coolantTemp, ConversionType.temp), title: "Engine", unit: UnitFunctions.unitFor(ConversionType.temp, leadingSpace: false), mainContext: context,),
                      SizedNMEABox(value: returnAfterConversion(fluidLevel.level, ConversionType.none), title: "Fuel", unit: "%", mainContext: context,),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(value: returnAfterConversion(engineData.oilTemp, ConversionType.temp), title: "Oil", unit: UnitFunctions.unitFor(ConversionType.temp, leadingSpace: false), mainContext: context,),
                      SizedNMEABox(value: returnAfterConversion(engineData.oilPres, ConversionType.pressure), title: "Oil", unit: UnitFunctions.unitFor(ConversionType.pressure), mainContext: context,),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(value: returnAfterConversion(engineData.fuelRate, ConversionType.fuelRate), title: "Fuel Rate", unit: UnitFunctions.unitFor(ConversionType.fuelRate), mainContext: context,),
                      SizedNMEABox(value: returnAfterConversion(engineData.efficieny, ConversionType.fuelEfficiency), title: "Efficiency", unit: UnitFunctions.unitFor(ConversionType.fuelEfficiency), mainContext: context,),
                    ]),
                    NMEAdataRow(mainContext: context, boxes: [
                      SizedNMEABox(value: returnAfterConversion(engineData.legTilt, ConversionType.none), title: "Leg Tilt", unit: "%", mainContext: context,),
                      SizedNMEABox(value: returnAfterConversion(temperatureData.actualTemp, ConversionType.wTemp), title: "Water Temp", unit: UnitFunctions.unitFor(ConversionType.wTemp, leadingSpace: false), mainContext: context,),
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
                      SizedNMEABox(value: returnAfterConversion(gpsData.speedOverGround, ConversionType.speed), title: "Speed", unit: UnitFunctions.unitFor(ConversionType.speed), mainContext: context,),
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
                    // Row(     // Recording Mode
                    //   mainAxisAlignment: MainAxisAlignment.spaceAround,
                    //   children: [
                    //     Text(
                    //       "Recording Mode",
                    //       style: TextStyle(
                    //         color: Theme.of(context).colorScheme.onSurface,
                    //         fontSize: 18,
                    //       ),
                    //     ),
                    //     DropdownMenu(
                    //       menuStyle: MenuStyle(
                    //         backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surface),
                    //         surfaceTintColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerHighest),
                    //       ),
                    //       textStyle: TextStyle(
                    //         color: Theme.of(context).colorScheme.onSurface,
                    //         backgroundColor: Theme.of(context).colorScheme.surface,
                    //       ),
                    //       initialSelection: recModeEnum[ntOptions["recMode"]],
                    //       enableSearch: false,
                    //       dropdownMenuEntries: recModeOptions.map<DropdownMenuEntry<String>>((String value) {
                    //         return DropdownMenuEntry<String>(
                    //           value: value,
                    //           label: value,
                    //           style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.onSurfaceVariant))
                    //         );
                    //       }).toList(),
                    //       onSelected: (value) {
                    //         setOptions("recMode=${recModeEnum.keys.firstWhere((element) => recModeEnum[element] == value)}");
                    //       },
                    //     ),
                    //   ],
                    // ),
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
                    // SettingsList(    // Settings List
                    //   physics: const NeverScrollableScrollPhysics(),
                    //   shrinkWrap: true,
                    //   brightness: MyApp.themeNotifier.value == ThemeMode.light ? Brightness.light : Brightness.dark,
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
                    //       tiles: [
                    //         SettingsTile(
                    //           title: Text("Recording Interval (seconds)", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                    //           value: Text(ntOptions["recInt"].toString(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                    //           onPressed: (lContext) {
                    //             showInputDialog(context, "Recording Interval", ntOptions["recInt"], "recInt");
                    //           },
                    //         ),
                    //       ],
                    //     )
                    //   ],
                    // ),
                    // const SizedBox(height: 15,),
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
                      child: SettingsList(
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
                            tiles: [
                              // SettingsTile.navigation(
                              //   title: Text("WiFi Settings", style: TextStyle(color: Theme.of(context).colorScheme.error),),
                              //   onPressed: (context) async {
                              //     // await http.get(Uri.parse('http://$connectURL/set?eraseWiFi=true'));
                              //     showDialog(
                              //       context: lcontext,
                              //       builder: (context) {
                              //         String wifiSSID = '';
                              //         String wifiPASS = '';
                              //         return AlertDialog(
                              //           title: Text('WiFi Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                              //           backgroundColor: Theme.of(context).colorScheme.surface,
                              //           actionsAlignment: MainAxisAlignment.spaceBetween,
                              //           content: Column(
                              //             crossAxisAlignment: CrossAxisAlignment.start,
                              //             mainAxisSize: MainAxisSize.min,
                              //             children: [
                              //               Text('SSID', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                              //               TextField(
                              //                 autocorrect: false,
                              //                 autofocus: true,
                              //                 onChanged: (value) => wifiSSID,
                              //               ),
                              //               Padding(
                              //                 padding: const EdgeInsets.only(top: 16),
                              //                 child: Text('Password', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                              //               ),
                              //               TextField(
                              //                 autocorrect: false,
                              //                 onChanged: (value) => wifiPASS,
                              //               ),
                              //             ],
                              //           ),
                              //           actions: [
                              //             TextButton(
                              //               style: ButtonStyle(
                              //                 backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.error)
                              //               ),
                              //               onPressed: () => http.get(Uri.parse('http://$connectURL/set?eraseWiFi=true')),
                              //               child: Padding(
                              //                 padding: const EdgeInsets.all(8.0),
                              //                 child: Text('Erase WiFi Settings', style: TextStyle(color: Theme.of(context).colorScheme.onError),),
                              //               )
                              //             ),
                              //             TextButton(
                              //               style: ButtonStyle(
                              //                 backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
                              //               ),
                              //               onPressed: () async {
                              //                 await http.get(Uri.parse('http://$connectURL/set?AP_SSID=$wifiSSID'));
                              //                 await http.get(Uri.parse('http://$connectURL/set?AP_PASS=$wifiPASS'));
                              //                 Future.delayed(Durations.extralong4, () {
                              //                   http.get(Uri.parse('http://$connectURL/set?reboot=true'));
                              //                 },);
                              //               },
                              //               child: Padding(
                              //                 padding: const EdgeInsets.all(8.0),
                              //                 child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                              //               )
                              //             ),
                              //           ],
                              //         );
                              //       },
                              //     );
                              //   },
                              // ),
                              SettingsTile.navigation(
                                title: Text("OTA Update", style: TextStyle(color: Theme.of(context).colorScheme.error),),
                                onPressed: (context) async {
                                  await http.get(Uri.parse('http://$connectURL/set?otaUpdate=true'));
                                  if (!await launchUrl(Uri.parse('http://$connectURL/update'))) {
                                    throw Exception('Could not launch http://$connectURL/update');
                                  }
                                },
                              ),
                              SettingsTile.navigation(
                                title: Text("Reboot", style: TextStyle(color: Theme.of(context).colorScheme.error),),
                                onPressed: (context) async {
                                  await http.get(Uri.parse('http://$connectURL/set?reboot=true'));
                                },
                              ),
                            ],
                          )
                        ],
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
                        child: Text("Firmware built on ${nmeaDevice.buildDate}", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                      ),
                    ),
                  ]
                ),
              ),
            ]
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              if (channel != null) {
                disconnectWebSocket();
              } else {
                showConnectDialog(context, "IP Address");
              }
            },
            label: channel != null ? const Text("Disconnect", style: TextStyle(color: Colors.white)) : const Text("Connect", style: TextStyle(color: Colors.white)),
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
    // if (engineData.errors != null) {
    //   return Padding(
    //     padding: const EdgeInsets.all(8.0),
    //     child: Wrap(
    //       spacing: 8.0,
    //       children: engineData.errors!.map((error) {
    //         return Chip(
    //           label: Text(error),
    //           backgroundColor: Theme.of(context).colorScheme.surface,
    //           labelStyle: const TextStyle(color: Colors.red),
    //           side: const BorderSide(color: Colors.red),
    //         );
    //       }).toList(),
    //     ),
    //   );
    // } else {
    //   return const Text('');
    // }
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
        return (depthUnit == DepthUnit.meters ? value : value * 3.280839895).toStringAsFixed(2);
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
    String input = connectURL;

    Widget confirmButton = ElevatedButton(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
      ),
      child: Text("Connect", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
      onPressed: () {
        setState(() {
          connectURL = input;
          connectWebSocket();
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
            connectURL = input;
            connectWebSocket();
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
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
      ),
      child: Text("Set", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
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
}
