import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
// import 'package:nmeatrax_app/classes.dart';
import 'package:nmeatrax_app/communications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

List<String> downloadList = [];
String connectURL = "192.168.1.1";
ValueNotifier<List<String>> emailMessagesNotifier = ValueNotifier([]);
ScrollController emailMessagesScrollController = ScrollController();

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  
  // Future<void> getFilesList() async {
  //   try {
  //     final dlList = await http.get(Uri.parse('http://$connectURL/listDir'));
  //
  //     if (dlList.statusCode == 200) {
  //       List<List<String>> converted = const CsvToListConverter(shouldParseNumbers: false).convert(dlList.body);
  //       if (converted.isEmpty) {
  //         throw Exception('No files found');
  //       }
  //       downloadList = converted.elementAt(0);
  //       downloadList.removeAt(downloadList.length - 1);
  //       setState(() {});
  //     } else {
  //       throw Exception('Failed to get download list');
  //     }
  //   } on Exception{
  //     if (mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //       content: Text("Could not fetch files from NMEAtrax.", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
  //       duration: const Duration(seconds: 5),
  //       backgroundColor: Theme.of(context).colorScheme.surface,
  //     ));}
  //   }
  // }

  @override
  void initState() {
    super.initState();
    // if (connectionMode == ConnectionMode.wifi) {
    //   getFilesList();
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Text('Voyage Recordings', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
            Spacer(),
            IconButton(onPressed: getOptions, icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onPrimary,)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: Theme.of(context).primaryIconTheme,
      ),
      body: RefreshIndicator(
        // onRefresh: getFilesList,
        onRefresh: getOptions,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: const Text("Tap on the file you wish to download"),
            ),
            OverflowBar(
              spacing: 8,
              alignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary,)
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        bool emailBtnVis = true;
                        return ValueListenableBuilder<List<String>>(
                          valueListenable: emailMessagesNotifier,
                          builder: (aContext, emailMessages, child) {
                            return AlertDialog(
                              title: const Text("Email Progress"),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: ListView.builder(
                                  controller: emailMessagesScrollController,
                                  shrinkWrap: true,
                                  itemCount: emailMessages.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    if (emailMessagesScrollController.hasClients) {
                                      emailMessagesScrollController.jumpTo(emailMessagesScrollController.position.maxScrollExtent);
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Text(
                                        emailMessages.elementAt(index),
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                Visibility(
                                  visible: emailMessages.where((x) => x.contains("Email sent successfully!")).isNotEmpty,
                                  child: Icon(Icons.check_circle, 
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    size: 36,
                                  ),
                                ),
                                Visibility(
                                  visible: emailBtnVis,
                                  child: ElevatedButton(
                                    style: ButtonStyle(backgroundColor: WidgetStateProperty.all<Color>(
                                      emailBtnVis ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary
                                    ),),
                                    onPressed: emailBtnVis ? () {
                                      setState(() {
                                        emailBtnVis = false;
                                      });
                                      setOptions("email=true");
                                    } : null,
                                    child: Text("Send Email", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context, rootNavigator: true).pop();
                                    setState(() {
                                      emailBtnVis = true;
                                      emailMessagesNotifier.value = [];
                                    });
                                  },
                                  child: emailMessages.where((x) => x.contains("Email sent successfully!")).isNotEmpty ? Text("Done", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),) : Text("Close", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                  child: Icon(Icons.email, size: 36, color: Theme.of(context).colorScheme.onPrimary,),
                ),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary,)
                  ),
                  onPressed: () async {
                    if (mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Downloading all files...", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ));}
                    for (var file in downloadList) {
                      await downloadData(file);
                    }
                    if (context.mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Downloaded all files!", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                      duration: const Duration(minutes: 5),
                      showCloseIcon: true,
                      closeIconColor: Theme.of(context).colorScheme.onSecondaryContainer,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ));}
                  },
                  child: Icon(Icons.download, size: 36, color: Theme.of(context).colorScheme.onPrimary,),
                ),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary,)
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Are you sure?"),
                          content: const Text("This will delete all recordings."),
                          actions: [
                              ElevatedButton(
                                style: ButtonStyle(
                                  backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary)
                                ),
                                onPressed: () {
                                  // http.post(Uri.parse("http://$connectURL/set?eraseData=true"));
                                  setOptions("eraseData=true");
                                  downloadList.clear();
                                  if (mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text("Erased all recordings", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                    duration: const Duration(seconds: 5),
                                    backgroundColor: Theme.of(context).colorScheme.surface,
                                  ));}
                                  Navigator.of(context, rootNavigator: true).pop();
                                  setState(() {});
                                },
                              child: Text("Yes", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                            )
                          ],
                        );
                      },
                    );
                  },
                  child: const Icon(Icons.delete_rounded, color: Colors.red, size: 36,),
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
                    mouseCursor: WidgetStateMouseCursor.clickable,
                    hoverColor: Theme.of(context).colorScheme.surface,
                    leading: downloadList.elementAt(index).substring(downloadList.elementAt(index).length - 3) == 'gpx' ? const Icon(Icons.location_on) : const Icon(Icons.insert_drive_file),
                    title: Text(downloadList.elementAt(index)),
                    onTap: () async {
                      String s = await downloadData(downloadList.elementAt(index));
                      if (context.mounted) {ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(s, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
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
      return "Error. Could not get $fileName";
    }
  }
}