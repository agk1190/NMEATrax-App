import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
// import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'classes.dart';
import 'downloads.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

NmeaDevice nmeaDevice = NmeaDevice();
EngineData engineData = EngineData(id: 0);
GpsData gpsData = GpsData(id: 0);
FluidLevel fluidLevel = FluidLevel(id: 0);
TransmissionData transmissionData = TransmissionData(id: 0);
DepthData depthData = DepthData(id: 0);
TemperatureData temperatureData = TemperatureData(id: 0);
Map<String, DateTime> lastDataTime = {};
DateTime lastDataReceived = DateTime.now();

BluetoothDevice? connectedDevice;
BluetoothCharacteristic? nmeaDataChar;
BluetoothCharacteristic? settingsChar;
BluetoothCharacteristic? downloadsListChar;
BluetoothCharacteristic? fileDownloadControlChar;
BluetoothCharacteristic? fileDownloadChar;

StreamSubscription? nmeaDataSubscription;
StreamSubscription? settingsSubscription;
StreamSubscription? downloadsListSubscription;

final serviceUuid = Guid("ddbf54c4-f88d-4358-b2a5-cfbf2ce4dd37");
final nmeaDataUUID = Guid("67fa3483-a670-4f3e-8e1c-79a106c35567");
final settingsUUID = Guid("2e99e907-2587-43f9-8865-5a02f39a322a");
final downloadsListUUID = Guid("5a3446e2-cab6-4bbe-b4c4-d7be7284a4b5");
final fileDownloadControlUUID = Guid("b946d82c-2878-472b-ae34-9d47f84e1a58");
final fileDownloadUUID = Guid("2661cd56-cd1f-47f6-b404-6f5bde95793b");

Future<void> getOptions() async {
  if (connectedDevice == null || connectedDevice!.isConnected == false) {
    return;
  }
  switch (connectionMode) {
    case ConnectionMode.wifi:
      dynamic response;
      try {
        response = await http.get(Uri.parse('http://$connectURL/get'));

        if (response.statusCode == 200) {
          nmeaDevice = nmeaDevice.updateFromJson(jsonDecode(response.body));
        } else {
          throw Exception('Failed to get options');
        }

        final dlList = await http.get(Uri.parse('http://$connectURL/listDir'));

        try {
          final List<dynamic> jsonList = jsonDecode(dlList.body);
          downloadList = jsonList.map((e) => {'name': e['name'], 'size': e['size']}).toList();
        } catch (e) {
          // fallback: try to parse as old format (list of names)
          try {
            final List<String> oldList = List<String>.from(jsonDecode(dlList.body));
            downloadList = oldList.map((name) => {'name': name, 'size': null}).toList();
          } catch (_) {
            // ignore
          }
        }
      } on Exception {
        //
      }
      break;
    case ConnectionMode.bluetooth:
      await downloadsListChar!.write(utf8.encode('listDir'), withoutResponse: false);
      await settingsChar!.write(utf8.encode('fetch'), withoutResponse: false);
      break;
  }
}

Future<void> setOptions(String kvPair) async {
  switch (connectionMode) {
    case ConnectionMode.wifi:
      try {
        final response = await http.post(Uri.parse('http://$connectURL/set?$kvPair'));
          if (response.statusCode == 200) {
            await getOptions();
          }
        } on Exception {
          //
        }
      break;
    case ConnectionMode.bluetooth:
      await settingsChar!.write(utf8.encode(kvPair), withoutResponse: false);
      break;
  }
  
}

class BLEServices {
  final Function() onDataStreamStarted;
  final Function() onNmeaDataUpdated;
  final Function(Map<String, dynamic>) onSettingsUpdated;
  final Function(List<Map<String, dynamic>>) onDownloadsListUpdated;

  BLEServices.scanAndConnect(this.onDataStreamStarted, this.onNmeaDataUpdated, this.onSettingsUpdated, this.onDownloadsListUpdated) {
    scanAndConnect();
  }

  BLEServices(this.onDataStreamStarted, this.onNmeaDataUpdated, this.onSettingsUpdated, this.onDownloadsListUpdated);

