import 'dart:async';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
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

StreamSubscription? nmeaDataSubscription;
StreamSubscription? settingsSubscription;
StreamSubscription? downloadsListSubscription;

final serviceUuid = Guid("ddbf54c4-f88d-4358-b2a5-cfbf2ce4dd37");
final nmeaDataUUID = Guid("67fa3483-a670-4f3e-8e1c-79a106c35567");
final settingsUUID = Guid("2e99e907-2587-43f9-8865-5a02f39a322a");
final downloadsListUUID = Guid("5a3446e2-cab6-4bbe-b4c4-d7be7284a4b5");

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
          // print(response.body);
          nmeaDevice = nmeaDevice.updateFromJson(jsonDecode(response.body));
          // setState(() {});
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
            // setState(() {});
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
  // final BluetoothDevice device;
  final Function() onDataStreamStarted;
  final Function() onNmeaDataUpdated;
  final Function(Map<String, dynamic>) onSettingsUpdated;
  final Function(String) onDownloadsListUpdated;

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
                print("processing:$decodedValue");
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
              onDownloadsListUpdated(utf8.decode(value));
            });
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
          await connectedDevice!.connect();

          BLEServices(onDataStreamStarted, onNmeaDataUpdated, onSettingsUpdated, onDownloadsListUpdated).discoverServices();
          break;
        }
      }
    });
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
    onDataUpdated();
  }
}

