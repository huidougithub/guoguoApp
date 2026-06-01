import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'screens/grade_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/pet_selection_screen.dart';
import 'services/app_store.dart';
import 'services/audio_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await AudioService.preload();
  final store = AppStore();
  await store.load();
  runApp(WisdomExplorerApp(store: store));
}

class WisdomExplorerApp extends StatefulWidget {
  const WisdomExplorerApp({super.key, required this.store});

  final AppStore store;

  @override
  State<WisdomExplorerApp> createState() => _WisdomExplorerAppState();
}

class _WisdomExplorerAppState extends State<WisdomExplorerApp>
    with WidgetsBindingObserver {
  AppStore get store => widget.store;
  Timer? lifecycleSuspendTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    lifecycleSuspendTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      lifecycleSuspendTimer?.cancel();
      AudioService.resumeForLifecycle(
        musicEnabled: store.progress.settings['music'] ?? false,
      );
    } else {
      lifecycleSuspendTimer?.cancel();
      lifecycleSuspendTimer = Timer(const Duration(milliseconds: 700), () {
        AudioService.suspendForLifecycle();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '智慧小探险家',
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Roboto',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF8C42),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFEAF7FF),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              backgroundColor: Color(0xFFFFD166),
              foregroundColor: Color(0xFF2D2A32),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(112, 56),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          home: store.progress.selectedGrade == null
              ? GradeSelectionScreen(store: store)
              : store.progress.selectedPet == null
              ? PetSelectionScreen(store: store)
              : HomeScreen(store: store),
        );
      },
    );
  }
}
