import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../gamification/achievements.dart';
import '../gamification/ranks.dart';
import '../models/user_model.dart';
import '../payments/payment_config.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/luxury_background.dart';
import '../widgets/luxury_button.dart';
import '../widgets/owner_comment_tile.dart';
import '../widgets/payment_sheet.dart';
import '../widgets/profile_showcase.dart';
import '../widgets/purchase_celebration.dart';
import '../widgets/user_avatar.dart';
import 'admin_screen.dart';
import 'login_screen.dart';
import 'public_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _controller = TextEditingController();
  final _titleController = TextEditingController();
  final _bioController = TextEditingController();
  final _linksController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _accentIndex = 0;
  bool _saving = false;
  bool _savingDetails = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().currentUser;
    _controller.text = user?.username ?? '';
    _titleController.text = user?.profileTitle ?? '';
    _bioController.text = user?.bio ?? '';
    _linksController.text = user?.links.join('\n') ?? '';
    _accentIndex = user?.profileAccentIndex ?? 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _bioController.dispose();
    _linksController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context);
    final userProv = context.read<UserProvider>();
    final user = userProv.currentUser;
    if (user == null) return;

    final newName = _controller.text.trim();
    if (newName == user.username) {
      messenger.showSnackBar(
        const SnackBar(content: Text('That is already your name.')),
      );
      return;
    }

    // Namensänderung kostet echtes Geld.
    const price = PaymentConfig.usernameChangePriceMinor;
    final paid = await showPaymentSheet(
      context,
      amountMinor: price,
      description: 'Rename to "$newName"',
    );
    if (!mounted || !paid) return;

    setState(() => _saving = true);
    await userProv.changeUsername(newName, price);
    if (!mounted) return;
    setState(() => _saving = false);

    await showPurchaseCelebration(context, amountMinor: price);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Renamed to $newName! 👑'),
        backgroundColor: AppTheme.goldDark,
      ),
    );
  }

  Future<void> _saveProfileDetails() async {
    final messenger = ScaffoldMessenger.of(context);
    // Aufteilen genügt – der Provider normalisiert & validiert die Links
    // (nur sichere http(s)-Links werden gespeichert).
    final links = _linksController.text.split(RegExp(r'[\n,]')).toList();

    setState(() => _savingDetails = true);
    await context.read<UserProvider>().updateProfileDetails(
          profileTitle: _titleController.text,
          bio: _bioController.text,
          links: links,
          profileAccentIndex: _accentIndex,
        );
    if (!mounted) return;
    setState(() => _savingDetails = false);

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Profile updated.'),
        backgroundColor: AppTheme.goldDark,
      ),
    );
  }

  /// Nimmt ein Foto auf bzw. wählt eines aus der Galerie, speichert es dauerhaft
  /// im App-Verzeichnis und setzt es als Profilbild.
  Future<void> _pickImage(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    final userProv = context.read<UserProvider>();
    final user = userProv.currentUser;
    if (user == null) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;

      // In ein stabiles Verzeichnis kopieren (Original-Pfad ist oft temporär).
      final dir = await getApplicationDocumentsDirectory();
      final dest =
          '${dir.path}/avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      await picked.saveTo(dest);

      await userProv.updateProfilePhoto(dest);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Camera is not available on this device.'
                : 'Could not load the image.',
          ),
          backgroundColor: const Color(0xFFE05A5A),
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardHigh,
        title: const Text('Sign out?',
            style: TextStyle(color: AppTheme.gold)),
        content: const Text(
          'Your spending and history stay saved and await your return.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out',
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
    final provider = context.watch<UserProvider>();
    final user = provider.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('MY PROFILE'),
        actions: [
          if (provider.isAdmin)
            _AdminButton(reportCount: provider.reportedCommentCount),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.gold),
            tooltip: 'Sign out',
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
                          UserAvatar(
                            name: user.username,
                            imagePath: user.avatarPath,
                            size: 110,
                            bordered: true,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PhotoButton(
                                icon: Icons.photo_camera,
                                label: 'Camera',
                                onTap: () => _pickImage(ImageSource.camera),
                              ),
                              const SizedBox(width: 12),
                              _PhotoButton(
                                icon: Icons.photo_library,
                                label: 'Gallery',
                                onTap: () => _pickImage(ImageSource.gallery),
                              ),
                            ],
                          ),
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
                          const SizedBox(height: 20),
                          ProfileShowcase(user: user),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              final rank = context
                                  .read<UserProvider>()
                                  .leaderboardRankOf(user.id);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PublicProfileScreen(
                                    user: user,
                                    leaderboardRank: rank,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.visibility),
                            label: const Text('VIEW PUBLIC PROFILE'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.gold,
                              side: const BorderSide(color: AppTheme.goldDark),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Rang nach ausgegebenem Geld
                          _RankCard(spentMinor: user.totalSpentMinor),
                          const SizedBox(height: 16),

                          // Statistik
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                    label: 'Spent',
                                    value: PaymentConfig.format(
                                        user.totalSpentMinor),
                                    icon: '💸'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                    label: 'Results',
                                    value: '${user.unlockedResultsCount}',
                                    icon: '🔓'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                    label: 'Top unlock',
                                    value: PaymentConfig.format(
                                        user.highestUnlockMinor),
                                    icon: '🚀'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _NextPriceCard(
                              price: PaymentConfig.format(
                                  user.currentResultPriceMinor)),
                          const SizedBox(height: 28),

                          // Auszeichnungen
                          _AchievementsSection(user: user),
                          const SizedBox(height: 28),

                          // Kommentare auf dem eigenen Profil (mit Antwort)
                          _ProfileCommentsCard(user: user),
                          const SizedBox(height: 28),

                          // Profil personalisieren
                          const _SectionLabel('PROFILE STYLE'),
                          const SizedBox(height: 10),
                          _ProfileDetailsEditor(
                            titleController: _titleController,
                            bioController: _bioController,
                            linksController: _linksController,
                            accentIndex: _accentIndex,
                            saving: _savingDetails,
                            onAccentChanged: (index) {
                              setState(() => _accentIndex = index);
                            },
                            onSave: _saveProfileDetails,
                          ),
                          const SizedBox(height: 24),

                          // Name bearbeiten
                          const _SectionLabel('USERNAME'),
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
                                    hintText: 'Your name',
                                    prefixIcon: Icon(Icons.person,
                                        color: AppTheme.gold),
                                  ),
                                  textCapitalization:
                                      TextCapitalization.words,
                                  validator: (v) {
                                    if (v == null || v.trim().length < 2) {
                                      return 'At least 2 characters.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                        size: 14,
                                        color: AppTheme.textSecondary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Changing your name costs ${PaymentConfig.format(PaymentConfig.usernameChangePriceMinor)}.',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                LuxuryButton(
                                  onPressed: _save,
                                  busy: _saving,
                                  icon: Icons.workspace_premium,
                                  label:
                                      'RENAME  (${PaymentConfig.format(PaymentConfig.usernameChangePriceMinor)})',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(color: AppTheme.divider, height: 1),
                          const SizedBox(height: 16),
                          _SignOutButton(onTap: _logout),
                          const SizedBox(height: 8),
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

/// AppBar-Knopf zum Report-Tool (nur Admins), mit Badge für offene Meldungen.
class _AdminButton extends StatelessWidget {
  final int reportCount;
  const _AdminButton({required this.reportCount});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Report center',
      icon: Badge(
        isLabelVisible: reportCount > 0,
        backgroundColor: const Color(0xFFE05A5A),
        label: Text('$reportCount'),
        child: const Icon(Icons.shield_outlined, color: AppTheme.gold),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminScreen()),
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PhotoButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.gold,
        side: const BorderSide(color: AppTheme.goldDark),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _ProfileDetailsEditor extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController bioController;
  final TextEditingController linksController;
  final int accentIndex;
  final bool saving;
  final ValueChanged<int> onAccentChanged;
  final VoidCallback onSave;

  const _ProfileDetailsEditor({
    required this.titleController,
    required this.bioController,
    required this.linksController,
    required this.accentIndex,
    required this.saving,
    required this.onAccentChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileAccentPicker(selected: accentIndex, onChanged: onAccentChanged),
        const SizedBox(height: 12),
        TextField(
          controller: titleController,
          maxLength: 42,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'e.g. Diamond Division Investor',
            labelText: 'Profile title',
            prefixIcon: Icon(Icons.workspace_premium, color: AppTheme.gold),
            counterStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: bioController,
          minLines: 3,
          maxLines: 5,
          maxLength: 220,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Short text about you',
            labelText: 'Bio',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.notes, color: AppTheme.gold),
            counterStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: linksController,
          minLines: 2,
          maxLines: 4,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'website.com\ninstagram.com/name',
            labelText: 'Links',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.link, color: AppTheme.gold),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Icon(Icons.save),
          label: const Text('SAVE PROFILE'),
        ),
      ],
    );
  }
}