  Future<void> discoverServices() async {
    List<BluetoothService> services = await connectedDevice!.discoverServices();
    for (var service in services) {
      if (service.uuid == serviceUuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid == nmeaDataUUID && characteristic.properties.notify) {
            nmeaDataChar = characteristic;
            await nmeaDataChar!.setNotifyValue(true);
            if (nmeaDataSubscription != null) {
              nmeaDataSubscription!.cancel();
            }
            nmeaDataSubscription = nmeaDataChar!.lastValueStream.listen((value) {
              NmeaData.parseData(utf8.decode(value), onNmeaDataUpdated);
            });
            onDataStreamStarted();
          }
          if (characteristic.uuid == settingsUUID && characteristic.properties.notify) {
            settingsChar = characteristic;
            await settingsChar!.setNotifyValue(true);
            if (settingsSubscription != null) {
              settingsSubscription!.cancel();
            }
            settingsSubscription = settingsChar!.lastValueStream.listen((value) {
              String decodedValue = utf8.decode(value, allowMalformed: true);
              if (decodedValue.startsWith("{\"") && decodedValue.endsWith("}")) {
                onSettingsUpdated(jsonDecode(decodedValue));
              }
            });
          }
          if (characteristic.uuid == downloadsListUUID && characteristic.properties.notify) {
            downloadsListChar = characteristic;
            await downloadsListChar!.setNotifyValue(true);
            if (downloadsListSubscription != null) {
              downloadsListSubscription!.cancel();
            }
            downloadsListSubscription = downloadsListChar!.lastValueStream.listen((value) {
              // Parse JSON array of objects with 'name' and 'size'
              try {
                final List<dynamic> jsonList = jsonDecode(utf8.decode(value));
                downloadList = jsonList.map((e) => {'name': e['name'], 'size': e['size']}).toList();
                onDownloadsListUpdated(downloadList);
              } catch (e) {
                // fallback: try to parse as old format (list of names)
                try {
                  final List<String> oldList = List<String>.from(jsonDecode(utf8.decode(value)));
                  onDownloadsListUpdated(oldList.map((name) => {'name': name, 'size': null}).toList());
                } catch (_) {
                  // ignore
                }
              }
            });
          }
          if (characteristic.uuid == fileDownloadControlUUID && characteristic.properties.write) {
            fileDownloadControlChar = characteristic;
            await fileDownloadControlChar!.setNotifyValue(true);
          }
          if (characteristic.uuid == fileDownloadUUID && characteristic.properties.notify) {
            fileDownloadChar = characteristic;
            await fileDownloadChar!.setNotifyValue(true);
          }
        }
      }
    }
    getOptions();
  }

  Future<void> scanAndConnect() async {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    // Find device advertising the service UUID
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.advertisementData.serviceUuids.contains(serviceUuid)) {
          FlutterBluePlus.stopScan();

          connectedDevice = r.device;
            try {
              await connectedDevice!.connect(autoConnect: false);
            } on Exception catch (e) {
            // Handle Android GATT error 133 by retrying connection
            if (e.toString().contains('133')) {
              await Future.delayed(const Duration(seconds: 2));
              try {
                await connectedDevice!.disconnect();
              } catch (_) {}
              await Future.delayed(const Duration(seconds: 1));
              await connectedDevice!.connect(autoConnect: false);
            } else {
              rethrow;
            }
          }

          BLEServices(onDataStreamStarted, onNmeaDataUpdated, onSettingsUpdated, onDownloadsListUpdated).discoverServices();
          break;
        }
      }
    });
  }
}

class BleFileDownloader {
  final BluetoothCharacteristic fileDownloadControlChar;
  final BluetoothCharacteristic fileDownloadChar;
  final int? expectedSize;
  Uint8List _fileBuffer = Uint8List(0);
  late Completer<void> _completer;
  late StreamSubscription _dataSubscription;
  bool _receiving = false;

  BleFileDownloader(this.fileDownloadControlChar, this.fileDownloadChar, {this.expectedSize});

