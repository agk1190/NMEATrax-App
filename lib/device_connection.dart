import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:eventflux/eventflux.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'classes.dart';
import 'communications.dart';
import 'downloads.dart';

/// Abstract interface for communicating with the NMEATrax device.
///
/// Use [DeviceConnection.create] to obtain the appropriate implementation
/// for the current [connectionMode] (BLE or WiFi).
abstract class DeviceConnection {
  /// Whether the device is currently connected.
  bool get isConnected;

  /// Connect to the device and start receiving NMEA data.
  ///
  /// [onDataStreamStarted] is invoked once the connection is established
  /// and data is flowing.
  /// [onDataUpdated] is invoked whenever a new NMEA message is parsed.
  /// [onSettingsUpdated] is invoked when device configuration is received.
  /// [onDownloadsListUpdated] is invoked when the file list is received.
  /// [onError] is invoked with a human-readable message on failure.
  Future<void> connect({
    required Function() onDataStreamStarted,
    required Function() onDataUpdated,
    required Function(Map<String, dynamic>) onSettingsUpdated,
    required Function(List<Map<String, dynamic>>) onDownloadsListUpdated,
    required Function(String) onError,
  });

  /// Disconnect from the device and clean up resources.
  Future<void> disconnect();

  /// Fetch device configuration and update [nmeaDevice] and [downloadList].
  Future<void> getOptions();

  /// Send a setting to the device as a key=value query string (e.g. "recMode=1").
  Future<void> setOptions(String kvPair);

  /// Download [filename] from the device to the local Downloads folder.
  ///
  /// Returns a human-readable status/result message.
  /// [progressNotifier] is updated from 0.0 to 1.0 as the download proceeds.
  Future<String> downloadFile(String filename, ValueNotifier<double> progressNotifier);

  /// Returns the [DeviceConnection] implementation for the current [connectionMode].
  factory DeviceConnection.create() {
    switch (connectionMode) {
      case ConnectionMode.bluetooth:
        return BleDeviceConnection();
      case ConnectionMode.wifi:
        return WifiDeviceConnection();
    }
  }
}

// ─── Convenience top-level wrappers ──────────────────────────────────────────

/// Fetches device options using the active connection type.
Future<void> getOptions() => DeviceConnection.create().getOptions();

/// Sends a key=value setting to the device using the active connection type.
Future<void> setOptions(String kvPair) => DeviceConnection.create().setOptions(kvPair);

/// Whether the device is currently connected (works for both BLE and WiFi).
bool get isDeviceConnected => DeviceConnection.create().isConnected;

// ─── Shared file-save helper ──────────────────────────────────────────────────

/// Saves [data] to the local Downloads folder under [filename].
///
/// Resolves filename conflicts by appending " (1)", " (2)", etc. Returns
/// a human-readable result message. [progressNotifier] is set to 1.0 on success.
Future<String> _saveToDownloads(Uint8List data, String filename, ValueNotifier<double> progressNotifier) async {
  final String fileExt = filename.substring(filename.length - 4);
  final String baseName = filename.substring(0, filename.length - 4);
  final dynamic directory;

  if (Platform.isAndroid) {
    PermissionStatus status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    directory = "/storage/emulated/0/Download";
  } else {
    directory = await getDownloadsDirectory();
  }

  String filePath = Platform.isAndroid
      ? "$directory/$baseName$fileExt"
      : "${directory?.path}\\$baseName$fileExt";
  File file = File(filePath);

  int i = 1;
  while (file.existsSync()) {
    String tryName = "$baseName ($i)";
    filePath = Platform.isAndroid
        ? "$directory/$tryName$fileExt"
        : "${directory?.path}\\$tryName$fileExt";
    file = File(filePath);
    i++;
  }

  await file.writeAsBytes(data);
  progressNotifier.value = 1.0;
  return "$baseName$fileExt saved to $filePath";
}

// ─── WiFi implementation ─────────────────────────────────────────────────────

/// Communicates with the NMEATrax device over WiFi using HTTP and SSE.
class WifiDeviceConnection implements DeviceConnection {
  @override
  bool get isConnected => nmeaDevice.connected;

  @override
  Future<void> connect({
    required Function() onDataStreamStarted,
    required Function() onDataUpdated,
    required Function(Map<String, dynamic>) onSettingsUpdated,
    required Function(List<Map<String, dynamic>>) onDownloadsListUpdated,
    required Function(String) onError,
  }) async {
    if (nmeaDevice.connected) return;

    final pingResult = await Ping(connectURL, count: 1).stream.first;
    if (pingResult.summary != null || pingResult.error != null) {
      onError("Could not reach NMEATrax at $connectURL. Please check your connection.");
      return;
    }

    EventFlux.instance.connect(
      EventFluxConnectionType.get,
      'http://$connectURL/NMEATrax',
      onSuccessCallback: (EventFluxResponse? response) {
        nmeaDevice.connected = true;
        getOptions();
        onDataStreamStarted();
        response?.stream?.listen((event) {
          NmeaData.parseData(event.data, onDataUpdated);
        });
      },
      autoReconnect: false,
      reconnectConfig: ReconnectConfig(
        mode: ReconnectMode.linear,
        interval: const Duration(seconds: 5),
        maxAttempts: 5,
      ),
      onError: (e) {
        nmeaDevice.connected = false;
        onError("Error connecting to data stream");
      },
    );
  }

