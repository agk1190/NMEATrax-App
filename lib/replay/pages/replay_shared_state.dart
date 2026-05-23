import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gpx/gpx.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nmeatrax_app/classes.dart';
import '../../main.dart';


// ── CSV / GPX data ────────────────────────────────────────────────────────────

class ReplayCsvData {
  final List<List<dynamic>> rows;
  final List<dynamic> headers;
  final File filePath;

  ReplayCsvData({
    required this.rows,
    required this.headers,
    required this.filePath,
  });

  factory ReplayCsvData.empty() {
    return ReplayCsvData(
      rows: <List<dynamic>>[],
      headers: <dynamic>[],
      filePath: File('null'),
    );
  }

  int get maxLine => rows.isEmpty ? 0 : rows.length - 1;
}

final ValueNotifier<ReplayCsvData> replayCsvNotifier =
    ValueNotifier<ReplayCsvData>(ReplayCsvData.empty());

ReplayCsvData currentReplayCsvData() => replayCsvNotifier.value;

File gpxFilePath = File('null');


// ── Analysis limits ───────────────────────────────────────────────────────────

final Map<String, dynamic> _defaultLowerLimits = <String, dynamic>{
  'RPM': 0.0,
  'Engine Temp': 273.15,
  'Oil Temp': 273.15,
  'Oil Pressure': 300.0,
  'Fuel Rate': 0.0,
  'Fuel Level': 10.0,
  'Fuel Efficiency': 0.0,
  'Leg Tilt': 0.0,
  'Speed': 0.0,
  'Heading': 0.0,
  'Depth': 1.0,
  'Water Temp': 275.15,
  'Battery Voltage': 12.0,
  'Engine Hours': 0.0,
  'Latitude': 47.0,
  'Longitude': -125.0,
  'Magnetic Variation': 0.0,
  'Error Bits': 0.0,
};

final Map<String, dynamic> _defaultUpperLimits = <String, dynamic>{
  'RPM': 5200.0,
  'Engine Temp': 353.15,
  'Oil Temp': 388.15,
  'Oil Pressure': 700.0,
  'Fuel Rate': 50.0,
  'Fuel Level': 100.0,
  'Fuel Efficiency': 4.0,
  'Leg Tilt': 100.0,
  'Speed': 15.4333,
  'Heading': 360.0,
  'Depth': 304.8000000012192,
  'Water Temp': 298.15,
  'Battery Voltage': 15.0,
  'Engine Hours': 3600000.0,
  'Latitude': 50.0,
  'Longitude': -122.0,
  'Magnetic Variation': 20.0,
  'Error Bits': 0.0,
};

class ReplayLimitsData {
  final Map<String, dynamic> lower;
  final Map<String, dynamic> upper;

  ReplayLimitsData({required this.lower, required this.upper});

  factory ReplayLimitsData.defaults() {
    return ReplayLimitsData(
      lower: Map<String, dynamic>.from(_defaultLowerLimits),
      upper: Map<String, dynamic>.from(_defaultUpperLimits),
    );
  }
}

final ValueNotifier<ReplayLimitsData> replayLimitsNotifier =
    ValueNotifier<ReplayLimitsData>(ReplayLimitsData.defaults());

ReplayLimitsData currentReplayLimitsData() => replayLimitsNotifier.value;

class NmeaViolation {
  final String name;
  final dynamic value;
  final int line;

  NmeaViolation({required this.name, required this.value, required this.line});
}

final ValueNotifier<int> curLineNumNotifier = ValueNotifier<int>(0);

void setCurLineNum(int value) {
  final int clamped = value.clamp(0, replayCsvNotifier.value.maxLine);
  if (curLineNumNotifier.value != clamped) {
    curLineNumNotifier.value = clamped;
  }
}

void onSliderChanged(double value) => setCurLineNum(value.toInt());

void decrCurLineNum() => setCurLineNum(curLineNumNotifier.value - 1);

void incrCurLineNum() => setCurLineNum(curLineNumNotifier.value + 1);

final ValueNotifier<bool> analyzeVisibleNotifier = ValueNotifier<bool>(false);
final ValueNotifier<List<NmeaViolation>> analyzedDataNotifier = ValueNotifier<List<NmeaViolation>>(<NmeaViolation>[]);

