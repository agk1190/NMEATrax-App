import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

DepthUnit depthUnit = DepthUnit.feet;
TempUnit tempUnit = TempUnit.celsius;
SpeedUnit speedUnit = SpeedUnit.kn;
FuelUnit fuelUnit = FuelUnit.litre;

class UnitFunctions {
  static String unitFor(ConversionType type, {bool leadingSpace = true}) {
    String result;
    switch (type) {
      case ConversionType.temp:
      case ConversionType.wTemp:
        result = tempUnit == TempUnit.celsius ? '\u2103' : '\u2109';
      case ConversionType.depth:
        result = depthUnit == DepthUnit.meters ? 'm' : 'ft';
      case ConversionType.fuelRate:
        result = fuelUnit == FuelUnit.litre ? 'L/h' : 'gph';
      case ConversionType.fuelEfficiency:
        result = fuelUnit == FuelUnit.litre ? 'L/km' : 'mpg';
      case ConversionType.speed:
        switch (speedUnit) {
          case SpeedUnit.km:
            result = 'km/h';
          case SpeedUnit.kn:
            result = 'kn';
          case SpeedUnit.mi:
           result = 'mph';
          case SpeedUnit.ms:
            result = 'm/s';
        }
    }
    return leadingSpace ? ' $result' : result;
  }

  static String unitOf(String dataHeader, {bool leadingSpace = true}) {
    String result;
    if (dataHeader.contains('Temp')) {
      result = tempUnit == TempUnit.celsius ? '\u2103' : '\u2109';
    } else if (dataHeader.contains('Depth')) {
      result = depthUnit == DepthUnit.meters ? 'm' : 'ft';
      result = leadingSpace ? ' $result' : result;
    } else if (dataHeader.contains('Rate')) {
      result = fuelUnit == FuelUnit.litre ? 'L/h' : 'gph';
      result = leadingSpace ? ' $result' : result;
    } else if (dataHeader.contains('Efficiency')) {
      result = fuelUnit == FuelUnit.litre ? 'L/km' : 'mpg';
      result = leadingSpace ? ' $result' : result;
    } else if (dataHeader.contains('Pressure')) {
      result = leadingSpace ? ' kpa' : 'kpa';
    } else if (dataHeader.contains('Level') || dataHeader.contains('Tilt')) {
      result = '%';
    } else if (dataHeader.contains('Heading') || dataHeader.contains('Variation')) {
      result = '\u00B0';
    } else if (dataHeader.contains('Voltage')) {
      result = leadingSpace ? ' V' : 'V';
    } else if (dataHeader.contains('Hours')) {
      result = leadingSpace ? ' h' : 'h';
    } else if (dataHeader.contains('Speed')) {
      switch (speedUnit) {
        case SpeedUnit.km:
          result = 'km/h';
        case SpeedUnit.kn:
          result = 'kn';
        case SpeedUnit.mi:
          result = 'mph';
        case SpeedUnit.ms:
          result = 'm/s';
      }
      result = leadingSpace ? ' $result' : result;
    } else {
      result = '';
    }
    return result;
  }

  static dynamic returnInPreferredUnit(String key, dynamic value) {
    if (value is String) {return value;}
    if (key.contains('Temp')) {
      return tempUnit == TempUnit.celsius ? round((value - 273.15), decimals: 2) : round(((value - 273.15) * (9/5) + 32), decimals: 2);
    } else if (key.contains('Depth')) {
      return depthUnit == DepthUnit.meters ? round(value, decimals: 2) : round((value * 3.280839895), decimals: 2);
    } else if (key.contains('Rate')) {
      return (fuelUnit == FuelUnit.litre ? value : round(value * 0.26417205234375, decimals: 1));
    } else if (key.contains('Efficiency')) {
      return (fuelUnit == FuelUnit.litre ? round(value, decimals: 3) : round(2.35214583 / value, decimals: 3));
    } else if (key.contains('Hours')) {
      return round(value / 3600, decimals: 1);
    } else if (key.contains('Speed')) {
      switch (speedUnit) {
        case SpeedUnit.km:
          return round(value * 3.6, decimals: 2);
        case SpeedUnit.kn:
          return round(value * (3600/1852), decimals: 2);
        case SpeedUnit.mi:
          return round(value * 2.2369362920544025, decimals: 2);
        case SpeedUnit.ms:
          return round(value, decimals: 2);
      }
    } else {
      return value;
    }
  }

