import 'package:flutter/material.dart';
import 'dart:convert';
import 'communications.dart';

class WifiPage extends StatefulWidget {
  const WifiPage({super.key});

  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final List<Map<String, String>> _wifiList = [];

  void _addWifi() {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text.trim();

    if (ssid.isNotEmpty && password.isNotEmpty) {
      setState(() {
        _wifiList.add({'ssid': ssid, 'password': password});
      });
      _ssidController.clear();
      _passwordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter both SSID and Password')),
      );
    }
  }

  void _removeWifi(int index) {
    setState(() {
      _wifiList.removeAt(index);
    });
  }

  void _confirm() {
    final jsonArray = jsonEncode(_wifiList);
    // Use the JSON array as needed
    print(jsonArray); // For demonstration purposes
    setOptions('wifiCred=$jsonArray');
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text('JSON Array: $jsonArray')),
    // );
  }

    @override
  void initState() {
    super.initState();
    // _wifiList = 
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
              controller: _ssidController,
              decoration: InputDecoration(labelText: 'SSID'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Theme.of(context).primaryColor),
              ),
              onPressed: _addWifi,
              child: Text('Add'),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ReorderableListView(
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _wifiList.removeAt(oldIndex);
                    _wifiList.insert(newIndex, item);
                  });
                },
                children: [
                  for (int i = 0; i < _wifiList.length; i++)
                    ListTile(
                      key: ValueKey(i),
                      title: Text(_wifiList[i]['ssid'] ?? ''),
                      subtitle: Text(_wifiList[i]['password'] ?? ''),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _removeWifi(i),
                      ),
                      tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Theme.of(context).primaryColor),
              ),
              onPressed: _confirm,
              child: Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}
