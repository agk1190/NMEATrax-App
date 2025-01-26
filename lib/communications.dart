import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'classes.dart';
import 'downloads.dart';

NmeaDevice nmeaDevice = NmeaDevice();

Future<void> getOptions() async {
  dynamic response;
  try {
    response = await http.get(Uri.parse('http://$connectURL/get'));

    if (response.statusCode == 200) {
      print(response.body);
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
}

Future<void> setOptions(String kvPair) async {
  try {
    final response = await http.post(Uri.parse('http://$connectURL/set?$kvPair'));
    if (response.statusCode == 200) {
      getOptions();
      // setState(() {});
    }
  } on Exception {
    //
  }
}