  static double convertToBaseUnit(double value, Map<String, dynamic> limitMap, int selectedLimit) {
    if (limitMap.keys.elementAt(selectedLimit).contains('Temp')) {
      return tempUnit == TempUnit.celsius ? value + 273.15 : (value - 32) * (5/9) + 273.15;
    } else if (limitMap.keys.elementAt(selectedLimit).contains('Depth')) {
      return depthUnit == DepthUnit.meters ? value : value / 3.280839895;
    } else if (limitMap.keys.elementAt(selectedLimit).contains('Rate')) {
      return (fuelUnit == FuelUnit.litre ? value : value * 3.785411784);
    } else if (limitMap.keys.elementAt(selectedLimit).contains('Efficiency')) {
      return (fuelUnit == FuelUnit.litre ? value : (3.78541 / (1.60934 * value)));
    } else if (limitMap.keys.elementAt(selectedLimit).contains('Hours')) {
      return value * 3600;
    } else if (limitMap.keys.elementAt(selectedLimit).contains('Speed')) {
      switch (speedUnit) {
        case SpeedUnit.km:
          return value * (1000/3600);
        case SpeedUnit.kn:
          return value * 0.514444;
        case SpeedUnit.mi:
          return value * (1609.34/3600);
        case SpeedUnit.ms:
          return value;
      }
    } else  {
      return value;
    }
  }
}

class ListData extends StatelessWidget {
  const ListData({
    super.key,
    required this.csvHeaderData,
    required this.csvListData,
    required this.curLineNum,
    required this.mainContext,
  });

  final List csvHeaderData;
  final List<List> csvListData;
  final int curLineNum;
  final dynamic mainContext;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: csvHeaderData.length,
        itemBuilder: (BuildContext context, int index) {
          return Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: 
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: Text('${csvHeaderData.elementAt(index)}:', textAlign: TextAlign.right, style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface))),
                  Expanded(child: Text(' ${UnitFunctions.returnInPreferredUnit(csvHeaderData.elementAt(index), csvListData.elementAt(curLineNum)[index])}${UnitFunctions.unitOf(csvHeaderData.elementAt(index))}', textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(mainContext).colorScheme.onSurface),))
                ],
              )
          );
        },
      ),
    );
  }
}

class ListAnalyzedData extends StatelessWidget {
  const ListAnalyzedData({
    super.key,
    required this.analyzedData,
    required this.action,
    required this.mainContext,
  });

  final List<NmeaViolation> analyzedData;
  final Function(int) action;
  final dynamic mainContext;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<NmeaViolation>> groupedViolations = {};

