import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/calculator_provider.dart';
import 'providers/user_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()..init()),
        ChangeNotifierProvider(create: (_) => CalculatorProvider()),
      ],
      child: const RichCalculatorApp(),
    ),
  );
}

class RichCalculatorApp extends StatelessWidget {
  const RichCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Der Reichen-Rechner',
      theme: AppTheme.darkGoldTheme,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
