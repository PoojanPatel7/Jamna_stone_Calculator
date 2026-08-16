import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/localization/app_translations.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final themeIndex = prefs.getInt('theme_mode');
  if (themeIndex != null) {
    themeNotifier.value = ThemeMode.values[themeIndex];
  }
  
  themeNotifier.addListener(() {
    prefs.setInt('theme_mode', themeNotifier.value.index);
  });

  runApp(const SlabCountApp());
}

class SlabCountApp extends StatelessWidget {
  const SlabCountApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppTranslations.currentLocale,
      builder: (context, locale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, ThemeMode currentMode, __) {
            return MaterialApp(
              title: 'Jamna Stone',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blue,
                  brightness: Brightness.light,
                ),
                useMaterial3: true,
                appBarTheme: const AppBarTheme(
                  systemOverlayStyle: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.dark,
                    statusBarBrightness: Brightness.light,
                  ),
                ),
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blue,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
              ),
              themeMode: currentMode,
              home: const SplashScreen(),
            );
          },
        );
      }
    );
  }
}
