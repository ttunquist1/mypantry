import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_pantry/account.dart';
import 'package:my_pantry/friend.dart';
import 'package:my_pantry/homepage.dart';
import 'package:my_pantry/pantry.dart';
import 'package:my_pantry/qrcode.dart';
import 'package:my_pantry/screens/recipe_list_screen.dart';
import 'package:my_pantry/settings.dart';
import 'package:my_pantry/shopping.dart';
import 'package:my_pantry/sign_in.dart';
import 'package:my_pantry/sign_up.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;

  try {
    await _initializeFirebase();
  } catch (e) {
    startupError = e.toString();
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(MyPantryApp(startupError: startupError));
}

Future<void> _initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return;
  }

  // iOS/Android use their native Google config files.
  await Firebase.initializeApp();
}

class MyPantryApp extends StatefulWidget {
  const MyPantryApp({super.key, this.startupError});

  final String? startupError;

  @override
  State<MyPantryApp> createState() => _MyPantryAppState();
}

class _MyPantryAppState extends State<MyPantryApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Pantry',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFBF5F36),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F1EA),
        cardTheme: const CardThemeData(elevation: 1, margin: EdgeInsets.zero),
        appBarTheme: const AppBarTheme(centerTitle: false),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFBF5F36),
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
      home:
          widget.startupError == null
              ? const AuthWrapper()
              : StartupErrorPage(message: widget.startupError!),
      routes: {
        '/friends': (context) => const FriendsPage(),
        '/sign_in': (context) => const SignInPage(),
        '/sign_up': (context) => const SignUpPage(),
        '/pantry': (context) => const PantryPage(),
        '/shopping': (context) => const ShoppingListPage(),
        '/settings': (context) => SettingsPage(toggleTheme: toggleTheme),
        '/account': (context) => const AccountPage(),
        '/ai': (context) => const RecipeListScreen(),
        '/qr': (context) => const QRScannerPage(),
        '/homepager': (context) => const HomePager(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const SignInPage();
        }

        return const HomePager();
      },
    );
  }
}

class StartupErrorPage extends StatelessWidget {
  const StartupErrorPage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Startup error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
