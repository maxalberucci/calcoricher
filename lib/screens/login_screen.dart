import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../legal/legal_meta.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gold_text.dart';
import '../widgets/luxury_background.dart';
import 'admin_screen.dart';
import 'home_shell.dart';
import 'legal/legal_document_screen.dart';

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
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isRegister && !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte akzeptiere AGB und Datenschutzerklärung.'),
          backgroundColor: Color(0xFFE05A5A),
        ),
      );
      return;
    }
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
      MaterialPageRoute(
        builder: (_) =>
            provider.isAdmin ? const AdminScreen() : const HomeShell(),
      ),
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
                      const Text('👑',
                          style: TextStyle(fontSize: 64),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      GoldText(
                        'CALCORICHER',
                        textAlign: TextAlign.center,
                        glow: true,
                        style: AppTheme.serif(const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        )),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isRegister
                            ? 'Create your account for the rich'
                            : 'Welcome back, noble one',
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
                            labelText: 'Username',
                            prefixIcon:
                                Icon(Icons.person, color: AppTheme.gold),
                          ),
                          validator: (v) {
                            if (!_isRegister) return null;
                            if (v == null || v.trim().length < 2) {
                              return 'At least 2 characters.';
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
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email, color: AppTheme.gold),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your email.';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Invalid email.';
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
                          labelText: 'Password',
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
                            return 'At least 4 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Pflicht-Zustimmung bei der Registrierung.
                      if (_isRegister) ...[
                        _TermsAcceptance(
                          value: _acceptedTerms,
                          onChanged: (v) =>
                              setState(() => _acceptedTerms = v ?? false),
                        ),
                        const SizedBox(height: 16),
                      ],

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
                            : Text(_isRegister ? 'CREATE ACCOUNT' : 'SIGN IN'),
                      ),
                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _isRegister = !_isRegister),
                        child: Text(
                          _isRegister
                              ? 'Already have an account? Sign in'
                              : 'No account yet? Register now',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _LegalFooter(),
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

/// Pflicht-Checkbox bei der Registrierung mit antippbaren Links zu AGB und
/// Datenschutzerklärung.
class _TermsAcceptance extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _TermsAcceptance({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.gold,
            checkColor: Colors.black,
            side: const BorderSide(color: AppTheme.goldDark),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'Ich akzeptiere die '),
                _docSpan(context, 'AGB', LegalMeta.terms),
                const TextSpan(text: ' und die '),
                _docSpan(context, 'Datenschutzerklärung', LegalMeta.privacy),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Dezente Fußzeile mit Links zu allen Rechtstexten.
class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _footerLink(context, LegalMeta.privacy),
        const _Dot(),
        _footerLink(context, LegalMeta.terms),
        const _Dot(),
        _footerLink(context, LegalMeta.cookies),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => const Text(
        ' · ',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      );
}

Widget _footerLink(BuildContext context, LegalDocument doc) {
  return GestureDetector(
    onTap: () => LegalDocumentScreen.open(context, doc),
    child: Text(
      doc.title,
      style: const TextStyle(
        color: AppTheme.gold,
        fontSize: 12,
        decoration: TextDecoration.underline,
        decorationColor: AppTheme.goldDark,
      ),
    ),
  );
}

InlineSpan _docSpan(BuildContext context, String label, LegalDocument doc) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: GestureDetector(
      onTap: () => LegalDocumentScreen.open(context, doc),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.gold,
          fontSize: 12.5,
          decoration: TextDecoration.underline,
          decorationColor: AppTheme.goldDark,
        ),
      ),
    ),
  );
}
