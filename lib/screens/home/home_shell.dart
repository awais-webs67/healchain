/// ─────────────────────────────────────────────────────────────────────────────
/// HomeShell — Bottom navigation shell with role-based tabs + floating chatbot
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';

class HomeShell extends StatefulWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabGlowCtrl;

  @override
  void initState() {
    super.initState();
    _fabGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _fabGlowCtrl.dispose();
    super.dispose();
  }

  // Donor tabs
  static const _donorNav = [
    (icon: Icons.home_rounded, label: 'Home', route: AppRoutes.home),
    (icon: Icons.water_drop_rounded, label: 'Requests', route: AppRoutes.bloodRequests),
    (icon: Icons.chat_rounded, label: 'Chat', route: AppRoutes.donorChat),
    (icon: Icons.notifications_rounded, label: 'Alerts', route: AppRoutes.notifications),
    (icon: Icons.person_rounded, label: 'Profile', route: AppRoutes.profile),
  ];

  // Recipient tabs
  static const _recipientNav = [
    (icon: Icons.home_rounded, label: 'Home', route: AppRoutes.home),
    (icon: Icons.search_rounded, label: 'Search', route: AppRoutes.donorSearch),
    (icon: Icons.chat_rounded, label: 'Chat', route: AppRoutes.donorChat),
    (icon: Icons.notifications_rounded, label: 'Alerts', route: AppRoutes.notifications),
    (icon: Icons.person_rounded, label: 'Profile', route: AppRoutes.profile),
  ];

  List<({IconData icon, String label, String route})> _getNavItems() {
    final role = context.read<AuthProvider>().userModel?.role ?? 'recipient';
    return role == 'donor' ? _donorNav : _recipientNav;
  }

  int _calcIndex(List<({IconData icon, String label, String route})> items) {
    final loc = GoRouterState.of(context).uri.path;
    for (int i = 0; i < items.length; i++) {
      if (loc == items[i].route) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navItems = _getNavItems();
    final currentIndex = _calcIndex(navItems);

    return Scaffold(
      body: widget.child,

      // ── Floating Chatbot Button ──────────────────────────────────────
      floatingActionButton: AnimatedBuilder(
        animation: _fabGlowCtrl,
        builder: (_, _) => Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryRed.withValues(
                    alpha: 0.25 + _fabGlowCtrl.value * 0.15),
                blurRadius: 16 + _fabGlowCtrl.value * 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            heroTag: 'chatbot_fab',
            onPressed: () => context.push(AppRoutes.chatbot),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Ink(
              decoration: const BoxDecoration(
                gradient: AppTheme.heroGradient,
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                child: const Icon(Icons.smart_toy_rounded,
                    color: Colors.white, size: 26),
              ),
            ),
          ),
        ),
      ),

      // ── Bottom Navigation ───────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 0.5)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (i) {
                final item = navItems[i];
                final isActive = i == currentIndex;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (i == currentIndex) return;
                      context.go(navItems[i].route);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.primaryRed.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(item.icon, size: 24,
                            color: isActive ? AppTheme.primaryRed : (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
                        const SizedBox(height: 4),
                        Text(item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                              color: isActive ? AppTheme.primaryRed : (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
                            )),
                      ]),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
