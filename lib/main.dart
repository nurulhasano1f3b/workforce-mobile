import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'data/notifications_repository.dart';
import 'data/providers.dart';
import 'data/punch_repository.dart';
import 'data/shifts_repository.dart';
import 'data/user_repository.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite needs explicit factory initialisation on non-mobile platforms.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Lock to portrait — timecard + roster are single-column layouts.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Pre-warm the PunchRepository.  init() loads SQLite cache and starts the
  // connectivity watcher — no network call blocks runApp().
  final punchRepo = PunchRepository();
  await punchRepo.init();

  // Pre-warm shifts, notifications, and user profile with the stored token.
  final shiftsRepo = ShiftsRepository();
  final notifRepo = NotificationsRepository();
  final userRepo = UserRepository();
  if (punchRepo.isLoggedIn) {
    await shiftsRepo.init(punchRepo.token);
    await notifRepo.init(punchRepo.token);
    userRepo.updateToken(punchRepo.token);
  }

  runApp(
    ProviderScope(
      overrides: [
        punchRepositoryProvider.overrideWithValue(punchRepo),
        shiftsRepositoryProvider.overrideWithValue(shiftsRepo),
        notificationsRepositoryProvider.overrideWithValue(notifRepo),
        userRepositoryProvider.overrideWithValue(userRepo),
      ],
      child: const WorkforceApp(),
    ),
  );
}

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

class WorkforceApp extends StatelessWidget {
  const WorkforceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workforce',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const _AuthGate(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1B8A5A),
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth gate — checks for a stored token and routes accordingly.
//
// Flow:
//   1. SQLite cache is already loaded at this point (main() did init()).
//   2. If token exists → HomeScreen (already shows cached data, background
//      refresh in progress).
//   3. If no token → LoginScreen.
// ---------------------------------------------------------------------------

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(punchRepositoryProvider);
    return repo.isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}

// ---------------------------------------------------------------------------
// Splash — only shown on very first cold start while the DB is opening.
// Not used after init() completes, but kept here in case of future use.
// ---------------------------------------------------------------------------

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1B8A5A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_rounded, size: 56, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Workforce',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
