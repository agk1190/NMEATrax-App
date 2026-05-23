import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../classes.dart';
import '../main.dart';

import 'pages/data_page.dart';
import 'pages/analyze_page.dart';
import 'pages/map_page.dart';
import 'pages/limits_page.dart';
import 'pages/replay_shared_state.dart';

class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key});

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, animationDuration: Durations.short4);
    loadPrefs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext mainContext) {
    return MaterialApp(
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
      title: 'NMEATrax Replay',
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          drawer: NmeaDrawer(
            option1Action: () {
              Navigator.pushReplacementNamed(context, '/live');
            },
            option2Action: () {
              Navigator.pushReplacementNamed(context, '/replay');
            },
            option3Action: () {
              Navigator.pushReplacementNamed(context, '/files');
            },
            toggleThemeAction: () {
              setState(() {
                MyApp.themeNotifier.value =
                  MyApp.themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                savePrefs();
              });
            },
            depthChanged: (selection) {
              setState(() {
                depthUnit = selection.first;
                savePrefs();
              });
            },
            tempChanged: (selection) {
              setState(() {
                tempUnit = selection.first;
                savePrefs();
              });
            },
            speedChanged: (selection) {
              setState(() {
                speedUnit = selection.first;
                savePrefs();
              });
            },
            fuelChanged: (selection) {
              setState(() {
                fuelUnit = selection.first;
                savePrefs();
              });
            },
            pressureChanged: (selection) {
              setState(() {
                pressureUnit = selection.first;
                savePrefs();
              });
            },
            useDepthOffsetChanged: (selection) {
              setState(() {
                useDepthOffset = selection!;
                savePrefs();
              });
            },
            appVersion: MyApp.appVersion,
            currentThemeMode: MyApp.themeNotifier.value,
            mainContext: context
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            systemOverlayStyle: SystemUiOverlayStyle(systemNavigationBarColor: Theme.of(context).colorScheme.surfaceContainer),
            backgroundColor: Theme.of(context).colorScheme.primary,
            iconTheme: Theme.of(context).primaryIconTheme,
            title: Text('NMEATrax Replay', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),),
            bottom: TabBar(
              controller: _tabController,
              onTap: (value) {
                _tabController.animateTo(value);
                analyzeData();
                analyzeVisibleNotifier.value = true;
                if (value != 3) {
                  setSelectedLimit(0);
                }
              },
              indicatorColor: Colors.white,
              tabs: const [
                Tab(icon: Icon(Icons.directions_boat_sharp, color: Colors.white)),
                Tab(icon: Icon(Icons.analytics, color: Colors.white)),
                Tab(icon: Icon(Icons.map, color: Colors.white)),
                Tab(icon: Icon(Icons.settings, color: Colors.white)),
              ],
            ),
          ),
          bottomNavigationBar: AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              return BottomAppBar(
                color: Theme.of(mainContext).colorScheme.surfaceContainer,
                child: switch (_tabController.index) {
                  0 => const DataAppBar(),
                  1 => const AnalyzeDataAppBar(),
                  2 => const MapAppBar(),
                  3 => const LimitsAppBar(),
                  int() => const Row(),
                }
              );
            },
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              const DataPage(),
              AnalyzePage(onOpenDataTab: () {
                _tabController.animateTo(0);
              }),
              const MapPage(),
              const LimitsPage(),
            ]
          ),
        ),
      ),
    );
  }
}
