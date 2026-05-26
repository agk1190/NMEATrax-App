import 'package:flutter/material.dart';
import '../../main.dart';
import 'package:nmeatrax_app/classes.dart';
import 'replay_shared_state.dart';

class LimitsPage extends StatefulWidget {
  const LimitsPage({super.key});

  @override
  State<LimitsPage> createState() => _LimitsPageState();
}

class _LimitsPageState extends State<LimitsPage> {

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReplayLimitsData>(
      valueListenable: replayLimitsNotifier,
      builder: (context, limitsData, __) => ValueListenableBuilder<int>(
        valueListenable: selectedLimitNotifier,
        builder: (context, selectedLimit, _) => SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 20),
                child: Text(
                  'Analysis Limits',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                  ),
                ),
              ),
              DropdownMenu(
                width: 250,
                initialSelection: limitsData.upper.keys.first,
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surface),
                  surfaceTintColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerHighest),
                ),
                textStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),
                enableSearch: false,
                enableFilter: false,
                dropdownMenuEntries: limitsData.upper.keys.map<DropdownMenuEntry<dynamic>>((String value) {
                  return DropdownMenuEntry<String>(
                    value: value,
                    label: value,
                    style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.onSurfaceVariant)),
                  );
                }).toList(),
                onSelected: (value) {
                  final List<dynamic> keyList = limitsData.upper.keys.toList();
                  setSelectedLimit(keyList.indexOf(value));
                },
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(
                  'Lower Limit',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 50),
                leading: Icon(Icons.vertical_align_bottom, color: Theme.of(context).colorScheme.onSurface),
                trailing: Text(
                  UnitFunctions.returnInPreferredUnit(limitsData.lower.keys.elementAt(selectedLimit), limitsData.lower.values.elementAt(selectedLimit)).toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
                onTap: () => showInputDialog(context, 'Enter lower limit', false),
              ),
              ListTile(
                title: Text(
                  'Upper Limit',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 50),
                leading: Icon(Icons.vertical_align_top_outlined, color: Theme.of(context).colorScheme.onSurface),
                trailing: Text(
                  UnitFunctions.returnInPreferredUnit(limitsData.upper.keys.elementAt(selectedLimit), limitsData.upper.values.elementAt(selectedLimit)).toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
                onTap: () => showInputDialog(context, 'Enter upper limit', true),
              ),
            ]
          ),
        ),
      ),
    );
  }

  //https://www.appsdeveloperblog.com/alert-dialog-with-a-text-field-in-flutter/
  showInputDialog(BuildContext context, String title, bool upper) {
    double input = 0;

    Widget confirmButton = ElevatedButton(
      style: ButtonStyle(
        backgroundColor:WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
      ),
      child: Text("OK", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
      onPressed: () {
        updateSelectedLimitValue(upper: upper, input: input);
        savePrefs();
        //https://stackoverflow.com/a/50683571 for nav.pop
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
    AlertDialog alert = AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(title),
      content: TextField(
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        autofocus: true,
        onChanged: (value) {
          try {
            input = double.parse(value);
          } on Exception {
            // do nothing
          }
        },
        onSubmitted: (value) {
          try {
            updateSelectedLimitValue(upper: upper, input: double.parse(value));
            savePrefs();
          } on Exception {
            // do nothing
          }
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
      actions: [
        confirmButton,
      ],
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

}

class LimitsAppBar extends StatelessWidget {
  const LimitsAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            MyApp.themeNotifier.value =
              MyApp.themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
            savePrefs();
          },
          icon: MyApp.themeNotifier.value == ThemeMode.light ? Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.surface,) : Icon(Icons.light_mode, color: Theme.of(context).colorScheme.onPrimary,),
        ),
      ],
    );
  }
}