void analyzeData() {
  final ReplayCsvData csvData = currentReplayCsvData();
  final ReplayLimitsData limitsData = currentReplayLimitsData();
  final List<NmeaViolation> result = <NmeaViolation>[];
  int i = 0;
  for (final List<dynamic> row in csvData.rows) {
    int j = 0;
    for (final dynamic col in row) {
      if (col is! String) {
        if ((col < limitsData.lower[csvData.headers[j]] || col > limitsData.upper[csvData.headers[j]]) && col != -273.0) {
          if (!(csvData.headers[j] == 'Oil Pressure' && (col == 0 || col == 4))) {
            result.add(NmeaViolation(name: csvData.headers.elementAt(j), value: col, line: i));
          }
        }
      }
      j++;
    }
    i++;
  }

  analyzedDataNotifier.value = result;
}

final ValueNotifier<List<int>> selectedGraphColumnsNotifier = ValueNotifier<List<int>>(<int>[]);

final ValueNotifier<int> selectedLimitNotifier = ValueNotifier<int>(0);

void setSelectedLimit(int index) {
  final int maxIndex = currentReplayLimitsData().upper.isEmpty ? 0 : currentReplayLimitsData().upper.length - 1;
  final int clamped = index.clamp(0, maxIndex);
  if (selectedLimitNotifier.value != clamped) {
    selectedLimitNotifier.value = clamped;
  }
}

void updateSelectedLimitValue({
  required bool upper,
  required double input,
}) {
  final int selectedLimit = selectedLimitNotifier.value;
  final ReplayLimitsData limitsData = currentReplayLimitsData();
  final Map<String, dynamic> nextLower = Map<String, dynamic>.from(limitsData.lower);
  final Map<String, dynamic> nextUpper = Map<String, dynamic>.from(limitsData.upper);

  if (upper) {
    final String key = nextUpper.keys.elementAt(selectedLimit);
    nextUpper[key] = UnitFunctions.convertToBaseUnit(input, nextUpper, selectedLimit);
  } else {
    final String key = nextLower.keys.elementAt(selectedLimit);
    nextLower[key] = UnitFunctions.convertToBaseUnit(input, nextLower, selectedLimit);
  }

  replayLimitsNotifier.value = ReplayLimitsData(lower: nextLower, upper: nextUpper);
}


// ── Map tracks ───────────────────────────────────────────────────────────────

final MapController replayMapController = MapController();
final LatLng replayHomeCoords = const LatLng(48.668070, -123.404493);

class ReplayMapTracksData {
  final List<List<LatLng>> tracks;
  final List<int> numbers;
  final List<Color> colors;

  ReplayMapTracksData({
    required this.tracks,
    required this.numbers,
    required this.colors,
  });

  factory ReplayMapTracksData.empty() {
    return ReplayMapTracksData(
      tracks: <List<LatLng>>[<LatLng>[const LatLng(0, 0)]],
      numbers: <int>[],
      colors: <Color>[const Color(0xFF0050C7)],
    );
  }
}

final ValueNotifier<ReplayMapTracksData> replayMapTracksNotifier =
    ValueNotifier<ReplayMapTracksData>(ReplayMapTracksData.empty());

ReplayMapTracksData currentReplayMapTracksData() => replayMapTracksNotifier.value;

void resetMapTracks() {
  replayMapTracksNotifier.value = ReplayMapTracksData.empty();
}

void removeGpxTrackAt(int index) {
  final ReplayMapTracksData mapTracksData = currentReplayMapTracksData();
  final List<List<LatLng>> tracks = List<List<LatLng>>.from(mapTracksData.tracks);
  final List<int> numbers = List<int>.from(mapTracksData.numbers);
  final List<Color> colors = List<Color>.from(mapTracksData.colors);

  tracks.removeAt(index);
  numbers.removeAt(index);
  if (index + 1 < colors.length) {
    colors.removeAt(index + 1);
  }

  if (tracks.isEmpty) {
    tracks.add(<LatLng>[const LatLng(0, 0)]);
  }

  replayMapTracksNotifier.value = ReplayMapTracksData(
    tracks: tracks,
    numbers: numbers,
    colors: colors,
  );
}


// ── File loading helpers ──────────────────────────────────────────────────────

Future<File> _pickFile(List<String> extensions) async {
  final FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
  );
  if (result != null) {
    return File(result.files.single.path!);
  }
  return currentReplayCsvData().filePath; // user cancelled — return previous path unchanged
}

