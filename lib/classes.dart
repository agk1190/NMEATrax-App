import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

DepthUnit depthUnit = DepthUnit.feet;
TempUnit tempUnit = TempUnit.celsius;
SpeedUnit speedUnit = SpeedUnit.kn;
FuelUnit fuelUnit = FuelUnit.litre;
PressureUnit pressureUnit = PressureUnit.kpa;
bool useDepthOffset = false;

class UnitFunctions {
  static String unitFor(ConversionType type, {bool leadingSpace = true}) {
    String result;
    switch (type) {
      case ConversionType.none:
        result = '';
      case ConversionType.temp:
      case ConversionType.wTemp:
        result = tempUnit == TempUnit.celsius ? '°C' : '°F';
      case ConversionType.depth:
        result = depthUnit == DepthUnit.meters ? 'm' : 'ft';
      case ConversionType.fuelRate:
        result = fuelUnit == FuelUnit.litre ? 'L/h' : 'gph';
      case ConversionType.fuelEfficiency:
        result = fuelUnit == FuelUnit.litre ? 'L/km' : 'mpg';
      case ConversionType.pressure:
        switch (pressureUnit) {
          case PressureUnit.psi:
            result = 'psi';
          case PressureUnit.kpa:
            result = 'kpa';
          case PressureUnit.inHg:
            result = 'inHg';
          case PressureUnit.bar:
            result = 'bar';
        }
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
      result = tempUnit == TempUnit.celsius ? '°C' : '°F';
    } else if (dataHeader.contains('Depth')) {
      result = depthUnit == DepthUnit.meters ? 'm' : 'ft';
      result = leadingSpace ? ' $result' : result;
    } else if (dataHeader.contains('Rate')) {
      result = fuelUnit == FuelUnit.litre ? 'L/h' : 'gph';
      result = leadingSpace ? ' $result' : result;
    } else if (dataHeader.contains('Efficiency')) {
      result = fuelUnit == FuelUnit.litre ? 'L/km' : 'mpg';
      result = leadingSpace ? ' $result' : result;
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
    } else if (dataHeader.contains('Pressure')) {
      switch (pressureUnit) {
        case PressureUnit.psi:
          result = 'psi';
        case PressureUnit.kpa:
          result = 'kpa';
        case PressureUnit.bar:
          result = 'bar';
        case PressureUnit.inHg:
          result = 'inHg';
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
    } else if (key.contains('Pressure')) {
      switch (pressureUnit) {
        case PressureUnit.psi:
          return round(value * 0.1450377377, decimals: 0);
        case PressureUnit.kpa:
          return round(value * 1.0, decimals: 0);
        case PressureUnit.bar:
          return round(value * 0.01, decimals: 0);
        case PressureUnit.inHg:
          return round(value * 0.296133971, decimals: 0);
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
    return Expanded(
      child: SizedBox(
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
      ),
    );
  }
}

class NMEAdataRow extends StatelessWidget {
  final dynamic mainContext;
  final List<SizedNMEABox> boxes;

  const NMEAdataRow({
    super.key,
    required this.mainContext,
    required this.boxes,
  });
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: boxes,
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
    required this.pressureChanged,
    required this.useDepthOffsetChanged,
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
  final Function(Set<PressureUnit> selection) pressureChanged;
  final Function(bool? selection) useDepthOffsetChanged;
  final Function() toggleThemeAction;
  final String appVersion;
  final ThemeMode currentThemeMode;
  final dynamic mainContext;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 200,
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
          ListTile(
            textColor: Theme.of(mainContext).colorScheme.onSurface,
            iconColor: Theme.of(mainContext).colorScheme.onSurface,
            title: Text('Units', style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
            leading: const Icon(Icons.settings),
            onTap: () {
              Navigator.of(context).pop();
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => UnitSelectionDialog(
              //       depthChanged: (selection) {
              //         depthChanged(selection);
              //       },
              //       tempChanged: (selection) {
              //         tempChanged(selection);
              //       },
              //       speedChanged: (selection) {
              //         speedChanged(selection);
              //       },
              //       fuelChanged: (selection) {
              //         fuelChanged(selection);
              //       },
              //       pressureChanged: (selection) {
              //         pressureChanged(selection);
              //       },
              //       useDepthOffsetChanged: (selection) {
              //         useDepthOffsetChanged(selection);
              //       },
              //       mainContext: mainContext,
              //     ),
              //   ),
              // );
              showDialog(context: context, builder: (context) {
                return UnitSelectionDialog(
                  depthChanged: (selection) {
                    depthChanged(selection);
                  },
                  tempChanged: (selection) {
                    tempChanged(selection);
                  },
                  speedChanged: (selection) {
                    speedChanged(selection);
                  },
                  fuelChanged: (selection) {
                    fuelChanged(selection);
                  },
                  pressureChanged: (selection) {
                    pressureChanged(selection);
                  },
                  useDepthOffsetChanged: (selection) {
                    useDepthOffsetChanged(selection);
                  },
                  mainContext: mainContext,
                );
              },);
            },
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
              // Padding(
              //   padding: const EdgeInsets.all(8.0),
              //   child: SegmentedButton(
              //     style: ButtonStyle(
              //       backgroundColor: WidgetStateProperty.resolveWith<Color>(
              //         (Set<WidgetState> states) {
              //             if (states.contains(WidgetState.selected)){
              //               return Theme.of(mainContext).colorScheme.primary;
              //             }
              //             return Theme.of(mainContext).colorScheme.surface;
              //           },
              //       ),
              //     ),
              //     showSelectedIcon: false,
              //     segments: <ButtonSegment<DepthUnit>>[
              //       ButtonSegment(
              //         value: DepthUnit.feet,
              //         label: Text('ft', style: TextStyle(color: depthUnit == DepthUnit.feet ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
              //         tooltip: 'Feet'
              //       ),
              //       ButtonSegment(
              //         value: DepthUnit.meters,
              //         label: Text('m', style: TextStyle(color: depthUnit == DepthUnit.meters ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
              //         tooltip: 'Meters'
              //       ),
              //     ], 
              //     selected: <DepthUnit>{depthUnit},
              //     onSelectionChanged: depthChanged,
              //   ),
              // ),
              // Padding(
              //   padding: const EdgeInsets.all(8.0),
              //   child: SegmentedButton(
              //     style: ButtonStyle(
              //       backgroundColor: WidgetStateProperty.resolveWith<Color>(
              //         (Set<WidgetState> states) {
              //             if (states.contains(WidgetState.selected)){
              //               return Theme.of(mainContext).colorScheme.primary;
              //             }
              //             return Theme.of(mainContext).colorScheme.surface;
              //           },
              //       ),
              //     ),
              //     showSelectedIcon: false,
              //     segments: <ButtonSegment<TempUnit>>[
              //       ButtonSegment(
              //         value: TempUnit.celsius,
              //         label: Text('\u2103', style: TextStyle(color: tempUnit == TempUnit.celsius ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
              //       ),
              //       ButtonSegment(
              //         value: TempUnit.fahrenheit,
              //         label: Text('\u2109', style: TextStyle(color: tempUnit == TempUnit.fahrenheit ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
              //       ),
              //     ], 
              //     selected: <TempUnit>{tempUnit},
              //     onSelectionChanged: tempChanged,
              //   ),
              // ),
              // Padding(
              //   padding: const EdgeInsets.all(8.0),
              //   child: SegmentedButton(
              //     style: ButtonStyle(
              //       backgroundColor: WidgetStateProperty.resolveWith<Color>(
              //         (Set<WidgetState> states) {
              //             if (states.contains(WidgetState.selected)){
              //               return Theme.of(mainContext).colorScheme.primary;
              //             }
              //             return Theme.of(mainContext).colorScheme.surface;
              //           },
              //       ),
              //     ),
              //     showSelectedIcon: false,
              //     segments: <ButtonSegment<FuelUnit>>[
              //       ButtonSegment(
              //         value: FuelUnit.litre,
              //         label: Text('Litre', style: TextStyle(color: fuelUnit == FuelUnit.litre ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
              //       ),
              //       ButtonSegment(
              //         value: FuelUnit.gallon,
              //         label: Text('Gallon', style: TextStyle(color: fuelUnit == FuelUnit.gallon ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
              //       ),
              //     ], 
              //     selected: <FuelUnit>{fuelUnit},
              //     onSelectionChanged: fuelChanged,
              //   ),
              // ),
              // Padding(
              //   padding: const EdgeInsets.all(8.0),
              //   child: SegmentedButton(
              //     style: ButtonStyle(
              //       backgroundColor: WidgetStateProperty.resolveWith<Color>(
              //         (Set<WidgetState> states) {
              //             if (states.contains(WidgetState.selected)){
              //               return Theme.of(mainContext).colorScheme.primary;
              //             }
              //             return Theme.of(mainContext).colorScheme.surface;
              //           },
              //       ),
              //     ),
              //     showSelectedIcon: false,
              //     segments: <ButtonSegment<SpeedUnit>>[
              //       ButtonSegment(
              //         value: SpeedUnit.km,
              //         label: Text('km', style: TextStyle(color: speedUnit == SpeedUnit.km ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
              //       ),
              //       ButtonSegment(
              //         value: SpeedUnit.kn,
              //         label: Text('kn', style: TextStyle(color: speedUnit == SpeedUnit.kn ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
              //       ),
              //       ButtonSegment(
              //         value: SpeedUnit.mi,
              //         label: Text('mi', style: TextStyle(color: speedUnit == SpeedUnit.mi ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
              //       ),
              //       ButtonSegment(
              //         value: SpeedUnit.ms,
              //         label: Text('m/s', style: TextStyle(color: speedUnit == SpeedUnit.ms ? Theme.of(mainContext).colorScheme.onPrimary : Theme.of(mainContext).colorScheme.onSurface),),
              //       ),
              //     ], 
              //     selected: <SpeedUnit>{speedUnit},
              //     onSelectionChanged: speedChanged,
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }
}

class UnitSelectionDialog extends StatelessWidget {
  final Function(Set<DepthUnit> selection) depthChanged;
  final Function(Set<TempUnit> selection) tempChanged;
  final Function(Set<SpeedUnit> selection) speedChanged;
  final Function(Set<FuelUnit> selection) fuelChanged;
  final Function(Set<PressureUnit> selection) pressureChanged;
  final Function(bool? selection) useDepthOffsetChanged;
  final dynamic mainContext;

  const UnitSelectionDialog({
    super.key,
    required this.depthChanged,
    required this.tempChanged,
    required this.speedChanged,
    required this.fuelChanged,
    required this.pressureChanged,
    required this.useDepthOffsetChanged,
    required this.mainContext,
  });

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: Theme.of(mainContext).colorScheme.surface,
          title: Text('Select Units', style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    color: Theme.of(mainContext).colorScheme.surfaceContainer,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SegmentedButton<DepthUnit>(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                                (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.selected)) {
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
                                label: Text(
                                  'ft',
                                  style: TextStyle(
                                    color: depthUnit == DepthUnit.feet
                                        ? Theme.of(mainContext).colorScheme.onPrimary
                                        : Theme.of(mainContext).colorScheme.onSurface,
                                  ),
                                ),
                                tooltip: 'Feet',
                              ),
                              ButtonSegment(
                                value: DepthUnit.meters,
                                label: Text(
                                  'm',
                                  style: TextStyle(
                                    color: depthUnit == DepthUnit.meters
                                        ? Theme.of(mainContext).colorScheme.onPrimary
                                        : Theme.of(mainContext).colorScheme.onSurface,
                                  ),
                                ),
                                tooltip: 'Meters',
                              ),
                            ],
                            selected: <DepthUnit>{depthUnit},
                            onSelectionChanged: (p0) {
                              setState(() {
                                depthChanged(p0);
                              });
                            },
                          ),
                          SizedBox(width: 10,),
                          CheckboxListTile(
                            title: Text('Use offset', style: TextStyle(color: Theme.of(mainContext).colorScheme.onSurface),),
                            controlAffinity: ListTileControlAffinity.leading,
                            value: useDepthOffset,
                            onChanged: (bool? value) {
                              setState(() {
                                useDepthOffsetChanged(value);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SegmentedButton<TempUnit>(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
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
                        label: Text(
                          '\u2103',
                          style: TextStyle(
                            color: tempUnit == TempUnit.celsius
                                ? Theme.of(mainContext).colorScheme.onPrimary
                                : Theme.of(mainContext).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: TempUnit.fahrenheit,
                        label: Text(
                          '\u2109',
                          style: TextStyle(
                            color: tempUnit == TempUnit.fahrenheit
                                ? Theme.of(mainContext).colorScheme.onPrimary
                                : Theme.of(mainContext).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                    selected: <TempUnit>{tempUnit},
                    onSelectionChanged: (p0) {
                      setState(() {
                        tempChanged(p0);
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SegmentedButton<FuelUnit>(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
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
                        label: Text(
                          'Litre',
                          style: TextStyle(
                            color: fuelUnit == FuelUnit.litre
                                ? Theme.of(mainContext).colorScheme.onPrimary
                                : Theme.of(mainContext).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: FuelUnit.gallon,
                        label: Text(
                          'Gallon',
                          style: TextStyle(
                            color: fuelUnit == FuelUnit.gallon
                                ? Theme.of(mainContext).colorScheme.onPrimary
                                : Theme.of(mainContext).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                    selected: <FuelUnit>{fuelUnit},
                    onSelectionChanged: (p0) {
                      setState(() {
                        fuelChanged(p0);
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SegmentedButton<SpeedUnit>(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
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
                        label: Text(
                          'km',
                          style: TextStyle(
                            color: speedUnit == SpeedUnit.km
                                ? Theme.of(mainContext).colorScheme.onPrimary
                                : Theme.of(mainContext).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: SpeedUnit.kn,
                        label: Text(
                          'kn',
                          style: TextStyle(
                            color: speedUnit == SpeedUnit.kn
                                ? Theme.of(mainContext).colorScheme.onPrimary
                                : Theme.of(mainContext).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: SpeedUnit.mi,
                        label: Text(
                          'mi',
                          style: TextStyle(
                            color: speedUnit == SpeedUnit.mi
                                ? Theme.of(mainContext).colorScheme.onPrimary
                                : Theme.of(mainContext).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: SpeedUnit.ms,
                        label: Text(
                          'm/s',
                          style: TextStyle(
                            color: speedUnit == SpeedUnit.ms
                                ? Theme.of(mainContext).colorScheme.onPrimary
                                : Theme.of(mainContext).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                    selected: <SpeedUnit>{speedUnit},
                    onSelectionChanged: (p0) {
                      setState(() {
                        speedChanged(p0);
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SegmentedButton<PressureUnit>(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
                            return Theme.of(mainContext).colorScheme.primary;
                          }
                          return Theme.of(mainContext).colorScheme.surface;
                        },
                      ),
                    ),
                    showSelectedIcon: false,
                    segments: <ButtonSegment<PressureUnit>>[
                      ButtonSegment(
                        value: PressureUnit.psi,
                        label: Text(
                          'psi',
                          style: TextStyle(
                            color: pressureUnit == PressureUnit.psi
                                ? Theme.of(mainContext).colorScheme.onPrimary
                                : Theme.of(mainContext).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: PressureUnit.kpa,
                        label: Text(
                          'kpa',
                          style: TextStyle(
                            color: pressureUnit == PressureUnit.kpa
                                ? Theme.of(mainContext).colorScheme.onPrimary
                                : Theme.of(mainContext).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: PressureUnit.bar,
                        label: Text(
                          'bar',
                          style: TextStyle(
                            color: pressureUnit == PressureUnit.bar
                                ? Theme.of(mainContext).colorScheme.onPrimary
                                : Theme.of(mainContext).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: PressureUnit.inHg,
                        label: Text(
                          'inHg',
                          style: TextStyle(
                            color: pressureUnit == PressureUnit.inHg
                                ? Theme.of(mainContext).colorScheme.onPrimary
                                : Theme.of(mainContext).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                    selected: <PressureUnit>{pressureUnit},
                    onSelectionChanged: (p0) {
                      setState(() {
                        pressureChanged(p0);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all<Color>(Theme.of(mainContext).colorScheme.primary),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Done', style: TextStyle(color: Theme.of(mainContext).colorScheme.onPrimary),),
            ),
          ],
        );
      },
    );
  }
}

class NmeaViolation {
  final String name;
  final dynamic value;
  final int line;

  NmeaViolation({required this.name, required this.value, required this.line});
}

class EngineData {
  int id = 0;
  int? rpm;
  double? boostPres;
  int? legTilt;
  double? oilTemp;
  double? oilPres;
  double? coolantTemp;
  double? coolantPres;
  double? voltage;
  double? fuelRate;
  double? fuelPres;
  double? efficieny;
  int? hours;
  double? engineLoad;
  double? engineTorque;
  List<String>? errors;

  EngineData({this.id = 0, this.rpm, this.boostPres, this.legTilt, this.oilTemp, this.oilPres, this.coolantTemp, this.coolantPres, this.voltage, this.fuelRate, this.fuelPres, this.efficieny, this.hours, this.engineLoad, this.engineTorque, this.errors});

  // Factory constructor for creating an instance from JSON   // ChatGPT
  factory EngineData.fromJson(Map<String, dynamic> json) {
    return EngineData(
      rpm: json['rpm'] as int?, // Use nullable types
      boostPres: json['boostPres'] as double?,
      legTilt: json['legTilt'] as int?,
      oilTemp: json['oTemp'] as double?,
      oilPres: json['oPres'] as double?,
      coolantTemp: json['eTemp'] as double?,
      coolantPres: json['ePres'] as double?,
      voltage: json['battV'] as double?,
      fuelRate: json['fuelRate'] as double?,
      fuelPres: json['fuelPres'] as double?,
      efficieny: json['efficiency'] as double?,
      hours: json['eHours'] as int?,
      engineLoad: json['eLoad'] as double?,
      engineTorque: json['eTorque'] as double?,
    );
  }

  EngineData updateFromJson(Map<String, dynamic> json) {
    return EngineData(
      rpm: json['rpm'] ?? rpm,
      boostPres: json['boostPres'] ?? boostPres,
      legTilt: json['legTilt'] ?? legTilt,
      oilTemp: json['oTemp'] ?? oilTemp,
      oilPres: json['oPres'] ?? oilPres,
      coolantTemp: json['eTemp'] ?? coolantTemp,
      coolantPres: json['ePres'] ?? coolantPres,
      voltage: json['battV'] ?? voltage,
      fuelRate: json['fuelRate'] ?? fuelRate,
      fuelPres: json['fuelPres'] ?? fuelPres,
      efficieny: json['efficiency'] ?? efficieny,
      hours: json['eHours'] ?? hours,
      engineLoad: json['eLoad'] ?? engineLoad,
      engineTorque: json['eTorque'] ?? engineTorque,
      errors: errors,
    );
  }

  EngineData updateErrorsFromJson(Map<String, dynamic> json) {
    int status1 = json['status1'] ?? 0;
    int status2 = json['status2'] ?? 0;

    List<String> status1ErrorNames = [
      "Check Engine",
      "Over Temperature",
      "Low Oil Pressure",
      "Low Oil Level",
      "Low Fuel Pressure",
      "Low Voltage",
      "Low Coolant Level",
      "Water Flow",
      "Water in Fuel",
      "Charge Indicator",
      "Preheat Indicator",
      "High Boost Pressure",
      "Rev Limit Exceeded",
      "EGR System",
      "Throttle Position Sensor",
      "Engine Emergency Stop Mode",
    ];

    List<String> status2ErrorNames = [
      "Warning Level 1",
      "Warning Level 2",
      "Power Reduction",
      "Maintenance Needed",
      "Engine Comm Error",
      "Sub or Secondary Throttle",
      "Neutral Start Protect",
      "Engine Shutting Down",
      "Reserved 1",
      "Reserved 2",
      "Reserved 3",
      "Reserved 4",
      "Reserved 5",
      "Reserved 6",
      "Reserved 7",
      "Reserved 8",
    ];

    // status1Errors = [];
    // status2Errors = [];
    errors = [];
    for (int i = 0; i < 16; i++) {
      if ((status1 & (1 << i)) != 0) {
        // status1Errors?.add(status1ErrorNames[i]);
        errors?.add(status1ErrorNames[i]);
      }
      if ((status2 & (1 << i)) != 0) {
        errors?.add(status2ErrorNames[i]);
      }
    }

    return EngineData(
      id: id,
      rpm: rpm,
      boostPres: boostPres,
      legTilt: legTilt,
      oilTemp: oilTemp,
      oilPres: oilPres,
      coolantTemp: coolantTemp,
      coolantPres: coolantPres,
      voltage: voltage,
      fuelRate: fuelRate,
      fuelPres: fuelPres,
      efficieny: efficieny,
      hours: hours,
      engineLoad: engineLoad,
      engineTorque: engineTorque,
      errors: errors,
    );
  }
  // Method to convert an instance to JSON    // ChatGPT
  // Map<String, dynamic> toJson() {
  //   return {
  //     if (rpm != null) 'rpm': rpm, // Include only non-null fields
  //     if (temp != null) 'temp': temp,
  //     if (pres != null) 'pres': pres,
  //   };
  // }
}

class GpsData {
  int id = 0;
  int? unixTime;
  double? latitude;
  double? longitude;
  double? speedOverGround;
  int? courseOverGround;
  double? magneticVariation;

  GpsData({this.id = 0, this.unixTime, this.latitude, this.longitude, this.speedOverGround, this.courseOverGround, this.magneticVariation});

  GpsData updateFromJson(Map<String, dynamic> json) {
    return GpsData(
      unixTime: json['unixTime'] ?? unixTime,
      latitude: json['lat'] ?? latitude,
      longitude: json['lon'] ?? longitude,
      speedOverGround: json['sog'] ?? speedOverGround,
      courseOverGround: json['cog'] ?? courseOverGround,
      magneticVariation: json['magVar'] ?? magneticVariation,
    );
  }
}

class FluidLevel {
  int id = 0;
  double? fluidType;
  double? level;
  double? capacity;

  FluidLevel({this.id = 0, this.fluidType, this.level, this.capacity});

  FluidLevel updateFromJson(Map<String, dynamic> json) {
    return FluidLevel(
      fluidType: json['fluidType'] ?? fluidType,
      level: json['level'] ?? level,
      capacity: json['capacity'] ?? capacity,
    );
  }
}

class TransmissionData{
  int id = 0;
  String? gear;
  double? oilTemp;
  double? oilPressure;

  TransmissionData({this.id = 0, this.gear, this.oilTemp, this.oilPressure});

  TransmissionData updateFromJson(Map<String, dynamic> json) {
    return TransmissionData(
      gear: json['gear'] ?? gear,
      oilTemp: json['oTemp'] ?? oilTemp,
      oilPressure: json['oPres'] ?? oilPressure,
    );
  }
}

class DepthData{
  int id = 0;
  double? depth;
  double? offset;

  DepthData({this.id = 0, this.depth, this.offset});

  DepthData updateFromJson(Map<String, dynamic> json) {
    return DepthData(
      depth: json['depth'] ?? depth,
      offset: json['offset'] ?? offset,
    );
  }
}

class TemperatureData{
  int id = 0;
  int? tempInstance;
  int? tempSource;
  double? actualTemp;
  double? setTemp;

  TemperatureData({this.id = 0, this.tempInstance, this.tempSource, this.actualTemp, this.setTemp});

  TemperatureData updateFromJson(Map<String, dynamic> json) {
    return TemperatureData(
      tempInstance: json['tempInstance'] ?? tempInstance,
      tempSource: json['tempSource'] ?? tempSource,
      actualTemp: json['actualTemp'] ?? actualTemp,
      setTemp: json['setTemp'] ?? setTemp,
    );
  }
}

class NmeaDevice {
  int id = 0;
  bool connected;
  String? firmware;
  String? hardware;
  int? recMode;
  int? recInterval;
  bool? isLocalAP;
  String? wifiSSID;
  String? wifiPass;
  String? wifiCredentials;
  String? buildDate;

  NmeaDevice({this.id = 0, this.connected = false, this.firmware, this.hardware, this.recMode, this.recInterval, this.isLocalAP, this.wifiSSID, this.wifiPass, this.wifiCredentials, this.buildDate});

  NmeaDevice updateFromJson(Map<String, dynamic> json) {
    return NmeaDevice(
      connected: connected,
      firmware: json['firmware'] ?? firmware,
      hardware: json['hardware'] ?? hardware,
      recMode: json['recMode'] ?? recMode,
      recInterval: json['recInt'] ?? recInterval,
      isLocalAP: json['wifiMode'] ?? isLocalAP,
      wifiSSID: json['wifiSSID'] ?? wifiSSID,
      wifiPass: json['wifiPass'] ?? wifiPass,
      wifiCredentials: json['wifiCredentials'] ?? wifiCredentials,
      buildDate: json['buildDate'] ?? buildDate,
    );
  }
}

enum ConversionType {none, depth, temp, wTemp, speed, fuelRate, fuelEfficiency, pressure}

enum DepthUnit {meters, feet}

enum TempUnit {celsius, fahrenheit}

enum SpeedUnit {ms, kn, km, mi}

enum FuelUnit {litre, gallon}

enum PressureUnit {psi, kpa, inHg, bar}

enum FluidType {
  fuel,
  water,
  grayWater,
  liveWell,
  oil,
  blackWater,
  fuelGasoline,
  error,
  unavailable
}

enum EnviroDataType {temp, depth}

enum TempSource {
  seaTemp,
  outsideTemp,
  insideTemp,
  engineRoomTemp,
  mainCabinTemp,
  liveWellTemp,
  baitWellTemp,
  refridgerationTemp,
  heatingSystemTemp,
  dewPointTemp,
  apparentWindChillTemp,
  theoreticalWindChillTemp,
  heatIndexTemp,
  freezerTemp,
  exhaustGasTemp,
  shaftSealTemp,
}
