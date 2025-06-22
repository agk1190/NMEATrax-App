import 'dart:convert';
import 'package:flutter/material.dart';
import 'communications.dart';

class WifiPage extends StatefulWidget {
  const WifiPage({super.key});

  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> {
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final List<Map<String, String>> wifiList = [];

  void _addWifi() {
    String ssid = ssidController.text.trim();
    String password = passwordController.text.trim();

    if (ssid.isNotEmpty && password.isNotEmpty) {
      setState(() {
        wifiList.add({'ssid': ssid, 'password': password});
      });
      ssidController.clear();
      passwordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter both SSID and Password')),
      );
    }
  }

  void _removeWifi(int index) {
    setState(() {
      wifiList.removeAt(index);
    });
  }

  Future<void> _confirm() async {
    await setOptions('clrWifiCred');
    for (Map<String, String> wifiPair in wifiList) {
      Map<String, String> wifiCredPair = {};
      wifiCredPair['ssid'] = '"${wifiPair['ssid']}"';
      wifiCredPair['password'] = '"${wifiPair['password']}"';
      await setOptions('setWifiCred=$wifiCredPair');
    }
  }

  void _getWifi() async {
    await getOptions();
    if (mounted) {
      setState(() {
        wifiList.clear();
        if (nmeaDevice.wifiCredentials != null && nmeaDevice.wifiCredentials != "null" && nmeaDevice.wifiCredentials!.isNotEmpty) {
          List<dynamic> ssidList = jsonDecode(nmeaDevice.wifiCredentials!);
          for (var wifiPair in ssidList) {
            wifiList.add(Map<String, String>.from(wifiPair));
          }
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getWifi();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WiFi Configuration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: ssidController,
              decoration: InputDecoration(labelText: 'SSID'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: false,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.primary),
              ),
              onPressed: _addWifi,
              child: Text('Add', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ReorderableListView(
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = wifiList.removeAt(oldIndex);
                    wifiList.insert(newIndex, item);
                  });
                },
                children: [
                  for (int i = 0; i < wifiList.length; i++)
                    Padding(
                      key: ValueKey(i),
                      padding: const EdgeInsets.all(4.0),
                      child: ListTile(
                        key: ValueKey(i),
                        title: Text(wifiList[i]['ssid'] ?? ''),
                        subtitle: Text(wifiList[i]['password'] ?? ''),
                        trailing: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () => _removeWifi(i),
                          ),
                        ),
                        tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.primary),
              ),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('WiFi credentials saved', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                    backgroundColor: Theme.of(context).colorScheme.surfaceBright,
                  )
                );
                await _confirm();
                _getWifi();
              },
              child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}
