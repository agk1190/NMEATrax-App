import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:http/http.dart' as http;
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/io.dart';
import 'package:dart_ping/dart_ping.dart';

import 'classes.dart';
import 'downloads.dart';
import 'main.dart';

const _appVersion = '4.0.0';
Map<String, dynamic> nmeaData = {"rpm": "-273", "etemp": "-273", "otemp": "-273", "opres": "-273", "fuel_rate": "-273", "flevel": "-273", "efficiency": "-273", "leg_tilt": "-273", "speed": "-273", "heading": "-273", "depth": "-273", "wtemp": "-273", "battV": "-273", "ehours": "-273", "gear": "-", "lat": "-273", "lon": "-273", "mag_var": "-273", "time": "-"};
Map<String, dynamic> ntOptions = {"isMeters":false, "isDegF":false, "recInt":0, "timeZone":0, "recMode":0};
const Map<num, String> recModeEnum = {0:"Off", 1:"On", 2:"Auto by Speed", 3:"Auto by RPM", 4:"Auto by Speed", 5:"Auto by RPM"};

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  final List<String> recModeOptions = <String>['Off', 'On', 'Auto by Speed', 'Auto by RPM'];
  late StreamSubscription<String> subscription;
  bool moreSettingsVisible = false;
  IOWebSocketChannel? channel;
  late BuildContext lcontext;

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
  
    // Function to connect or disconnect the WebSocket
  void connectWebSocket() async {
    if (channel == null) {
      final validIP = await Ping(connectURL, count: 1).stream.first;
      if (validIP.response != null) {
        channel = IOWebSocketChannel.connect(Uri.parse('ws://$connectURL/ws'));
        channel!.stream.listen((message) {
          int i = 0;
          if (message.toString().substring(2, 5) != "rpm") {
          } else {
            setState(() {
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
            });
          }
        });
        setState(() {
          getOptions();
          if (Platform.isAndroid) {KeepScreenOn.turnOn();}
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
        nmeaData = {"rpm": "-", "etemp": "-", "otemp": "-", "opres": "-", "fuel_rate": "-", "flevel": "-", "efficiency": "-", "leg_tilt": "-", "speed": "-", "heading": "-", "depth": "-", "wtemp": "-", "battV": "-", "ehours": "-", "gear": "-", "lat": "-", "lon": "-", "mag_var": "-", "time": "-"};
      });
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
                    if (channel != null) disconnectWebSocket();
                    Navigator.pushReplacementNamed(context, '/live');
                  },
                ),
                ListTile(
                  textColor: Theme.of(context).colorScheme.onBackground,
                  iconColor: Theme.of(context).colorScheme.onBackground,
                  title: Text('Replay', style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                  leading: const Icon(Icons.timeline),
                  onTap: () {
                    if (channel != null) disconnectWebSocket();
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
                const SizedBox(height: 10,),
                Center(
                  child: ElevatedButton(
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all<Color>(Theme.of(context).colorScheme.primary),),
                    child: MyApp.themeNotifier.value == ThemeMode.light ? Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.onPrimary,) : Icon(Icons.light_mode, color: Theme.of(context).colorScheme.onPrimary,),
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
            bottom: TabBar(
              indicatorColor: Theme.of(context).colorScheme.secondary,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard, color: Colors.white)),
                Tab(icon: Icon(Icons.list, color: Colors.white)),
                Tab(icon: Icon(Icons.settings, color: Colors.white)),
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
                            Expanded(child: Text(nmeaData.keys.elementAt(index), textAlign: TextAlign.right, style: TextStyle(color: Theme.of(context).colorScheme.onBackground))),
                            Expanded(child: Text(" ${nmeaData.values.elementAt(index)}", textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onBackground),))
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
                    const SizedBox(height: 15,),
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
                        DropdownMenu(
                          // menuStyle: MenuStyle(
                          //   backgroundColor: MaterialStatePropertyAll(Theme.of(context).colorScheme.surfaceVariant)
                          // ),
                          initialSelection: recModeEnum[ntOptions["recMode"]],
                          enableSearch: false,
                          dropdownMenuEntries: recModeOptions.map<DropdownMenuEntry<String>>((String value) {
                            return DropdownMenuEntry<String>(
                              value: value,
                              label: value,
                              // style: ButtonStyle(
                              //   backgroundColor: MaterialStatePropertyAll(Theme.of(context).colorScheme.surfaceVariant)
                              // ),
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
                        settingsSectionBackground: Theme.of(context).colorScheme.background,
                        settingsListBackground: Theme.of(context).colorScheme.surface,
                        titleTextColor: Theme.of(context).colorScheme.onBackground,
                      ),
                      lightTheme: SettingsThemeData(
                        settingsSectionBackground: Theme.of(context).colorScheme.background,
                        settingsListBackground: Theme.of(context).colorScheme.surface,
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
                    const SizedBox(height: 15,),
                    Visibility(
                      visible: moreSettingsVisible,
                      child: SettingsList(
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
                              SettingsTile.navigation(
                                title: Text("Reset Wifi Settings", style: TextStyle(color: Theme.of(context).colorScheme.error),),
                                onPressed: (context) async {
                                  await http.get(Uri.parse('http://$connectURL/get'));
                                },
                              ),
                              SettingsTile.navigation(
                                title: Text("OTA Update", style: TextStyle(color: Theme.of(context).colorScheme.error),),
                                onPressed: (context) async {
                                  if (!await launchUrl(Uri.parse('http://$connectURL/update'))) {
                                    throw Exception('Could not launch http://$connectURL/update');
                                  }
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
                          backgroundColor: MaterialStatePropertyAll(Theme.of(context).colorScheme.primary),
                        ),
                        onPressed: () {setState(() {moreSettingsVisible = !moreSettingsVisible;});},
                        child: moreSettingsVisible ? Text('Less Settings', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary),) : Text('More Settings', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary),),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: MaterialStatePropertyAll(Theme.of(context).colorScheme.primary),
                        ),
                        onPressed: () {
                          getOptions();
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadsPage()));
                        },
                        child: Text('Voyage Recordings', style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onPrimary),),
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

    //https://www.appsdeveloperblog.com/alert-dialog-with-a-text-field-in-flutter/
  showConnectDialog(BuildContext context, String title) {
    String input = connectURL;

    Widget confirmButton = ElevatedButton(
      style: ButtonStyle(
        backgroundColor: MaterialStatePropertyAll(Theme.of(context).colorScheme.primary),
      ),
      child: Text("Connect", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
      onPressed: () {
        setState(() {
          connectURL = input;
          connectWebSocket();
          if (channel != null) {_saveIP(connectURL);}
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
            if (channel != null) {_saveIP(connectURL);}
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
        backgroundColor: MaterialStatePropertyAll(Theme.of(context).colorScheme.primary),
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
