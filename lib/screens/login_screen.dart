import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/luxury_background.dart';
import 'home_shell.dart';

/// Login- und Registrierungs-Screen (lokaler Fake-Login).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isRegister = false;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);

    final provider = context.read<UserProvider>();
    final error = _isRegister
        ? await provider.register(
            username: _username.text,
            email: _email.text,
            password: _password.text,
          )
        : await provider.login(
            email: _email.text,
            password: _password.text,
          );

    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFE05A5A),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LuxuryBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('👑', style: TextStyle(fontSize: 64),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      const Text(
                        'DER REICHEN-RECHNER',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isRegister
                            ? 'Erstelle dein Konto für Reiche'
                            : 'Willkommen zurück, edle Person',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Benutzername (nur bei Registrierung)
                      if (_isRegister) ...[
                        TextFormField(
                          controller: _username,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Benutzername',
                            prefixIcon:
                                Icon(Icons.person, color: AppTheme.gold),
                          ),
                          validator: (v) {
                            if (!_isRegister) return null;
                            if (v == null || v.trim().length < 2) {
                              return 'Mindestens 2 Zeichen.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // E-Mail
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'E-Mail',
                          prefixIcon: Icon(Icons.email, color: AppTheme.gold),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Bitte E-Mail eingeben.';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Ungültige E-Mail.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Passwort
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Passwort',
                          prefixIcon:
                              const Icon(Icons.lock, color: AppTheme.gold),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 4) {
                            return 'Mindestens 4 Zeichen.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      ElevatedButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(_isRegister ? 'KONTO ERSTELLEN' : 'ANMELDEN'),
                      ),
                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _isRegister = !_isRegister),
                        child: Text(
                          _isRegister
                              ? 'Schon ein Konto? Jetzt anmelden'
                              : 'Noch kein Konto? Jetzt registrieren',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
