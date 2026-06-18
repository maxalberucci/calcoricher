import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/calculator_provider.dart';
import 'providers/user_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hochformat erzwingen — Layout bleibt so auf jedem Gerät sauber.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const RichCalculatorApp());
}

/// Wurzel-Widget. Stellt die Provider bereit, damit die App selbst-enthaltend
/// und testbar ist.
class RichCalculatorApp extends StatelessWidget {
  const RichCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()..init()),
        ChangeNotifierProvider(create: (_) => CalculatorProvider()),
      ],
      child: MaterialApp(
        title: 'Calcoricher',
        theme: AppTheme.darkGoldTheme,
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
