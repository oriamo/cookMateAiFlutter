import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'router/router.dart';
import 'screens/permissions_screen.dart';
import 'services/timer_service.dart';

// Global flag for demo mode
const bool isDemoMode = true;

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables from .env file if not in demo mode
    if (!isDemoMode) {
      await dotenv.load();
      
      // Initialize Gemini with API key from .env
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      Gemini.init(apiKey: apiKey);
    } else {
      // In demo mode, we'll just provide a placeholder
      print('Running in DEMO MODE - Using mock data instead of API services');
    }

    // Initialize TimerService
    await TimerService().init();

    runApp(
      const ProviderScope(
        child: CookMateApp(),
      ),
    );
  } catch (e) {
    print('Error during initialization: $e');
    // Default to demo mode if there's an error
    runApp(
      const ProviderScope(
        child: CookMateApp(),
      ),
    );
  }
}

class CookMateApp extends StatefulWidget {
  const CookMateApp({super.key});

  @override
  State<CookMateApp> createState() => _CookMateAppState();
}

class _CookMateAppState extends State<CookMateApp> {
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    // In demo mode, we'll auto-grant permissions
    if (isDemoMode) {
      _permissionsGranted = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionsGranted) {
      return MaterialApp(
        title: 'CookMate AI',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            primary: Colors.deepPurple,
            secondary: Colors.deepOrange,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: PermissionsScreen(
          onPermissionsGranted: () {
            setState(() {
              _permissionsGranted = true;
            });
          },
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp.router(
      title: 'CookMate AI' + (isDemoMode ? ' (Demo)' : ''),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          primary: Colors.green,
          secondary: Colors.deepOrange,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}