import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../payments/payment_config.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/luxury_background.dart';
import 'login_screen.dart';

/// Auswählbare Avatare (einfach, ohne Bild-Picker-Abhängigkeit).
const List<String> _kAvatars = [
  '👑', '💎', '🤵', '👸', '🏆', '💰', '🦁', '🚀', '🎩', '⭐'
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.text = context.read<UserProvider>().currentUser?.username ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await context.read<UserProvider>().updateProfile(username: _controller.text);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gespeichert, ${_controller.text.trim()}! 👑'),
        backgroundColor: AppTheme.goldDark,
      ),
    );
  }

  Future<void> _pickAvatar(String avatar) async {
    await context.read<UserProvider>().updateProfile(avatar: avatar);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardHigh,
        title: const Text('Abmelden?',
            style: TextStyle(color: AppTheme.gold)),
        content: const Text(
          'Deine Coins bleiben gespeichert und warten auf deine Rückkehr.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abmelden',
                style: TextStyle(color: Color(0xFFE05A5A))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<UserProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('MEIN PROFIL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.gold),
            tooltip: 'Abmelden',
            onPressed: _logout,
          ),
        ],
      ),
      body: LuxuryBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: user == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _AvatarCircle(avatar: user.avatar),
                          const SizedBox(height: 16),
                          Text(
                            user.username,
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            user.email,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Statistik
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                    label: 'Ausgegeben',
                                    value: PaymentConfig.format(
                                        user.totalSpentMinor),
                                    icon: '💸'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                    label: 'Resultate',
                                    value: '${user.unlockedResultsCount}',
                                    icon: '🔓'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _NextPriceCard(
                              price: PaymentConfig.format(
                                  user.currentResultPriceMinor)),
                          const SizedBox(height: 28),

                          // Avatar-Auswahl
                          const _SectionLabel('AVATAR WÄHLEN'),
                          const SizedBox(height: 10),
                          _AvatarPicker(
                            selected: user.avatar,
                            onPick: _pickAvatar,
                          ),
                          const SizedBox(height: 24),

                          // Name bearbeiten
                          const _SectionLabel('BENUTZERNAME'),
                          const SizedBox(height: 8),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _controller,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 18),
                                  decoration: const InputDecoration(
                                    hintText: 'Dein Name',
                                    prefixIcon: Icon(Icons.person,
                                        color: AppTheme.gold),
                                  ),
                                  textCapitalization:
                                      TextCapitalization.words,
                                  validator: (v) {
                                    if (v == null || v.trim().length < 2) {
                                      return 'Mindestens 2 Zeichen.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton(
                                  onPressed: _saving ? null : _save,
                                  child: _saving
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const Text('SPEICHERN'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('ABMELDEN'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE05A5A),
                              side: const BorderSide(color: Color(0xFFE05A5A)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
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

class _AvatarCircle extends StatelessWidget {
  final String avatar;
  const _AvatarCircle({required this.avatar});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.cardHigh,
        border: Border.all(color: AppTheme.gold, width: 2),
        boxShadow: AppTheme.goldGlow(opacity: 0.3, blur: 24),
      ),
      child: Center(child: Text(avatar, style: const TextStyle(fontSize: 52))),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onPick;

  const _AvatarPicker({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _kAvatars.map((a) {
        final isSelected = a == selected;
        return GestureDetector(
          onTap: () => onPick(a),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.gold.withValues(alpha: 0.15)
                  : AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.gold : AppTheme.divider,
                width: isSelected ? 2 : 0.5,
              ),
            ),
            child: Center(child: Text(a, style: const TextStyle(fontSize: 26))),
          ),
        );
      }).toList(),
    );
  }
}

class _NextPriceCard extends StatelessWidget {
  final String price;
  const _NextPriceCard({required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldDark, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, color: AppTheme.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preis für das nächste Resultat',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
                Text(
                  price,
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.gold,
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldDark, width: 0.5),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
