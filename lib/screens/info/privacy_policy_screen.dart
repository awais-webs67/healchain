/// ─────────────────────────────────────────────────────────────────────────────
/// PrivacyPolicyScreen — Premium privacy policy page for Heal Chain
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1117), Color(0xFF1A1F2E), Color(0xFF1E293B)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.shield_rounded, color: AppTheme.primaryRed, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Privacy Policy', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text('Last updated: March 2026', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                      ])),
                    ]),
                  ]),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Quick Summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: isDark ? 0.08 : 0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.2)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.info_rounded, color: AppTheme.primaryRed, size: 18),
                      const SizedBox(width: 8),
                      const Text('Quick Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryRed)),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                      'We collect only what\'s needed to connect donors and recipients. Your data is encrypted, never sold, '
                      'and you control what you share. Emergency notifications use your location only when you allow it.',
                      style: TextStyle(fontSize: 12.5, height: 1.6, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                _section(isDark, '1', 'Information We Collect', Icons.storage_rounded, const Color(0xFF1E88E5), [
                  _bullet('Personal Details', 'Name, email, phone number, blood group, and age provided during registration'),
                  _bullet('Health Information', 'Blood type, donation history, and health metrics you voluntarily enter'),
                  _bullet('Location Data', 'GPS coordinates when you enable location services (for donor matching)'),
                  _bullet('Device Info', 'Push notification tokens for emergency alerts delivery'),
                ]),

                _section(isDark, '2', 'How We Use Your Data', Icons.analytics_rounded, const Color(0xFF43A047), [
                  _bullet('Donor Matching', 'To connect recipients with compatible, nearby donors during emergencies'),
                  _bullet('Notifications', 'To send emergency blood request alerts and donation status updates'),
                  _bullet('Profile', 'To display your donor/recipient profile to relevant users'),
                  _bullet('Improvement', 'To improve our matching algorithms and app experience (anonymized)'),
                ]),

                _section(isDark, '3', 'Data Protection', Icons.lock_rounded, const Color(0xFF8B5CF6), [
                  _bullet('Encryption', 'All data is transmitted securely using TLS encryption'),
                  _bullet('Firebase Security', 'Data stored in Firebase with strict security rules'),
                  _bullet('Access Control', 'Only authenticated users can access the platform'),
                  _bullet('No Selling', 'We never sell, rent, or share your personal data with third parties'),
                ]),

                _section(isDark, '4', 'Your Rights', Icons.gavel_rounded, const Color(0xFFF9A825), [
                  _bullet('Access', 'View all your stored personal data from your profile screen'),
                  _bullet('Edit', 'Update or correct your personal information at any time'),
                  _bullet('Delete', 'Permanently delete your account and all associated data'),
                  _bullet('Opt-Out', 'Disable push notifications or location sharing from settings'),
                ]),

                _section(isDark, '5', 'Data Retention', Icons.schedule_rounded, AppTheme.primaryRed, [
                  _bullet('Active Accounts', 'Data retained while your account is active'),
                  _bullet('Deletion', 'All data deleted within 30 days of account deletion request'),
                  _bullet('Donation Records', 'Anonymized donation statistics may be retained for medical research'),
                ]),

                _section(isDark, '6', 'Third-Party Services', Icons.public_rounded, AppTheme.info, [
                  _bullet('Firebase', 'Authentication, database, and push notifications by Google Firebase'),
                  _bullet('Google Maps', 'Location services and reverse geocoding'),
                  _bullet('AI Services', 'AI-powered features using encrypted API calls (no personal data sent)'),
                ]),

                const SizedBox(height: 24),

                // Contact
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Questions?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'If you have questions about this policy or your data, contact us at:',
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.email_rounded, size: 16, color: AppTheme.primaryRed),
                      const SizedBox(width: 8),
                      const Text('privacy@healchain.app', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryRed)),
                    ]),
                  ]),
                ),

                const SizedBox(height: 20),
                Center(child: Text('© 2026 Heal Chain. All rights reserved.', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary.withValues(alpha: 0.5) : AppTheme.textDarkSecondary.withValues(alpha: 0.5)))),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(bool isDark, String num, String title, IconData icon, Color color, List<Widget> bullets) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(num, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color))),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          ]),
        ),
        // Bullets
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: bullets),
        ),
      ]),
    );
  }

  Widget _bullet(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 5, height: 5,
          decoration: const BoxDecoration(color: AppTheme.primaryRed, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12.5, height: 1.5),
            children: [
              TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: desc, style: TextStyle(color: AppTheme.textTertiary)),
            ],
          ),
        )),
      ]),
    );
  }
}
