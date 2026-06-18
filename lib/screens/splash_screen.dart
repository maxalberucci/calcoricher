import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/luxury_background.dart';
import 'home_shell.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );

    _ctrl.forward();

    _navigate();
  }

  Future<void> _navigate() async {
    // Mindestlaufzeit des Splash und Warten bis Daten geladen sind.
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final provider = context.read<UserProvider>();
    while (!provider.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    final target =
        provider.hasUser ? const HomeShell() : const LoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => target,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LuxuryBackground(
        child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Crown icon
                  const Text('👑', style: TextStyle(fontSize: 72)),
                  const SizedBox(height: 24),
                  // App name
                  const Text(
                    'DER REICHEN-\nRECHNER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Gold divider
                  Container(
                    height: 1,
                    width: 200,
                    color: AppTheme.goldDark,
                  ),
                  const SizedBox(height: 16),
                  // Tagline
                  const Text(
                    'Willkommen im teuersten Rechner der Welt',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      letterSpacing: 1.2,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Rechnen ist für Arme.\nZahlen ist für Reiche.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.goldDark,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
