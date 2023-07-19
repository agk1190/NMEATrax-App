import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'replay.dart';
import 'live.dart';

const _appVersion = '2.0.0';

ColorScheme myLightColors = const ColorScheme(
  brightness: Brightness.light, 
  primary: Color(0xFF0050C7), 
  primaryContainer: Color.fromARGB(255, 118, 176, 241),
  onPrimary: Color.fromARGB(255, 219, 217, 217), 
  secondary: Color.fromARGB(255, 87, 144, 236),
  onSecondary: Color.fromARGB(255, 194, 194, 194),
  error: Color(0xFFFF50C7), 
  onError: Colors.black,
  background: Color.fromARGB(255, 240, 240, 240),
  onBackground: Color.fromARGB(255, 22, 22, 22), 
  surface: Color.fromARGB(255, 231, 231, 231),
  onSurface: Color.fromARGB(255, 219, 219, 219),
);

ColorScheme myDarkColors = const ColorScheme(
  brightness: Brightness.dark, 
  primary: Color(0xFF0050C7), 
  primaryContainer: Color.fromARGB(255, 6, 38, 80),
  onPrimary: Color.fromARGB(255, 219, 219, 219), 
  secondary: Color.fromARGB(255, 87, 144, 236),
  onSecondary: Color.fromARGB(255, 194, 194, 194),
  error: Color(0xFFFF50C7), 
  onError: Colors.black,
  background: Color.fromARGB(255, 36, 36, 36),
  onBackground: Color.fromARGB(255, 219, 219, 219), 
  surface: Color.fromARGB(255, 80, 76, 76),
  onSurface: Color.fromARGB(255, 219, 219, 219),
);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // https://www.kindacode.com/article/flutter-ways-to-make-a-dark-light-mode-toggle/ - dark mode toggle
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier, 
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'NMEATrax App',
          theme: ThemeData(colorScheme: myLightColors),
          darkTheme: ThemeData(colorScheme: myDarkColors),
          themeMode: currentMode,
          home: const HomePage(),
          initialRoute: '/live',
          routes: {
            '/live':(context) => const LivePage(),
            '/replay':(context) => const ReplayPage(),
          },
        );
      });
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NMEATrax App'),
        systemOverlayStyle: SystemUiOverlayStyle(systemNavigationBarColor: Theme.of(context).colorScheme.background),
      ),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF0050C7),
              ),
              child: Text('NMEATrax App'),
            ),
            ListTile(
              title: const Text('Live'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/live');
              },
            ),
            ListTile(
              title: const Text('Replay'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/replay');
              },
            ),
            const AboutListTile(
              icon: Icon(
                Icons.info,
              ),
              applicationIcon: Icon(
                Icons.directions_boat,
              ),
              applicationName: 'NMEATrax',
              applicationVersion: _appVersion,
              aboutBoxChildren: [
                Text("For use with NMEATrax Vessel Monitoring System")
              ],
              child: Text('About app'),
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text('Home Page'),
      ),
    );
  }
}
