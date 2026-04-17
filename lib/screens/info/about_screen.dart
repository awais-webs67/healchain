/// ─────────────────────────────────────────────────────────────────────────────
/// AboutScreen — Premium about page for Heal Chain
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero gradient header
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B0000), AppTheme.primaryRedDark, Color(0xFFD32F2F)],
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
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Logo
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            decoration: BoxDecoration(gradient: AppTheme.heroGradient, borderRadius: BorderRadius.circular(20)),
                            child: const Icon(Icons.bloodtype_rounded, color: Colors.white, size: 36),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    RichText(text: const TextSpan(children: [
                      TextSpan(text: 'Heal ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: Colors.white, letterSpacing: 1)),
                      TextSpan(text: 'Chain', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                    ])),
                    const SizedBox(height: 6),
                    Text('Every Drop Counts', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 2, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('Version 1.0.0', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
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
                const SizedBox(height: 8),

                // Mission
                _sectionTitle('Our Mission'),
                _Card(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.favorite_rounded, color: AppTheme.primaryRed, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(child: Text('Connecting Lives, One Drop at a Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 14),
                  Text(
                    'Heal Chain is a mobile platform designed to bridge the gap between blood donors and recipients in real-time. '
                    'We believe no life should be lost due to a shortage of blood. Our mission is to make blood donation '
                    'accessible, transparent, and efficient — saving lives through the power of technology and community.',
                    style: TextStyle(fontSize: 13, height: 1.6, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
                  ),
                ])),

                const SizedBox(height: 20),

                // What We Do
                _sectionTitle('What We Do'),
                _featureItem(isDark, Icons.emergency_rounded, AppTheme.error, 'Emergency Alerts',
                    'Instant push notifications for urgent blood requests with real-time matching'),
                _featureItem(isDark, Icons.chat_rounded, const Color(0xFF1E88E5), 'Real-Time Chat',
                    'Direct communication between donors and recipients for seamless coordination'),
                _featureItem(isDark, Icons.location_on_rounded, const Color(0xFF43A047), 'Location Tracking',
                    'GPS-based donor matching to find the nearest available donor quickly'),
                _featureItem(isDark, Icons.emoji_events_rounded, const Color(0xFFF9A825), 'Donor Rewards',
                    'Points and recognition system to motivate and appreciate blood donors'),
                _featureItem(isDark, Icons.shield_rounded, const Color(0xFF8B5CF6), 'Safe & Verified',
                    'All donations are tracked and verified for transparency and safety'),

                const SizedBox(height: 20),

                // Impact
                _sectionTitle('Our Impact'),
                _Card(isDark: isDark, child: Row(children: [
                  _impactStat(isDark, '💉', 'Real-Time', 'Matching'),
                  Container(width: 1, height: 40, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  _impactStat(isDark, '🩸', '100%', 'Free'),
                  Container(width: 1, height: 40, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  _impactStat(isDark, '🌍', 'Open', 'To All'),
                ])),

                const SizedBox(height: 20),

                // Contact
                _sectionTitle('Contact Us'),
                _Card(isDark: isDark, child: Column(children: [
                  _contactRow(Icons.email_rounded, 'support@healchain.app', isDark),
                  const Divider(height: 20),
                  _contactRow(Icons.language_rounded, 'www.healchain.app', isDark),
                  const Divider(height: 20),
                  _contactRow(Icons.phone_rounded, '+92-XXX-XXXXXXX', isDark),
                ])),

                const SizedBox(height: 20),

                // Footer
                Center(child: Column(children: [
                  Text('Made with ❤️ for humanity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
                  const SizedBox(height: 4),
                  Text('© 2026 Heal Chain. All rights reserved.', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary.withValues(alpha: 0.5) : AppTheme.textDarkSecondary.withValues(alpha: 0.5))),
                ])),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primaryRed, letterSpacing: 0.5)),
  );

  Widget _featureItem(bool isDark, IconData icon, Color color, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 3),
          Text(desc, style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
        ])),
      ]),
    );
  }

  Widget _impactStat(bool isDark, String emoji, String value, String label) {
    return Expanded(child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 24)),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
    ]));
  }

  Widget _contactRow(IconData icon, String text, bool isDark) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppTheme.primaryRed, size: 18),
      ),
      const SizedBox(width: 14),
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }
}

class _Card extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _Card({required this.isDark, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: isDark ? AppTheme.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
    ),
    child: child,
  );
}