  @override
  Future<void> disconnect() async {
    EventFlux.instance.disconnect();
    nmeaDevice.connected = false;
  }

  @override
  Future<void> getOptions() async {
    try {
      final response = await http.get(Uri.parse('http://$connectURL/get'));
      if (response.statusCode == 200) {
        nmeaDevice = nmeaDevice.updateFromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to get options');
      }

      final dlList =
          await http.get(Uri.parse('http://$connectURL/listDir'));
      try {
        final List<dynamic> jsonList = jsonDecode(dlList.body);
        downloadList = jsonList
            .map((e) => {'name': e['name'], 'size': e['size']})
            .toList();
      } catch (e) {
        try {
          final List<String> oldList = List<String>.from(jsonDecode(dlList.body));
          downloadList = oldList.map((name) => {'name': name, 'size': null}).toList();
        } catch (_) {}
      }
    } on Exception {
      // ignore
    }
  }

  @override
  Future<void> setOptions(String kvPair) async {
    try {
      final response = await http.post(Uri.parse('http://$connectURL/set?$kvPair'));
      if (response.statusCode == 200) {
        await getOptions();
      }
    } on Exception {
      // ignore
    }
  }

  @override
  Future<String> downloadFile(String filename, ValueNotifier<double> progressNotifier) async {
    final http.StreamedResponse streamedResponse;

    if (Platform.isAndroid) {
      PermissionStatus status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }

    try {
      final request = http.Request('GET', Uri.parse('http://$connectURL/sdCard/$filename'));
      streamedResponse = await request.send();
    } catch (e) {
      return "Failed to connect while retrieving file.";
    }

    if (streamedResponse.statusCode == 200) {
      final Uint8List data = await streamedResponse.stream.toBytes();
      return _saveToDownloads(data, filename, progressNotifier);
    } else {
      return "Error. Could not get $filename";
    }
  }
}

// ─── BLE implementation ───────────────────────────────────────────────────────

/// Communicates with the NMEATrax device over Bluetooth Low Energy.
class BleDeviceConnection implements DeviceConnection {
  @override
  bool get isConnected => connectedDevice?.isConnected ?? false;

  @override
  Future<void> connect({
    required Function() onDataStreamStarted,
    required Function() onDataUpdated,
    required Function(Map<String, dynamic>) onSettingsUpdated,
    required Function(List<Map<String, dynamic>>) onDownloadsListUpdated,
    required Function(String) onError,
  }) async {
    BLEServices.scanAndConnect(
      onDataStreamStarted,
      onDataUpdated,
      onSettingsUpdated,
      onDownloadsListUpdated,
    );
  }

  @override
  Future<void> disconnect() async {
    if (connectedDevice?.isConnected ?? false) {
      await connectedDevice!.disconnect();
      // connectedDevice!.clearGattCache();
    }
    nmeaDevice.connected = false;
  }

  @override
  Future<void> getOptions() async {
    if (downloadsListChar == null || settingsChar == null) return;
    await downloadsListChar!.write(utf8.encode('listDir'), withoutResponse: false);
    await settingsChar!.write(utf8.encode('fetch'), withoutResponse: false);
  }

  @override
  Future<void> setOptions(String kvPair) async {
    if (settingsChar == null) return;
    await settingsChar!.write(utf8.encode(kvPair), withoutResponse: false);
  }

  @override
  Future<String> downloadFile(String filename, ValueNotifier<double> progressNotifier) async {
    if (fileDownloadControlChar == null || fileDownloadChar == null) {
      return Future.error('File download characteristics not available');
    }

    int? expectedSize;
    final fileEntry = downloadList.firstWhere(
      (e) => e['name'] == filename,
      orElse: () => <String, dynamic>{},
    );
    if (fileEntry['size'] != null) {
      expectedSize = int.tryParse(fileEntry['size'].toString());
    }

    final downloader = BleFileDownloader(
      fileDownloadControlChar!,
      fileDownloadChar!,
      expectedSize: expectedSize,
    );
    final Uint8List fileData = await downloader.downloadFile(filename, progressNotifier);

    return _saveToDownloads(fileData, filename, progressNotifier);
  }
}
