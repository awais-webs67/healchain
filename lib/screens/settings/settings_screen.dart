/// ─────────────────────────────────────────────────────────────────────────────
/// SettingsScreen — App settings with real Firestore integration
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDarkMode;
        final user = context.watch<AuthProvider>().userModel;

        return Scaffold(
          backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
          body: SafeArea(
            child: Column(children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.arrow_back_ios_rounded, size: 18,
                          color: isDark ? AppTheme.textPrimary : AppTheme.textDark),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Settings', style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.textPrimary : AppTheme.textDark)),
                    Text('Manage your preferences', style: TextStyle(fontSize: 12,
                        color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),

              Expanded(child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Appearance
                  _SectionHeader(title: 'Appearance', isDark: isDark),
                  _SettingsTile(
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    title: 'Dark Mode',
                    subtitle: isDark ? 'On' : 'Off',
                    isDark: isDark,
                    trailing: Switch.adaptive(
                      value: themeProvider.isDarkMode,
                      onChanged: (_) => themeProvider.toggleTheme(),
                      activeThumbColor: AppTheme.success,
                      activeTrackColor: AppTheme.success.withValues(alpha: 0.3),
                      inactiveThumbColor: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary,
                      inactiveTrackColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Notifications
                  _SectionHeader(title: 'Notifications', isDark: isDark),
                  _SettingsTile(
                    icon: Icons.notifications_rounded,
                    title: 'Push Notifications',
                    subtitle: 'Emergency blood requests',
                    isDark: isDark,
                    trailing: Switch.adaptive(
                      value: user?.notificationsEnabled ?? true,
                      onChanged: (val) {
                        context.read<AuthProvider>().updateProfile({
                          'notificationsEnabled': val,
                        });
                      },
                      activeThumbColor: AppTheme.success,
                      activeTrackColor: AppTheme.success.withValues(alpha: 0.3),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // About
                  _SectionHeader(title: 'About', isDark: isDark),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About Heal Chain',
                    subtitle: 'Our mission, team, and contact',
                    isDark: isDark,
                    onTap: () => context.push(AppRoutes.about),
                  ),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'How we protect your data',
                    isDark: isDark,
                    onTap: () => context.push(AppRoutes.privacyPolicy),
                  ),
                  _SettingsTile(
                    icon: Icons.code_rounded,
                    title: 'App Version',
                    subtitle: '1.0.0',
                    isDark: isDark,
                  ),

                  const SizedBox(height: 20),

                  // Danger Zone
                  _SectionHeader(title: 'Danger Zone', isDark: isDark),
                  _SettingsTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account and data',
                    iconColor: AppTheme.error,
                    isDark: isDark,
                    onTap: () => _showDeleteDialog(context),
                  ),
                ],
              )),
            ]),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.warning_rounded, color: AppTheme.error, size: 24),
            SizedBox(width: 10),
            Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
          content: const Text(
            'This action cannot be undone. All your data — profile, donations, chats, and notifications — will be permanently deleted.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _deleteAccount(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    try {
      final auth = context.read<AuthProvider>();
      final uid = auth.firebaseUser?.uid;
      if (uid == null) return;

      final db = FirebaseFirestore.instance;

      // 1. Delete all CHATS where user is a participant (+ their messages)
      final chatsAsParticipant = await db.collection('chats')
          .where('participants', arrayContains: uid).get();
      for (var chatDoc in chatsAsParticipant.docs) {
        // Delete all messages in this chat
        final msgs = await chatDoc.reference.collection('messages').get();
        final msgBatch = db.batch();
        for (var msg in msgs.docs) {
          msgBatch.delete(msg.reference);
        }
        await msgBatch.commit();
        // Delete the chat document
        await chatDoc.reference.delete();
      }

      // 2. Delete all BLOOD REQUESTS created by this user
      final requests = await db.collection('blood_requests')
          .where('recipientId', isEqualTo: uid).get();
      for (var doc in requests.docs) {
        await doc.reference.delete();
      }

      // 3. Delete all DONATIONS involving this user (as donor)
      final donationsAsDonor = await db.collection('donations')
          .where('donorId', isEqualTo: uid).get();
      for (var doc in donationsAsDonor.docs) {
        await doc.reference.delete();
      }

      // 4. Delete all NOTIFICATIONS for this user
      final notifs = await db.collection('notifications')
          .where('userId', isEqualTo: uid).get();
      for (var doc in notifs.docs) {
        await doc.reference.delete();
      }

      // 5. Delete all ALERTS for this user
      final alerts = await db.collection('alerts')
          .where('userId', isEqualTo: uid).get();
      for (var doc in alerts.docs) {
        await doc.reference.delete();
      }

      // 6. Delete user document from Firestore
      await db.collection('users').doc(uid).delete();

      // 7. Delete Firebase Auth user
      try {
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (_) {
        // May fail if session is old — sign out anyway
      }

      // 8. Sign out
      await auth.signOut();

      if (context.mounted) {
        context.go(AppRoutes.login);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader({required this.title, this.isDark = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryRed,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool isDark;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryRed).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor ?? AppTheme.primaryRed, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                color: isDark ? AppTheme.textPrimary : AppTheme.textDark)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
            ],
          ])),
          if (trailing != null) trailing!
          else if (onTap != null) Icon(Icons.chevron_right_rounded, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary, size: 22),
        ]),
      ),
    );
  }
}

