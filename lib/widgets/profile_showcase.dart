import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../gamification/ranks.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

const List<ProfileAccent> kProfileAccents = [
  ProfileAccent('Gold', AppTheme.gold, AppTheme.goldLight),
  ProfileAccent('Ruby', Color(0xFFE05A5A), Color(0xFFFF9A9A)),
  ProfileAccent('Emerald', Color(0xFF46D39A), Color(0xFFA7F3D0)),
  ProfileAccent('Sapphire', Color(0xFF5AA9FF), Color(0xFFB9D9FF)),
  ProfileAccent('Violet', Color(0xFFB278FF), Color(0xFFE5C7FF)),
];

class ProfileAccent {
  final String name;
  final Color color;
  final Color light;

  const ProfileAccent(this.name, this.color, this.light);
}

class ProfileShowcase extends StatelessWidget {
  final UserModel user;
  final bool showEmptyHint;

  const ProfileShowcase({
    super.key,
    required this.user,
    this.showEmptyHint = true,
  });

  @override
  Widget build(BuildContext context) {
    final accentIndex =
        user.profileAccentIndex.clamp(0, kProfileAccents.length - 1);
    final accent = kProfileAccents[accentIndex];
    final title = user.profileTitle.trim();
    final bio = user.bio.trim();
    final hasDetails =
        title.isNotEmpty || bio.isNotEmpty || user.links.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.color.withValues(alpha: 0.22),
            AppTheme.card,
            AppTheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.color.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: accent.color.withValues(alpha: 0.18),
            blurRadius: 26,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(
                emoji: user.avatar,
                imagePath: user.avatarPath,
                size: 58,
                bordered: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent.light,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      title.isEmpty
                          ? rankForSpent(user.totalSpentMinor).name
                          : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              bio,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ] else if (showEmptyHint && !hasDetails) ...[
            const SizedBox(height: 14),
            const Text(
              'Add a title, text and links to make this profile stand out.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          if (user.links.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.links
                  .map((link) => _ProfileLinkChip(link: link, accent: accent))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class ProfileAccentPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const ProfileAccentPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(kProfileAccents.length, (index) {
        final accent = kProfileAccents[index];
        final isSelected = selected == index;
        return Tooltip(
          message: accent.name,
          child: InkWell(
            onTap: () => onChanged(index),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.color.withValues(alpha: 0.18),
                border: Border.all(
                  color: isSelected ? accent.light : accent.color,
                  width: isSelected ? 3 : 1,
                ),
              ),
              child: Center(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [accent.light, accent.color],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ProfileLinkChip extends StatelessWidget {
  final String link;
  final ProfileAccent accent;

  const _ProfileLinkChip({required this.link, required this.accent});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this link.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = link
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');

    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: accent.color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, color: accent.light, size: 15),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent.light,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