    for (var violation in analyzedData) {
      if (!groupedViolations.containsKey(violation.name)) {
        groupedViolations[violation.name] = [];
      }
      groupedViolations[violation.name]!.add(violation);
    }
    return ListView(
      shrinkWrap: true,
      children: groupedViolations.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(40, 2, 40, 2),
          child: Card(
            color: Theme.of(mainContext).colorScheme.surfaceContainer,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("${entry.key} x ${entry.value.length}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(mainContext).colorScheme.onSurface)),
                ),
                SizedBox(
                  width: 200,
                  height: entry.value.length > 3 ? 126 : null,
                  child: ListView.builder(
                    shrinkWrap: true,
                    // physics: const NeverScrollableScrollPhysics(),
                    itemCount: entry.value.length,
                    itemBuilder: (context, index) {
                      final violation = entry.value[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(0, 5, 0, 5),
                        child: ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(Theme.of(mainContext).colorScheme.surfaceContainerHigh)
                          ),
                          onPressed:() => action(violation.line),
                          // child: Text('${violation.value} @ ${violation.line}', style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
                          child: Text('${UnitFunctions.returnInPreferredUnit(violation.name, violation.value)}${UnitFunctions.unitOf(violation.name)} @ ${violation.line}', style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class SizedNMEABox extends StatelessWidget {
  final String value;
  final String title;
  final String unit;
  final double fontSize;
  final dynamic mainContext;

  const SizedNMEABox({
    super.key,
    required this.value,
    required this.title,
    required this.unit,
    this.fontSize = 24,
    required this.mainContext,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Card(
        color: Theme.of(mainContext).colorScheme.surfaceContainerLow,
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(title, style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
              Text("$value$unit", style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Theme.of(mainContext).colorScheme.onSurface),),
            ],
          ),
        )
      ),
    );
  }
}

class NmeaDrawer extends StatelessWidget {
  const NmeaDrawer({
    super.key,
    required this.option1Action,
    required this.option2Action,
    required this.option3Action,
    required this.depthChanged,
    required this.tempChanged,
    required this.speedChanged,
    required this.fuelChanged,
    required this.toggleThemeAction,
    required this.appVersion,
    required this.currentThemeMode,
    required this.mainContext,
  });
  
  final Function() option1Action;
  final Function() option2Action;
  final Function() option3Action;
  final Function(Set<DepthUnit> selection) depthChanged;
  final Function(Set<TempUnit> selection) tempChanged;
  final Function(Set<SpeedUnit> selection) speedChanged;
  final Function(Set<FuelUnit> selection) fuelChanged;
  final Function() toggleThemeAction;
  final String appVersion;
  final ThemeMode currentThemeMode;
  final dynamic mainContext;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 250,
      backgroundColor: Theme.of(mainContext).colorScheme.surface,
      child: ListView(
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              image: DecorationImage(image: AssetImage('assets/images/nmeatraxLogo.png')),
              color: Color(0xFF0050C7),
            ),
            child: Text('NMEATrax', style: TextStyle(color: Colors.white),),
          ),
          ListTile(
            textColor: Theme.of(mainContext).colorScheme.onSurface,
            iconColor: Theme.of(mainContext).colorScheme.onSurface,
            title: Text('Live', style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
            leading: const Icon(Icons.bolt),
            onTap: option1Action,
          ),
          ListTile(
            textColor: Theme.of(mainContext).colorScheme.onSurface,
            iconColor: Theme.of(mainContext).colorScheme.onSurface,
            title: Text('Replay', style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
            leading: const Icon(Icons.timeline),
            onTap: option2Action,
          ),
          ListTile(
            textColor: Theme.of(mainContext).colorScheme.onSurface,
            iconColor: Theme.of(mainContext).colorScheme.onSurface,
            title: Text('Files', style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
            leading: const Icon(Icons.edit_document),
            onTap: option3Action
          ),
          const Divider(),
          AboutListTile(
            icon: Icon(
              color: Theme.of(mainContext).colorScheme.onSurface,
              Icons.info,
            ),
            applicationIcon: const Icon(
              Icons.directions_boat,
            ),
            applicationName: 'NMEATrax',
            applicationVersion: appVersion,
            aboutBoxChildren: const [
              Text("For use with NMEATrax Vessel Monitoring System")
            ],
            child: Text('About app', style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
          ),
          const Divider(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  style: ButtonStyle(backgroundColor: WidgetStateProperty.all<Color>(Theme.of(mainContext).colorScheme.primary),),
                  onPressed: toggleThemeAction,
                  child: currentThemeMode == ThemeMode.light ? Icon(Icons.dark_mode, color: Theme.of(mainContext).colorScheme.onPrimary,) : Icon(Icons.light_mode, color: Theme.of(mainContext).colorScheme.onPrimary,),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SegmentedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)){
                            return Theme.of(mainContext).colorScheme.primary;
                          }
                          return Theme.of(mainContext).colorScheme.surface;
                        },
                    ),
                  ),
                  showSelectedIcon: false,
                  segments: <ButtonSegment<DepthUnit>>[
                    ButtonSegment(
                      value: DepthUnit.feet,
                      label: Text('ft', style: TextStyle(color: depthUnit == DepthUnit.feet ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
                      tooltip: 'Feet'
                    ),
                    ButtonSegment(
                      value: DepthUnit.meters,
                      label: Text('m', style: TextStyle(color: depthUnit == DepthUnit.meters ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
                      tooltip: 'Meters'
                    ),
                  ], 
                  selected: <DepthUnit>{depthUnit},
                  onSelectionChanged: depthChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SegmentedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)){
                            return Theme.of(mainContext).colorScheme.primary;
                          }
                          return Theme.of(mainContext).colorScheme.surface;
                        },
                    ),
                  ),
                  showSelectedIcon: false,
                  segments: <ButtonSegment<TempUnit>>[
                    ButtonSegment(
                      value: TempUnit.celsius,
                      label: Text('\u2103', style: TextStyle(color: tempUnit == TempUnit.celsius ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
                    ),
                    ButtonSegment(
                      value: TempUnit.fahrenheit,
                      label: Text('\u2109', style: TextStyle(color: tempUnit == TempUnit.fahrenheit ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
                    ),
                  ], 
                  selected: <TempUnit>{tempUnit},
                  onSelectionChanged: tempChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SegmentedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)){
                            return Theme.of(mainContext).colorScheme.primary;
                          }
                          return Theme.of(mainContext).colorScheme.surface;
                        },
                    ),
                  ),
                  showSelectedIcon: false,
                  segments: <ButtonSegment<FuelUnit>>[
                    ButtonSegment(
                      value: FuelUnit.litre,
                      label: Text('Litre', style: TextStyle(color: fuelUnit == FuelUnit.litre ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
                    ),
                    ButtonSegment(
                      value: FuelUnit.gallon,
                      label: Text('Gallon', style: TextStyle(color: fuelUnit == FuelUnit.gallon ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
                    ),
                  ], 
                  selected: <FuelUnit>{fuelUnit},
                  onSelectionChanged: fuelChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SegmentedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)){
                            return Theme.of(mainContext).colorScheme.primary;
                          }
                          return Theme.of(mainContext).colorScheme.surface;
                        },
                    ),
                  ),
                  showSelectedIcon: false,
                  segments: <ButtonSegment<SpeedUnit>>[
                    ButtonSegment(
                      value: SpeedUnit.km,
                      label: Text('km', style: TextStyle(color: speedUnit == SpeedUnit.km ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
                    ),
                    ButtonSegment(
                      value: SpeedUnit.kn,
                      label: Text('kn', style: TextStyle(color: speedUnit == SpeedUnit.kn ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
                    ),
                    ButtonSegment(
                      value: SpeedUnit.mi,
                      label: Text('mi', style: TextStyle(color: speedUnit == SpeedUnit.mi ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
                    ),
                    ButtonSegment(
                      value: SpeedUnit.ms,
                      label: Text('m/s', style: TextStyle(color: speedUnit == SpeedUnit.ms ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
                    ),
                  ], 
                  selected: <SpeedUnit>{speedUnit},
                  onSelectionChanged: speedChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NmeaViolation {
  final String name;
  final dynamic value;
  final int line;

  NmeaViolation({required this.name, required this.value, required this.line});
}

enum ConversionType {depth, temp, wTemp, speed, fuelRate, fuelEfficiency}

enum DepthUnit {meters, feet}

enum TempUnit {celsius, fahrenheit}

enum SpeedUnit {ms, kn, km, mi}

enum FuelUnit {litre, gallon}
