/* import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:gpx/gpx.dart';

abstract class FileFunctions {
  void loadCSV();
  void loadGPX();
  void getGPXfromCSV();

  List<String> getCSVHeader();
  List<List<dynamic>> getCSVData();
  List<List<dynamic>> getGPXData();

  Future<File> getCSVFile();
  Future<File> getGPXFile();
}

class FileControl implements FileFunctions {

  List<List<dynamic>> csvListData = [];
  List<dynamic> csvHeaderData = [];
  List<List<dynamic>> gpxListData = [];
  File csvFilePath = File("null");
  File gpxFilePath = File("null");

  @override
  void loadCSV() async {
    if (csvFilePath.path == "null") {
      csvFilePath = await getCSVFile();
    }
    final List<String> lines = csvFilePath.readAsLinesSync();
      csvHeaderData = lines.first.split(',');
      csvListData = lines.skip(1).map((line) => line.split(',').map((value) {
        final num? parsedNum = num.tryParse(value);
        return parsedNum ?? value;
      }).toList()).toList();
  }

  @override
  void loadGPX() async {
      if (gpxFilePath.path == "null") {
        gpxFilePath = await getGPXFile();
      }
      final gpxData = gpxFilePath.readAsStringSync();
      final gpx = GpxReader().fromString(gpxData);
      gpxListData = gpx.trks.expand((trk) => trk.trksegs).expand((trkseg) => trkseg.trkpts).map((wpt) => [wpt.lat, wpt.lon]).toList();
  }

  @override
  void getGPXfromCSV() {
    gpxListData = csvListData.map((row) {
      final lat = row[15];
      final lon = row[16];
      return [lat, lon];
    }).toList();
  }

  @override
  List<String> getCSVHeader() {
    if (csvHeaderData.isEmpty) {
      loadCSV();
    }
    return csvHeaderData.cast<String>();
  }

  @override
  List<List<dynamic>> getCSVData() {
    if (csvListData.isEmpty) {
      loadCSV();
    }
    return csvListData;
  }

  @override
  List<List<dynamic>> getGPXData() {
    if (gpxListData.isEmpty) {
      loadGPX();
    }
    return gpxListData;
  }

  @override
  Future<File> getCSVFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ["csv"]);
    if (result != null) {
      File file = File(result.files.single.path!);
      return file;
    } else {
      // User canceled the picker
      // return File("null");
      return csvFilePath;
    }
  }

  @override
  Future<File> getGPXFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ["gpx"]);
    if (result != null) {
      File file = File(result.files.single.path!);
      return file;
    } else {
      // User canceled the picker
      // return File("null");
      return gpxFilePath;
    }
  }
} */