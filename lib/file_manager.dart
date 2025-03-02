import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gpx/gpx.dart';
import 'package:csv/csv.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'main.dart';
import 'classes.dart';

class FilePage extends StatefulWidget {
  const FilePage({super.key});

  @override
  State<FilePage> createState() => _FilePageState();
}

class _FilePageState extends State<FilePage> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  bool? selectAll = false;
  List<CsvFile> csvFiles = [];

  Future<void> saveTheme() async {
      final SharedPreferences prefs = await _prefs;
      setState(() {
        prefs.setBool('darkMode', MyApp.themeNotifier.value == ThemeMode.dark ? true : false);
        prefs.setBool('isMeters', depthUnit == DepthUnit.meters ? true : false);
        prefs.setBool('isCelsius', tempUnit == TempUnit.celsius ? true : false);
        prefs.setBool('isLitre', fuelUnit == FuelUnit.litre ? true : false);
        prefs.setBool('useDepthOffset', useDepthOffset);
        prefs.setInt('pressureUnit', pressureUnit.index);
        prefs.setInt('speedUnit', speedUnit.index);
      });
    }

  Future<void> addFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], allowMultiple: true);
    if (result != null) {
      for (PlatformFile file in result.files) {
        setState(() {
          csvFiles.add(CsvFile(file: File(file.path!), selected: false));
          if (csvFiles.any((element) => element.selected == true)) {
            if (csvFiles.any((element) => element.selected == false)) {
              selectAll = null;
            } else {
              selectAll = true;
            }
          } else {
            selectAll = false;
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(context) {
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
      title: 'NMEATrax File Manager',
      home: Scaffold(
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
              saveTheme();
            });
          },
          depthChanged: (selection) {
              setState(() {
                depthUnit = selection.first;
                saveTheme();
              });
            },
            tempChanged: (selection) {
              setState(() {
                tempUnit = selection.first;
                saveTheme();
              });
            },
            speedChanged: (selection) {
              setState(() {
                speedUnit = selection.first;
                saveTheme();
              });
            },
            fuelChanged: (selection) {
              setState(() {
                fuelUnit = selection.first;
                saveTheme();
              });
            },
            pressureChanged: (selection) {
              setState(() {
                pressureUnit = selection.first;
                saveTheme();
              });
            },
            useDepthOffsetChanged: (selection) {
              setState(() {
                useDepthOffset = selection!;
                saveTheme();
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
          title: Text('NMEATrax File Manager', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
        ),
        bottomNavigationBar: Builder(
          builder: (lcontext) {
            return BottomAppBar(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: allowedToCombine(2) ? WidgetStatePropertyAll(Theme.of(context).colorScheme.primary) : WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceDim)
                        ),
                        onPressed: allowedToCombine(2) ? () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              String filename = "combined";
                              return AlertDialog(
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                title: Text('Combine CSV Files', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                content: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("Filename for the combined file...", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                    TextField(
                                      keyboardType: TextInputType.text,
                                      autofocus: true,
                                      autocorrect: false,
                                      onChanged: (value) => filename = value,
                                    ),
                                  ],
                                ),
                                actions: [
                                  ElevatedButton(
                                    style: ButtonStyle(
                                      backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
                                    ),
                                    onPressed: () async {
                                      Navigator.of(context, rootNavigator: true).pop();
                                      combineCSV(filename);
                                      // String resultingFile = await combineCSV(filename);
                                    },
                                    child: Text('Combine', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                                  ),
                                ],
                              );
                            },
                          );
                        } : null,
                        child: Text('Combine', 
                          style: allowedToCombine(2) ? TextStyle(color: Theme.of(context).colorScheme.onPrimary) : TextStyle(color: Theme.of(context).colorScheme.surfaceBright),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: allowedToCombine(1) ? WidgetStatePropertyAll(Theme.of(context).colorScheme.primary) : WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceDim),
                        ),
                        onPressed: allowedToCombine(1) ? () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              String filename = "gpx";
                              return AlertDialog(
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                title: Text('Make GPX File', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                content: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("Filename for the GPX file...", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                    TextFormField(
                                      initialValue: filename,
                                      keyboardType: TextInputType.text,
                                      autofocus: true,
                                      autocorrect: false,
                                      onChanged: (value) => filename = value,
                                    ),
                                  ],
                                ),
                                actions: [
                                  ElevatedButton(
                                    style: ButtonStyle(
                                      backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
                                    ),
                                    onPressed: () async {
                                      if (await makeGPX(filename)) {
                                        if (context.mounted) {Navigator.of(context, rootNavigator: true).pop();}
                                      }                                    
                                    },
                                    child: Text('Create', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                                  ),
                                ],
                              );
                            },
                          );
                        } : null, 
                        child: Text('Make GPX', 
                          style: allowedToCombine(1) ? TextStyle(color: Theme.of(context).colorScheme.onPrimary) : TextStyle(color: Theme.of(context).colorScheme.surfaceBright),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor: allowedToCombine(1) ? WidgetStatePropertyAll(Theme.of(context).colorScheme.primary) : WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceDim),
                        ),
                        onPressed: allowedToCombine(1) ? () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              String filename = "kml";
                              return AlertDialog(
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                title: Text('Make KML File', style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                content: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("Filename for the KML file...", style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                                    TextFormField(
                                      initialValue: filename,
                                      keyboardType: TextInputType.text,
                                      autofocus: true,
                                      autocorrect: false,
                                      onChanged: (value) => filename = value,
                                    ),
                                  ],
                                ),
                                actions: [
                                  ElevatedButton(
                                    style: ButtonStyle(
                                      backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
                                    ),
                                    onPressed: () async {
                                      if (await makeKML(filename)) {
                                        if (context.mounted) {Navigator.of(context, rootNavigator: true).pop();}
                                      }                                    
                                    },
                                    child: Text('Create', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
                                  ),
                                ],
                              );
                            },
                          );
                        } : null, 
                        child: Text('Make KML', 
                          style: allowedToCombine(1) ? TextStyle(color: Theme.of(context).colorScheme.onPrimary) : TextStyle(color: Theme.of(context).colorScheme.surfaceBright),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        ),
        body: Column(
          children: [
            // Text(DateFormat('h:mm:ss a EEE MMM dd yyyy').format(DateTime.fromMillisecondsSinceEpoch(1723322540 * 1000, isUtc: true))),
            ReorderableListView.builder(
              header: CheckboxListTile(
                tristate: true,
                value: selectAll, 
                onChanged: (value) {
                  setState(() {
                    // selectAll = value;
                    if (value == null) {
                      for (var item in csvFiles) {
                        item.selected = false;
                      }
                    } else {
                      for (var item in csvFiles) {
                        item.selected = value;
                      }
                    }
                    
                    if (csvFiles.any((element) => element.selected == true)) {
                      if (csvFiles.any((element) => element.selected == false)) {
                        selectAll = null;
                      } else {
                        selectAll = true;
                      }
                    } else {
                      selectAll = false;
                    }
                  });
                },
              ),
              shrinkWrap: true,
              itemBuilder: (lcontext, index) {
                return Padding(
                  key: Key('$index'),
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                  child: CheckboxListTile(
                    title: Text(basenameWithoutExtension(csvFiles.elementAt(index).file.path), style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
                    tileColor: Theme.of(context).colorScheme.surfaceContainer,
                    value: csvFiles.elementAt(index).selected,
                    secondary: IconButton(
                      icon: Icon(Icons.playlist_remove_rounded, color: Theme.of(context).colorScheme.onSurface,),
                      onPressed: () {
                        setState(() {
                          csvFiles.removeAt(index);
                        });
                      },
                    ),
                    onChanged: (value) {
                      setState(() {
                        csvFiles.elementAt(index).selected = value!;

                        if (csvFiles.any((element) => element.selected == true)) {
                          if (csvFiles.any((element) => element.selected == false)) {
                            selectAll = null;
                          } else {
                            selectAll = true;
                          }
                        } else {
                          selectAll = false;
                        }
                          });
                        },
                  ),
                );
              },
              itemCount: csvFiles.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  csvFiles.insert(newIndex, csvFiles.removeAt(oldIndex));
                });
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Theme.of(context).colorScheme.primary,
          onPressed: () {
            setState(() {
              addFiles();
            });
          },
          child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
        )
      ),
    );
  }

  bool allowedToCombine(int max) {
    List<CsvFile> selectedCSVs = csvFiles.takeWhile((value) => value.selected == true).toList();
    return selectedCSVs.length >= max ? true : false;
  }

  Future<String> combineCSV(String fileName) async {
    List<CsvFile> selectedCSVs = csvFiles.takeWhile((value) => value.selected == true).toList();
    List<String> newFilePath = selectedCSVs.first.file.path.split(Platform.pathSeparator);
    newFilePath.removeLast();
    String newFileLocation = newFilePath.join(Platform.pathSeparator);
    bool headerLock = false;
    File newFile = File('$newFileLocation${Platform.pathSeparator}$fileName.csv');
    IOSink fileSink = newFile.openWrite(mode: FileMode.write);

    for (var voyage in selectedCSVs) {
      List<String> lines = voyage.file.readAsLinesSync();
      if (!headerLock) {
        fileSink.write('${lines.first}\r\n');
        headerLock = true;
      }
      lines.removeAt(0);
      for (var line in lines) {
        fileSink.write('$line\r\n');
      }
    }
    await fileSink.flush();
    await fileSink.close();

    return '$newFileLocation${Platform.pathSeparator}$fileName.csv';
  }

  Future<bool> makeGPX(String fileName) async {
    List<CsvFile> selectedCSVs = csvFiles.takeWhile((value) => value.selected == true).toList();
    List<String> newFilePath = selectedCSVs.first.file.path.split(Platform.pathSeparator);
    newFilePath.removeLast();
    String newFileLocation = newFilePath.join(Platform.pathSeparator);
    File newFile = File('$newFileLocation${Platform.pathSeparator}$fileName.gpx');
    List<Wpt> waypoints = [];
    int lineCount = 1;

    for (CsvFile voyage in selectedCSVs) {
      String csvData = await voyage.file.readAsString();
      List<List<String>> rowsAsListOfValues = const CsvToListConverter().convert(csvData, shouldParseNumbers: false);

      int latIndex = rowsAsListOfValues.first.indexOf('Latitude');
      int lonIndex = rowsAsListOfValues.first.indexOf('Longitude');
      int magVarIndex = rowsAsListOfValues.first.indexOf('Magnetic Variation (*)');
      int timeIndex = rowsAsListOfValues.first.indexOf('Time Stamp');
      // int month = 1;
      rowsAsListOfValues.removeAt(0);
      for (List<String> line in rowsAsListOfValues) {
        // List<String> timeSplit = line.elementAt(timeIndex).split(RegExp(r' |:'));
        String rawLine = line.join(',');
        DateTime dateTime;

        if (!line.elementAt(latIndex).contains('-273') && line.elementAt(timeIndex) != "-") {
          // if (line.elementAt(timeIndex) != "-") {
            dateTime = DateTime.parse(line.elementAt(timeIndex));
            // switch (timeSplit.elementAt(1)) {
            //   case 'Jan':
            //     month = 1;
            //     break;
            //   case 'Feb':
            //     month = 2;
            //     break;
            //   case 'Mar':
            //     month = 3;
            //     break;
            //   case 'Apr':
            //     month = 4;
            //     break;
            //   case 'May':
            //     month = 5;
            //     break;
            //   case 'Jun':
            //     month = 6;
            //     break;
            //   case 'Jul':
            //     month = 7;
            //     break;
            //   case 'Aug':
            //     month = 8;
            //     break;
            //   case 'Sep':
            //     month = 9;
            //     break;
            //   case 'Oct':
            //     month = 10;
            //     break;
            //   case 'Nov':
            //     month = 11;
            //     break;
            //   case 'Dec':
            //     month = 12;
            //     break;
            //   default:
            //     month = 1;
            // }
            // dateTime = DateTime(int.parse(timeSplit.last), month, int.parse(timeSplit.elementAt(2)), int.parse(timeSplit.elementAt(3)), int.parse(timeSplit.elementAt(4)), int.parse(timeSplit.elementAt(5)));
          // } else {
          //   dateTime = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          // }

          if (line.elementAt(latIndex) != "-273" && line.elementAt(latIndex) != "-") {
            waypoints.add(Wpt(
              lat: double.parse(line.elementAt(latIndex)),
              lon: double.parse(line.elementAt(lonIndex)),
              magvar: double.parse(line.elementAt(magVarIndex)),
              time: dateTime,
              name: lineCount.toString(),
              desc: rawLine,
            ));
            lineCount++;
          }
        }
      }
    }

    Gpx gpx = Gpx();
    gpx.creator = "dart-gpx library";
    gpx.trks = [Trk(
      name: "Voyage",
      trksegs: [Trkseg(
        trkpts: waypoints
      )]
    )];

    IOSink fileSink = newFile.openWrite(mode: FileMode.write);
    fileSink.write(GpxWriter().asString(gpx, pretty: true));
    await fileSink.flush();
    await fileSink.close();

    return true;
  }

  Future<bool> makeKML(String fileName) async {
    List<CsvFile> selectedCSVs = csvFiles.takeWhile((value) => value.selected == true).toList();
    List<String> newFilePath = selectedCSVs.first.file.path.split(Platform.pathSeparator);
    newFilePath.removeLast();
    String newFileLocation = newFilePath.join(Platform.pathSeparator);
    File newFile = File('$newFileLocation${Platform.pathSeparator}$fileName.kml');
    List<KmlPoint> waypoints = [];
    int lineCount = 1;

    for (CsvFile voyage in selectedCSVs) {
      String csvData = await voyage.file.readAsString();
      List<List<String>> rowsAsListOfValues = const CsvToListConverter().convert(csvData, shouldParseNumbers: false);

      int latIndex = rowsAsListOfValues.first.indexOf('Latitude');
      int lonIndex = rowsAsListOfValues.first.indexOf('Longitude');
      int timeIndex = rowsAsListOfValues.first.indexOf('Time Stamp');
      int month = 1;
      rowsAsListOfValues.removeAt(0);

      for (List<String> line in rowsAsListOfValues) {
        List<String> timeSplit = line.elementAt(timeIndex).split(RegExp(r' |:'));
        String rawLine = line.join(',');
        DateTime dateTime;

        if (!line.elementAt(latIndex).contains('-273')) {
          if (timeSplit.elementAt(0) != '-') {
            switch (timeSplit.elementAt(1)) {
              case 'Jan':
                month = 1;
                break;
              case 'Feb':
                month = 2;
                break;
              case 'Mar':
                month = 3;
                break;
              case 'Apr':
                month = 4;
                break;
              case 'May':
                month = 5;
                break;
              case 'Jun':
                month = 6;
                break;
              case 'Jul':
                month = 7;
                break;
              case 'Aug':
                month = 8;
                break;
              case 'Sep':
                month = 9;
                break;
              case 'Oct':
                month = 10;
                break;
              case 'Nov':
                month = 11;
                break;
              case 'Dec':
                month = 12;
                break;
              default:
                month = 1;
            }
            dateTime = DateTime(int.parse(timeSplit.last), month, int.parse(timeSplit.elementAt(2)), int.parse(timeSplit.elementAt(3)), int.parse(timeSplit.elementAt(4)), int.parse(timeSplit.elementAt(5)));
          } else {
            dateTime = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          }

          waypoints.add(KmlPoint(
              name: lineCount.toString(),
              description: rawLine,
              timestamp: dateTime.toIso8601String(),
              lat: line.elementAt(latIndex),
              lon: line.elementAt(lonIndex)
            ));
          lineCount++;
        }
      }
    }

    IOSink fileSink = newFile.openWrite(mode: FileMode.write);

    fileSink.write('<?xml version="1.0" encoding="UTF-8"?>\r\n<kml\r\nxmlns="http://earth.google.com/kml/2.2">\r\n<Document>\r\n<name>$fileName</name>\r\n<description>\r\n<![CDATA[NMEATrax Voyage]]>\r\n</description>\r\n');

    for (KmlPoint point in waypoints) {
      fileSink.write('<Placemark>\r\n<name>${point.name}</name>\r\n<description>${point.description}</description>\r\n<TimeStamp>${point.timestamp}</TimeStamp>\r\n<Point>\r\n<coordinates>${point.lon},${point.lat},0</coordinates>\r\n</Point>\r\n</Placemark>\r\n');
    }

    fileSink.write('</Document>\r\n</kml>\r\n');

    await fileSink.flush();
    await fileSink.close();

    return true;
  }
}

class CsvFile {
  File file;
  bool selected;

  CsvFile({required this.file, required this.selected});
}

class KmlPoint {
  String name;
  String description;
  String timestamp;
  String lat;
  String lon;

  KmlPoint({required this.name, required this.description, required this.timestamp, required this.lat, required this.lon});
}