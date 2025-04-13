import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'router/router.dart';
import 'screens/permissions_screen.dart';
import 'services/timer_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables from .env file
  await dotenv.load();
  
  // Initialize Gemini with API key from .env
  final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  Gemini.init(apiKey: apiKey);
  
  // Initialize TimerService
  await TimerService().init();
  
  runApp(
    const ProviderScope(
      child: CookMateApp(),
    ),
  );
}

class CookMateApp extends StatefulWidget {
  const CookMateApp({super.key});

  @override
  State<CookMateApp> createState() => _CookMateAppState();
}

class _CookMateAppState extends State<CookMateApp> {
  bool _permissionsGranted = false;

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
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