  Future<Uint8List> downloadFile(String filename, ValueNotifier<double> progressNotifier) async {
    _fileBuffer = Uint8List(0);
    _receiving = false;
    _completer = Completer<void>();

    // Listen for file data
    _dataSubscription = fileDownloadChar.lastValueStream.listen((value) async {
      _receiving = true;
      _fileBuffer = Uint8List.fromList(_fileBuffer + value);

      // Update progress
      if (expectedSize != null && expectedSize! > 0) {
        progressNotifier.value = _fileBuffer.length / expectedSize!;
      }
      
      if (expectedSize != null && _fileBuffer.length >= expectedSize!) {
        await fileDownloadControlChar.write(utf8.encode('end'), withoutResponse: false);
        complete();
      } else {
        await fileDownloadControlChar.write(utf8.encode('ack'), withoutResponse: false);
      }
    });

    await fileDownloadControlChar.write(utf8.encode(filename), withoutResponse: false);
    _fileBuffer = Uint8List(0);

    // Wait for the file to start receiving
    int waitCount = 0;
    while (!_receiving && waitCount < 40) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }
    if (!_receiving) {
      await _dataSubscription.cancel();
      throw Exception("File download did not start");
    }
    // Wait for the file to finish receiving
    await _completer.future;
    await _dataSubscription.cancel();
    progressNotifier.value = 1.0; // Ensure progress is 100% at end
    return _fileBuffer;
  }

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

Future<String> downloadDataBLE(String filename) async {
  if (connectedDevice == null || connectedDevice!.isConnected == false) {
    return Future.error('Device not connected');
  }
  switch (connectionMode) {
    case ConnectionMode.wifi:
      // try {
      //   final response = await http.get(Uri.parse('http://$connectURL/download/$filename'));
      //   if (response.statusCode == 200) {
      //     return File.fromRawPath(response.bodyBytes);
      //   } else {
      //     throw Exception('Failed to download file');
      //   }
      // } on Exception catch (e) {
      //   return Future.error(e.toString());
      // }
    case ConnectionMode.bluetooth:
      if (fileDownloadControlChar == null || fileDownloadChar == null) {
        return Future.error('File download characteristics not available');
      }
      // Find file size from downloadList
      int? expectedSize;
      final fileEntry = downloadList.firstWhere(
        (e) => e['name'] == filename,
        orElse: () => <String, dynamic>{},
      );
      if (fileEntry['size'] != null) {
        expectedSize = int.tryParse(fileEntry['size'].toString());
      }
      final downloader = BleFileDownloader(fileDownloadControlChar!, fileDownloadChar!, expectedSize: expectedSize);
      Uint8List fileData = await downloader.downloadFile(filename, progressNotifier);
      String fileExt = filename.substring(filename.length - 4);
      final dynamic directory;
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }
        directory = "/storage/emulated/0/Download";
      } else {
        directory = await getDownloadsDirectory();
      }
      String baseName = filename.substring(0, filename.length - 4);
      String filePath = Platform.isAndroid ? "$directory/$baseName$fileExt" : "${directory?.path}\\$baseName$fileExt";
      File file = File(filePath);
      int i = 1;
      while (file.existsSync()) {
        String tryName = i == 1 ? "$baseName ($i)" : "$baseName ($i)";
        filePath = Platform.isAndroid ? "$directory/$tryName$fileExt" : "${directory?.path}\\$tryName$fileExt";
        file = File(filePath);
        i++;
      }
      await file.writeAsBytes(fileData);
      return "$baseName$fileExt saved to $filePath";
  }
}

class NmeaData {
  dynamic data;
  final Function() onDataUpdated;

  NmeaData.parseData(data, this.onDataUpdated) {
    parseData(data);
  }

  void parseData(data) {
    String msgId;
    Map<String, dynamic> nmeaData;
    try {
      msgId = jsonDecode(data).values.first;
      nmeaData = jsonDecode(data).values.last;
    } on Exception {
      return;
    }

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
      case '000000':
        // heartbeat message
        break;
      case 'email':
        emailMessagesNotifier.value = List.from(emailMessagesNotifier.value)..add(nmeaData['msg']);
        break;
      default:
    }

    lastDataReceived = DateTime.now();
    onDataUpdated();
  }
}

