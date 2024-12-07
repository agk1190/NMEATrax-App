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

class _LivePageState extends State<LivePage> {

  Map<String, dynamic> nmeaData = {"rpm": "-273", "eTemp": "-273", "oTemp": "-273", "oPres": "-273", "fuelRate": "-273", "fLevel": "-273", "efficiency": "-273", "legTilt": "-273", "speed": "-273", "heading": "-273", "depth": "-273", "wTemp": "-273", "battV": "-273", "eHours": "-273", "gear": "-", "lat": "-273", "lon": "-273", "magVar": "-273", "time": "-273", "evcErrorMsg": "-"};
  Map<String, dynamic> ntOptions = {"recInt":0, "recMode":0};
  Map<num, String> recModeEnum = {0:"Off", 1:"On", 2:"Auto by Speed", 3:"Auto by RPM", 4:"Auto by Speed", 5:"Auto by RPM"};
  List<String> evcErrorList = List.empty();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  final List<String> recModeOptions = <String>['Off', 'On', 'Auto by Speed', 'Auto by RPM'];
  late StreamSubscription<String> subscription;
  bool moreSettingsVisible = false;
  WebSocketChannel? channel;
  late BuildContext lcontext;
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
        ntOptions = jsonDecode(response.body);
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
      // do nothing
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
            nmeaData['rpm'] = 'No Websocket';
          });
          return;
        } on WebSocketChannelException {
          setState(() {
            channel = null;
            nmeaData['rpm'] = 'No Websocket';
          });
          return;
        }
        
        channel!.stream.listen((message) {
          print(message);
          // Map<String, dynamic> testData = jsonDecode(message);
          // Map<String, dynamic> data = testData.values.last;
          String msgId = jsonDecode(message).values.first;
          Map<String, dynamic> data = jsonDecode(message).values.last;
          // print(data['rpm'] is int ? data['rpm'] as int : 0);
          // print(data['tilt'] is int ? data['tilt'] as int : 0);
          // nmeaData['rpm'] = (data['rpm'] is int ? data['rpm'] as int : '-').toString();
          // nmeaData['legTilt'] = (data['tilt'] is int ? data['tilt'] as int : '-').toString();

          switch (msgId) {
            case '127488':
            case '127489':
              engineData = engineData.updateFromJson(data);
              break;
            case '127258':
            case '129026':
            case '129029':
              gpsData = gpsData.updateFromJson(data);
              break;
            case '127505':
              fluidLevel = fluidLevel.updateFromJson(data);
              break;
            case '127493':
              transmissionData = transmissionData.updateFromJson(data);
              break;
            case '130312':
              temperatureData = temperatureData.updateFromJson(data);
              break;
            case '128267':
              depthData = depthData.updateFromJson(data);
              break;
            default:
          }
          
          setState(() {});
          
          return;
          int i = 0;
          if (message.toString().substring(2, 5) != "rpm") {
          } else {
            setState(() {
              lastDataReceived = DateTime.now();  // Update the last data received time
              nmeaData = jsonDecode(message);
              for (String element in nmeaData.values) {
                try {
                  if (element.substring(0, 4) == "-273") {
                    String key = nmeaData.keys.elementAt(i);
                    nmeaData[key] = '-';
                  }
                } on RangeError {
                  // do nothing
                }
                i++;
              }
              evcErrorList = nmeaData["evcErrorMsg"].toString().split(', ');
              if (nmeaData['time'] == '0') {nmeaData['time'] = '-';}
              if (nmeaData['eHours'] == '0') {nmeaData['eHours'] = '-';}
            });
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
          nmeaData['rpm'] = 'Bad IP';
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
        nmeaData.updateAll((key, value) => value = "-");
        evcErrorList = List.empty();
        webSocketTimer?.cancel();
        reconnectTimer?.cancel();
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
                nmeaData['rpm'] = '-';
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
          nmeaData['rpm'] = '-';
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

  @override
  void initState() {
    getPrefs();
    super.initState();
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('NMEATrax Live', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                if (ntOptions["recMode"] == 0) const Expanded(
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
            bottom: const TabBar(
              indicatorColor: Colors.white,
              tabs: [
                Tab(icon: Icon(Icons.dashboard, color: Colors.white)),
                Tab(icon: Icon(Icons.list, color: Colors.white)),
                Tab(icon: Icon(Icons.settings, color: Colors.white)),
              ],
            ),
          ),
          body: TabBarView(
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
                      visible: evcErrorList.isNotEmpty && evcErrorList.length > 1,
                      child: SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          shrinkWrap: true,
                          itemCount: evcErrorList.length,
                          itemBuilder: (lcontext, index) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
                              child: Chip(
                                elevation: 4,
                                label: Text(evcErrorList.elementAt(index)),
                                backgroundColor: Theme.of(context).colorScheme.surface,
                                labelStyle: const TextStyle(color: Colors.red),
                                side: const BorderSide(color: Colors.red),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: returnAfterConversion(gpsData.speedOverGround, ConversionType.speed), title: "Knots", unit: UnitFunctions.unitFor(ConversionType.speed), mainContext: context,)),
                        Expanded(child: SizedNMEABox(value: returnAfterConversion(depthData.depth, ConversionType.depth), title: "Depth", unit: UnitFunctions.unitFor(ConversionType.depth), mainContext: context,)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: returnAfterConversion(engineData.rpm, ConversionType.none), title: "RPM", unit: "", fontSize: 48, mainContext: context,),),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: returnAfterConversion(engineData.coolantTemp, ConversionType.temp), title: "Engine", unit: UnitFunctions.unitFor(ConversionType.temp, leadingSpace: false), mainContext: context,),),
                        Expanded(child: SizedNMEABox(value: returnAfterConversion(fluidLevel.level, ConversionType.none), title: "Fuel", unit: "%", mainContext: context,),),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: returnAfterConversion(engineData.oilTemp, ConversionType.temp), title: "Oil", unit: UnitFunctions.unitFor(ConversionType.temp, leadingSpace: false), mainContext: context,),),
                        Expanded(child: SizedNMEABox(value: returnAfterConversion(engineData.oilPres, ConversionType.pressure), title: "Oil", unit: UnitFunctions.unitFor(ConversionType.pressure), mainContext: context,),),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: returnAfterConversion(engineData.fuelRate, ConversionType.fuelRate), title: "Fuel Rate", unit: UnitFunctions.unitFor(ConversionType.fuelRate), mainContext: context,),),
                        Expanded(child: SizedNMEABox(value: returnAfterConversion(engineData.efficieny, ConversionType.fuelEfficiency), title: "Efficiency", unit: UnitFunctions.unitFor(ConversionType.fuelEfficiency), mainContext: context,),),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: SizedNMEABox(value: returnAfterConversion(engineData.legTilt, ConversionType.none), title: "Leg Tilt", unit: "%", mainContext: context,),),
                        Expanded(child: SizedNMEABox(value: returnAfterConversion(temperatureData.actualTemp, ConversionType.wTemp), title: "Water Temp", unit: UnitFunctions.unitFor(ConversionType.wTemp, leadingSpace: false), mainContext: context,),),
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
                            Expanded(child: Text(nmeaData.keys.elementAt(index), textAlign: TextAlign.right, style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                            Expanded(child: Text(" ${nmeaData.values.elementAt(index)}", textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),))
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
                          color: Theme.of(context).colorScheme.onSurface,
                          letterSpacing: 0.75,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          "Recording Mode",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18,
                          ),
                        ),
                        DropdownMenu(
                          menuStyle: MenuStyle(
                            backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surface),
                            surfaceTintColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerHighest),
                          ),
                          textStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            backgroundColor: Theme.of(context).colorScheme.surface,
                          ),
                          initialSelection: recModeEnum[ntOptions["recMode"]],
                          enableSearch: false,
                          dropdownMenuEntries: recModeOptions.map<DropdownMenuEntry<String>>((String value) {
                            return DropdownMenuEntry<String>(
                              value: value,
                              label: value,
                              style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.onSurfaceVariant))
                            );
                          }).toList(),
                          onSelected: (value) {
                            setOptions("recMode=${recModeEnum.keys.firstWhere((element) => recModeEnum[element] == value)}");
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 15,),
                    SettingsList(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      brightness: MyApp.themeNotifier.value == ThemeMode.light ? Brightness.light : Brightness.dark,
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
                            //   title: Text("Update", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                            //   onPressed: (context) {
                            //     getOptions();
                            //   },
                            // ),
                            // SettingsTile.switchTile(
                            //   title: Text("Depth in Meters?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                            //   initialValue: depthInMeters,
                            //   onToggle: (value) => setState(() {depthInMeters = value;}),
                            // ),
                            // SettingsTile.switchTile(
                            //   title: Text("Temperature in Celsius?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                            //   initialValue: tempInCelsius,
                            //   onToggle: (value) => setState(() {tempInCelsius = value;}),
                            // ),
                            SettingsTile(
                              title: Text("Recording Interval (seconds)", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                              value: Text(ntOptions["recInt"].toString(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                              onPressed: (lContext) {
                                showInputDialog(context, "Recording Interval", ntOptions["recInt"], "recInt");
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 15,),
                    Visibility(
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
                              SettingsTile.navigation(
                                title: Text("WiFi Settings", style: TextStyle(color: Theme.of(context).colorScheme.error),),
                                onPressed: (context) async {
                                  // await http.get(Uri.parse('http://$connectURL/set?eraseWiFi=true'));
                                  showDialog(
                                    context: lcontext,
                                    builder: (context) {
                                      String wifiSSID = '';
                                      String wifiPASS = '';
                                      return AlertDialog(
                                        title: Text('WiFi Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                        backgroundColor: Theme.of(context).colorScheme.surface,
                                        actionsAlignment: MainAxisAlignment.spaceBetween,
                                        content: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('SSID', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                            TextField(
                                              autocorrect: false,
                                              autofocus: true,
                                              onChanged: (value) => wifiSSID,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(top: 16),
                                              child: Text('Password', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                            ),
                                            TextField(
                                              autocorrect: false,
                                              onChanged: (value) => wifiPASS,
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            style: ButtonStyle(
                                              backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.error)
                                            ),
                                            onPressed: () => http.get(Uri.parse('http://$connectURL/set?eraseWiFi=true')),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text('Erase WiFi Settings', style: TextStyle(color: Theme.of(context).colorScheme.onError),),
                                            )
                                          ),
                                          TextButton(
                                            style: ButtonStyle(
                                              backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
                                            ),
                                            onPressed: () async {
                                              await http.get(Uri.parse('http://$connectURL/set?AP_SSID=$wifiSSID'));
                                              await http.get(Uri.parse('http://$connectURL/set?AP_PASS=$wifiPASS'));
                                              Future.delayed(Durations.extralong4, () {
                                                http.get(Uri.parse('http://$connectURL/set?reboot=true'));
                                              },);
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                                            )
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
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
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
                        ),
                        onPressed: () {setState(() {moreSettingsVisible = !moreSettingsVisible;});},
                        child: moreSettingsVisible ? Text('Less Settings', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary),) : Text('More Settings', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary),),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
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
                    const SizedBox(height: 15,),
                    Visibility(
                      visible: nmeaData['buildDate'] != null,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text("Firmware built on ${ntOptions["buildDate"]}", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
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
                nmeaData['rpm'] = '-';
              }
            },
            label: channel != null ? const Text("Disconnect", style: TextStyle(color: Colors.white)) : const Text("Connect", style: TextStyle(color: Colors.white)),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Text displayTimeStamp() {
    if (gpsData.unixTime == null) {
      return Text('-', style: TextStyle(color: Theme.of(context).colorScheme.onSurface));
    } else {
      // try {
      //   int.parse(nmeaData['time']);
      // } catch (e) {
      //   return Text('-', style: TextStyle(color: Theme.of(context).colorScheme.onSurface));
      // }
      return Text(DateFormat('h:mm:ss a EEE MMM dd yyyy').format(DateTime.fromMillisecondsSinceEpoch(gpsData.unixTime! * 1000, isUtc: false)), style: TextStyle(color: Theme.of(context).colorScheme.onSurface),);
    }
  }

  String returnAfterConversion(dynamic data, ConversionType type) {
    if (data == -273) {return '-';}
    // double value = double.parse(data);
    if (data == null) {return '-';}
    double value;
    if (data is int) {
      value = data.toDouble();
    } else {
      value = data;
    }
    
    switch (type) {
      case ConversionType.none:
        return value.toStringAsFixed(0);
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
            // return round(value * 3.6, decimals: 2).toString();
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
