import 'package:flutter/material.dart';
import 'tabs/admin_stats_tab.dart';
import 'tabs/admin_users_tab.dart';
import 'tabs/admin_requests_tab.dart';
import 'tabs/admin_settings_tab.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _i = 0;

  static const _violet = Color(0xFF7C4DFF);

  final _tabs = const [
    AdminStatsTab(),
    AdminUsersTab(),
    AdminRequestsTab(),
    AdminSettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C1030) : Colors.white;
    final inactiveColor = isDark ? const Color(0xFF4A5178) : const Color(0xFF9498B0);

    return Scaffold(
      body: IndexedStack(index: _i, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF1C2548) : const Color(0xFFE2E4EF))),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                _navItem(0, Icons.dashboard_rounded, 'Dashboard', inactiveColor),
                _navItem(1, Icons.people_alt_rounded, 'Users', inactiveColor),
                _navItem(2, Icons.bloodtype_rounded, 'Requests', inactiveColor),
                _navItem(3, Icons.settings_rounded, 'Settings', inactiveColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int idx, IconData icon, String label, Color inactiveColor) {
    final active = _i == idx;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _i = idx),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: active ? _violet : inactiveColor),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? _violet : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
