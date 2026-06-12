import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "api_client.dart";
import "api_config.dart";
import "app_state.dart";
import "splash_screen.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiBaseUrl = await resolveApiBaseUrl();
  final api = ApiClient(baseUrl: apiBaseUrl);
  final state = AppState(api);
  runApp(KharidMobileApp(state: state, api: api));
}

class KharidMobileApp extends StatelessWidget {
  const KharidMobileApp({super.key, required this.state, required this.api});

  final AppState state;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: Consumer<AppState>(
        builder: (context, app, _) => MaterialApp(
          title: "kharid.tj",
          debugShowCheckedModeBanner: false,
          themeMode: app.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB), brightness: Brightness.light),
            cardColor: Colors.white,
            dividerColor: const Color(0xFFE2E8F0),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF060B12),
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D4ED8), brightness: Brightness.dark),
            cardColor: const Color(0xFF101826),
            dividerColor: const Color(0xFF1E293B),
            textTheme: const TextTheme(
              titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              bodyLarge: TextStyle(fontSize: 15),
              bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Color(0xFF101826),
            ),
          ),
          home: AppSplashScreen(api: api, state: state),
        ),
      ),
    );
  }
}