/// Vollbreiter, edel-dezenter Abmelde-Button (rot getönt, mit Ripple).
class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});

  static const Color _red = Color(0xFFE05A5A);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: _red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _red.withValues(alpha: 0.45)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: _red, size: 18),
                SizedBox(width: 10),
                Text(
                  'SIGN OUT',
                  style: TextStyle(
                    color: _red,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aktueller Rang mit Fortschrittsbalken zum nächsten Rang.
class _RankCard extends StatelessWidget {
  final int spentMinor;
  const _RankCard({required this.spentMinor});

  @override
  Widget build(BuildContext context) {
    final rank = rankForSpent(spentMinor);
    final next = nextRankAfter(rank);
    final progress = rankProgress(spentMinor);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            rank.color.withValues(alpha: 0.18),
            AppTheme.card,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rank.color.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rank.color.withValues(alpha: 0.15),
                  border: Border.all(color: rank.color),
                ),
                child: Icon(rank.icon, color: rank.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('YOUR RANK',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        )),
                    Text(
                      rank.name,
                      style: TextStyle(
                        color: rank.color,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.surface,
              valueColor: AlwaysStoppedAnimation(rank.color),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              next == null
                  ? 'Maximum rank reached 👑'
                  : '${PaymentConfig.format(next.thresholdMinor - spentMinor)} to ${next.name}',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Übersicht der Auszeichnungen (frei/gesperrt) mit Fortschritt.
class _AchievementsSection extends StatelessWidget {
  final UserModel user;
  const _AchievementsSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionLabel('ACHIEVEMENTS'),
            const Spacer(),
            Text(
              '${unlockedCount(user)} / ${kAchievements.length}',
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kAchievements
              .map((a) => _AchievementBadge(achievement: a, user: user))
              .toList(),
        ),
      ],
    );
  }
}

/// Liste der auf dem eigenen Profil eingegangenen Kommentare inkl. Antwort-Feld.
class _ProfileCommentsCard extends StatelessWidget {
  final UserModel user;
  const _ProfileCommentsCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final comments = user.profileComments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionLabel('COMMENTS'),
            const Spacer(),
            Text(
              '${comments.length}',
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (comments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: const Text(
              'No comments on your profile yet.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          )
        else
          for (final comment in comments)
            Padding(
              key: ValueKey(comment.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: OwnerCommentTile(comment: comment, ownerId: user.id),
            ),
      ],
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final UserModel user;

  const _AchievementBadge({required this.achievement, required this.user});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked(user);
    final label = achievement.progressLabel(user);
    final color = unlocked ? AppTheme.gold : AppTheme.textSecondary;

    return Tooltip(
      message: achievement.description,
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: unlocked
              ? AppTheme.gold.withValues(alpha: 0.10)
              : AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unlocked ? AppTheme.gold : AppTheme.divider,
            width: unlocked ? 1 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              unlocked ? achievement.icon : Icons.lock_outline,
              color: color,
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
            if (!unlocked && label != null) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 9),
              ),
            ],
          ],
        ),
      ),
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
                  'Price for the next result',
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
