import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'calculator_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/comment_notifications.dart';

/// Main scaffold with bottom navigation between the three main sections.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _profileIndex = 2;
  int _selectedIndex = 0;

  static const _screens = [
    CalculatorScreen(),
    LeaderboardScreen(),
    ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == _profileIndex) _maybeShowNewComments();
  }

  /// Öffnet beim Wechsel auf den Profil-Tab ein Popup mit neuen Kommentaren und
  /// Antworten und setzt anschließend die Badges zurück.
  void _maybeShowNewComments() {
    final provider = context.read<UserProvider>();
    final user = provider.currentUser;
    if (user == null) return;
    final newComments = user.unreadCommentCount;
    final newReplies = user.unreadReplyCount;
    if (newComments <= 0 && newReplies <= 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showCommentNotifications(
        context,
        ownerId: user.id,
        newComments: newComments,
        newReplies: newReplies,
      );
      await provider.markProfileCommentsSeen();
      await provider.markRepliesSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final unreadTotal = provider.unreadCommentCount + provider.unreadReplyCount;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.calculate_outlined),
              activeIcon: Icon(Icons.calculate),
              label: 'Calculator',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard_outlined),
              activeIcon: Icon(Icons.leaderboard),
              label: 'Leaderboard',
            ),
            BottomNavigationBarItem(
              icon: _ProfileTabIcon(
                icon: Icons.person_outline,
                badgeCount: unreadTotal,
              ),
              activeIcon: _ProfileTabIcon(
                icon: Icons.person,
                badgeCount: unreadTotal,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// Profil-Icon mit kleinem Benachrichtigungs-Badge für neue Kommentare.
class _ProfileTabIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;

  const _ProfileTabIcon({required this.icon, required this.badgeCount});

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: badgeCount > 0,
      backgroundColor: AppTheme.gold,
      textColor: Colors.black,
      label: Text(
        badgeCount > 99 ? '99+' : '$badgeCount',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      child: Icon(icon),
    );
  }
}