Future<List<List<dynamic>>> _loadCSV(File filePath) async {
  final CsvCodec csvCodec = CsvCodec(dynamicTyping: true);
  final List<List<List<dynamic>>> rows = await filePath
      .openRead()
      .transform(utf8.decoder)
      .transform(csvCodec.decoder)
      .toList();
  return rows.first;
}

Future<List<Wpt>> _loadGPX(File filePath) async {
  final String gpxData = await filePath.readAsString();
  final Gpx gpx = GpxReader().fromString(gpxData);
  final List<Wpt> trackpts = gpx.trks[0].trksegs[0].trkpts;
  trackpts.removeWhere((Wpt wpt) => wpt.lat == 0);
  return trackpts;
}


// ── CSV / GPX public actions ──────────────────────────────────────────────────

/// Opens a CSV file picker, loads and processes the data, then resets
/// replay state. Called by the Data page app bar.
Future<void> getCSV() async {
  resetMapTracks();

  final File selectedCsvFile = await _pickFile(<String>['csv']);
  if (selectedCsvFile.path == 'null') return;

  final List<List<dynamic>> rows = await _loadCSV(selectedCsvFile);
  if (rows.isEmpty) return;

  final List<dynamic> parsedHeaders = List<dynamic>.from(rows.first);
  final List<List<dynamic>> parsedRows = rows.sublist(1);

  // Strip unit suffixes like " (kn)" from header names.
  final List<dynamic> cleanedHeaders = parsedHeaders.map((dynamic h) {
    final String s = h as String;
    return s.contains(' (') ? s.split(' (').first : s;
  }).toList();

  // Process row values: replace sentinel -273, format timestamps.
  for (int i = 0; i < parsedRows.length; i++) {
    for (int j = 0; j < parsedRows[i].length; j++) {
      final dynamic val = parsedRows[i][j];
      if (val is! String) {
        if ((-273.0).compareTo(val) == 0) {
          parsedRows[i][j] = '-';
        } else if (j == cleanedHeaders.indexOf('Time Stamp')) {
          parsedRows[i][j] = val == 0
              ? '-'
              : DateFormat('h:mm:ss a EEE MMM dd yyyy')
                  .format(DateTime.fromMillisecondsSinceEpoch(val * 1000, isUtc: false));
        }
      }
    }
  }

  // Build waypoints list for map.
  final List<Wpt> waypoints = <Wpt>[];
  final int latIdx = cleanedHeaders.indexOf('Latitude');
  final int lonIdx = cleanedHeaders.indexOf('Longitude');
  if (latIdx >= 0 && lonIdx >= 0) {
    for (final List<dynamic> row in parsedRows) {
      if (row[latIdx] != '-') {
        waypoints.add(Wpt(lat: row[latIdx] as double, lon: row[lonIdx] as double));
      }
    }
  }

  replayCsvNotifier.value = ReplayCsvData(
    rows: parsedRows,
    headers: cleanedHeaders,
    filePath: selectedCsvFile,
  );

  if (waypoints.isNotEmpty) importGPX(waypoints);
  setCurLineNum(0);
  analyzedDataNotifier.value = <NmeaViolation>[];
  analyzeVisibleNotifier.value = false;
}

/// Opens a CSV file and imports only its GPS track onto the map.
Future<void> getGPXfromCSV() async {
  final File selectedCsvFile = await _pickFile(<String>['csv']);
  if (selectedCsvFile.path == 'null') return;

  final List<List<dynamic>> rows = await _loadCSV(selectedCsvFile);
  if (rows.isEmpty) return;

  final List<dynamic> headersRow = rows.first;
  rows.removeAt(0);

  final int latIdx = headersRow.indexOf('Latitude');
  final int lonIdx = headersRow.indexOf('Longitude');

  final List<Wpt> waypoints = <Wpt>[];
  for (final List<dynamic> row in rows) {
    final String latVal = row[latIdx].toString();
    if (!latVal.contains('-273') && latVal != '-') {
      waypoints.add(Wpt(lat: row[latIdx] as double, lon: row[lonIdx] as double));
    }
  }

  if (waypoints.isNotEmpty) importGPX(waypoints);
}

