import 'package:flutter/material.dart';
import 'replay.dart';
import 'live.dart';
import 'file_manager.dart';

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
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ).copyWith(
              primary: const Color(0xFF0050C7),
              onPrimary: Colors.white,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
              ).copyWith(
                primary: const Color(0xFF0050C7),
                onPrimary: Colors.white,
              ),
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          themeMode: currentMode,
          // home: const LivePage(),
          initialRoute: '/live',
          routes: {
            '/live':(context) => const LivePage(),
            '/replay':(context) => const ReplayPage(),
            '/files':(context) => const FilePage(),
          },
        );
      });
  }
}
