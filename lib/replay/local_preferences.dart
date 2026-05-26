/* import 'package:shared_preferences/shared_preferences.dart';

abstract class LocalPreferences {
  Future<void> savePrefs();
  Future<void> loadPrefs();
}

class ReplayPreferences implements LocalPreferences {
  
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  Map<String, dynamic> lowerLimits = <String, dynamic>{
  'RPM':0.0,
  'Engine Temp':273.15,
  'Oil Temp':273.15,
  'Oil Pressure':300.0,
  'Fuel Rate':0.0,
  'Fuel Level':10.0,
  'Fuel Efficiency':0.0,
  'Leg Tilt':0.0,
  'Speed':0.0,
  'Heading':0.0,
  'Depth':1.0,
  'Water Temp':275.15,
  'Battery Voltage':12.0,
  'Engine Hours':0.0,
  'Latitude':47.0,
  'Longitude':-125.0,
  'Magnetic Variation':0.0,
  'Error Bits':0.0,
};
  Map<String, dynamic> upperLimits = <String, dynamic>{
    'RPM':5200.0,
    'Engine Temp':353.15,
    'Oil Temp':388.15,
    'Oil Pressure':700.0,
    'Fuel Rate':50.0,
    'Fuel Level':100.0,
    'Fuel Efficiency':4.0,
    'Leg Tilt':100.0,
    'Speed':15.4333,
    'Heading':360.0,
    'Depth':304.8000000012192,
    'Water Temp':298.15,
    'Battery Voltage':15.0,
    'Engine Hours':3600000.0,
    'Latitude':50.0,
    'Longitude':-122.0,
    'Magnetic Variation':20.0,
    'Error Bits':0.0,
  };

  @override
  Future<void> savePrefs() async {
    final SharedPreferences prefs = await _prefs;
    prefs.setBool('darkMode', MyApp.themeNotifier.value == ThemeMode.dark ? true : false);
    prefs.setString("lower", jsonEncode(lowerLimits));
    prefs.setString("upper", jsonEncode(upperLimits));
    prefs.setBool('isMeters', depthUnit == DepthUnit.meters ? true : false);
    prefs.setBool('isCelsius', tempUnit == TempUnit.celsius ? true : false);
    prefs.setBool('isLitre', fuelUnit == FuelUnit.litre ? true : false);
    prefs.setInt('speedUnit', speedUnit.index);
  }


  @override
  Future<void> loadPrefs() async {
    final SharedPreferences prefs = await _prefs;
    if (prefs.getBool('darkMode') == null) {return;}
    if (prefs.getString("lower") == null) {return;}
    if (prefs.getString("upper") == null) {return;}
    lowerLimits = jsonDecode(prefs.getString("lower")!);
    upperLimits = jsonDecode(prefs.getString("upper")!);
    if (prefs.getBool('darkMode')!) {
      MyApp.themeNotifier.value = ThemeMode.dark;
    } else {
        MyApp.themeNotifier.value = ThemeMode.light;
    }
  } 
} */