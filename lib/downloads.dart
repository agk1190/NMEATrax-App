import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

List<String> downloadList = [];
String emailData = "";
String connectURL = "192.168.1.1";

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  
  Future<void> getFilesList() async {
    final dlList = await http.get(Uri.parse('http://$connectURL/listDir'));

    if (dlList.statusCode == 200) {
      List<List<String>> converted = const CsvToListConverter(shouldParseNumbers: false).convert(dlList.body);
      downloadList = converted.elementAt(0);
      downloadList.removeAt(downloadList.length - 1);
      setState(() {});
    } else {
      throw Exception('Failed to get download list');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Voyage Recordings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: RefreshIndicator(
        onRefresh: getFilesList,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text("Tap on the file you wish to download"),
            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return StatefulBuilder(
                          builder: (aContext, setState) {
                            return AlertDialog(
                              title: const Text("Email Progress"),
                              content: Text(emailData),
                              actions: [
                                ElevatedButton(
                                  onPressed: () async {
                                    setState(() {emailData = "";});
                                    var request = http.Request('GET', Uri.parse('http://$connectURL/NMEATrax'));
                                    dynamic response;
                                    try {
                                      response = await request.send();
                                    } on Exception {
                                      if (mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text("Could not connect...", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                                        duration: const Duration(seconds: 3),
                                        backgroundColor: Theme.of(context).colorScheme.surface,
                                      ));}
                                      return;
                                    }

                                    var stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());

                                    stream.listen((line) {
                                      if (line.isNotEmpty && line.startsWith('data:')) {
                                        var data = line.substring(6);
                                        if (data.toString().substring(2, 5) != "rpm") {
                                          if (aContext.mounted) {
                                            setState(() {
                                              emailData += data;
                                              emailData += "\r\n";
                                            });
                                          }
                                        }
                                      }
                                    });
                                    Future.delayed(const Duration(seconds: 2), () {
                                      http.post(Uri.parse("http://$connectURL/set?email=true"));
                                    },);
                                  },
                                  child: const Text("Send Email"),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context, rootNavigator: true).pop();
                                  },
                                  child: const Text("Close"),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                  child: const Text("Email Files"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Downloading all files...", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ));}
                    for (var file in downloadList) {
                      await downloadData(file);
                    }
                    if (mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Downloaded all files!", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ));}
                  },
                  child: const Text("Download All"),
                ),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Are you sure?"),
                          actions: [
                              ElevatedButton(
                                onPressed: () {
                                  http.post(Uri.parse("http://$connectURL/set?eraseData=true"));
                                  downloadList.clear();
                                  if (mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text("Erased all recordings", style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                                    duration: const Duration(seconds: 5),
                                    backgroundColor: Theme.of(context).colorScheme.surface,
                                  ));}
                                  Navigator.of(context, rootNavigator: true).pop();
                                  setState(() {});
                                },
                              child: const Text("Yes"),
                            )
                          ],
                        );
                      },
                    );
                  },
                  child: const Text("Erase All"),
                ),
                // ElevatedButton(
                //   onPressed: getFilesList,
                //   child: const Text("Refresh")
                // ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: downloadList.length,
                itemBuilder: (BuildContext context, int index) {
                  return ListTile(
                    mouseCursor: MaterialStateMouseCursor.clickable,
                    hoverColor: Theme.of(context).colorScheme.surface,
                    leading: downloadList.elementAt(index).substring(downloadList.elementAt(index).length - 3) == 'gpx' ? const Icon(Icons.location_on) : const Icon(Icons.insert_drive_file),
                    title: Text(downloadList.elementAt(index)),
                    onTap: () async {
                      String s = await downloadData(downloadList.elementAt(index));
                      if (mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(s, style: TextStyle(color: Theme.of(context).colorScheme.onBackground),),
                        duration: const Duration(seconds: 5),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                      ));}
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> downloadData(String fileName) async {
    String fileExt = fileName.substring(fileName.length - 4);
    final dynamic directory;
    final http.StreamedResponse streamedResponse;

    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }

    try {
      final request = http.Request('GET', Uri.parse('http://$connectURL/sdCard/$fileName'));
      streamedResponse = await request.send();
    } catch (e) {
      return "Error. Could not connect to NMEATrax.";
    }
    if (streamedResponse.statusCode == 200) {
      if (Platform.isAndroid) {
        directory = "/storage/emulated/0/Download";
      } else {
        directory = await getDownloadsDirectory();
      }
      
      fileName = fileName.substring(0, fileName.length - 4);

      String filePath = Platform.isAndroid ? "$directory/$fileName$fileExt" : "${directory?.path}\\$fileName$fileExt";

      File file = File(filePath);
      
      int i = 1;
      while (file.existsSync()) {
        if (i == 1) {
          fileName += " ($i)";
        } else {
          fileName = fileName.substring(0, fileName.length - 4);
          fileName += " ($i)";
        }
        i++;
        filePath = Platform.isAndroid ? "$directory/$fileName$fileExt" : "${directory?.path}\\$fileName$fileExt";
        file = File(filePath);
      }
      
      await streamedResponse.stream.pipe(file.openWrite());
      
      return "$fileName$fileExt saved to $filePath";
    } else {
      return "Error. Could not get $fileName$fileExt";
    }
  }
}