/// Opens a GPX file picker and imports the track onto the map.
Future<void> getGPX(File _) async {
  gpxFilePath = await _pickFile(<String>['gpx']);
  if (gpxFilePath.path.contains('.csv')) return;
  if (gpxFilePath.path == 'null') return;

  final List<Wpt> rows = await _loadGPX(gpxFilePath);
  importGPX(rows);
}

/// Adds a list of waypoints as a new track layer on the map.
void importGPX(List<Wpt> rows) {
  if (rows.isEmpty) return;

  final ReplayMapTracksData mapTracksData = currentReplayMapTracksData();
  final List<List<LatLng>> tracks = List<List<LatLng>>.from(mapTracksData.tracks);
  final List<int> numbers = List<int>.from(mapTracksData.numbers);
  final List<Color> colors = List<Color>.from(mapTracksData.colors);

  int idx = 0;
  if (numbers.isNotEmpty) {
    idx = numbers.length;
    tracks.add(<LatLng>[const LatLng(0, 0)]);
  }
  if (tracks.isEmpty) {
    tracks.add(<LatLng>[const LatLng(0, 0)]);
  }
  tracks[idx].clear();

  for (final Wpt wpt in rows) {
    tracks[idx].add(LatLng(wpt.lat!, wpt.lon!));
  }

  numbers.add(idx + 1);
  if (idx > 0 && idx >= colors.length) {
    colors.add(Color.fromARGB(
      255,
      Random().nextInt(256),
      Random().nextInt(256),
      Random().nextInt(256),
    ));
  }

  replayMapTracksNotifier.value = ReplayMapTracksData(
    tracks: tracks,
    numbers: numbers,
    colors: colors,
  );
}


// ── Preferences ───────────────────────────────────────────────────────────────

Future<void> savePrefs() async {
  final ReplayLimitsData limitsData = currentReplayLimitsData();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setBool('darkMode', MyApp.themeNotifier.value == ThemeMode.dark);
  prefs.setString('lower', jsonEncode(limitsData.lower));
  prefs.setString('upper', jsonEncode(limitsData.upper));
  prefs.setBool('isMeters', depthUnit == DepthUnit.meters);
  prefs.setBool('isCelsius', tempUnit == TempUnit.celsius);
  prefs.setBool('isLitre', fuelUnit == FuelUnit.litre);
  prefs.setInt('speedUnit', speedUnit.index);
  prefs.setInt('pressureUnit', pressureUnit.index);
  prefs.setBool('useDepthOffset', useDepthOffset);
}

Future<void> loadPrefs() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final ReplayLimitsData limitsData = currentReplayLimitsData();
  Map<String, dynamic> loadedLower = Map<String, dynamic>.from(limitsData.lower);
  Map<String, dynamic> loadedUpper = Map<String, dynamic>.from(limitsData.upper);

  if (prefs.getString('lower') != null) {
    loadedLower = Map<String, dynamic>.from(jsonDecode(prefs.getString('lower')!));
  }
  if (prefs.getString('upper') != null) {
    loadedUpper = Map<String, dynamic>.from(jsonDecode(prefs.getString('upper')!));
  }
  replayLimitsNotifier.value = ReplayLimitsData(lower: loadedLower, upper: loadedUpper);
  if (prefs.getBool('darkMode') != null) {
    MyApp.themeNotifier.value =
        prefs.getBool('darkMode')! ? ThemeMode.dark : ThemeMode.light;
  }
  if (prefs.getBool('isMeters') != null) {
    depthUnit = prefs.getBool('isMeters')! ? DepthUnit.meters : DepthUnit.feet;
  }
  if (prefs.getBool('isCelsius') != null) {
    tempUnit = prefs.getBool('isCelsius')! ? TempUnit.celsius : TempUnit.fahrenheit;
  }
  if (prefs.getBool('isLitre') != null) {
    fuelUnit = prefs.getBool('isLitre')! ? FuelUnit.litre : FuelUnit.gallon;
  }
  if (prefs.getInt('speedUnit') != null) {
    speedUnit = SpeedUnit.values[prefs.getInt('speedUnit')!];
  }
  if (prefs.getInt('pressureUnit') != null) {
    pressureUnit = PressureUnit.values[prefs.getInt('pressureUnit')!];
  }
  if (prefs.getBool('useDepthOffset') != null) {
    useDepthOffset = prefs.getBool('useDepthOffset')!;
  }
}
