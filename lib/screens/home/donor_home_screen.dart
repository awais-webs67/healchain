/// ─────────────────────────────────────────────────────────────────────────────
/// DonorHomeScreen — Ultra-premium donor dashboard with rich features
/// ─────────────────────────────────────────────────────────────────────────────
/// Features: Gradient hero + avatar, glassmorphism stats, donation streak,
///   blood compatibility info, availability toggle, quick actions,
///   emergency banner, active donations, recent requests
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/blood_request_model.dart';
import '../../models/user_model.dart';

class DonorHomeScreen extends StatefulWidget {
  const DonorHomeScreen({super.key});
  @override
  State<DonorHomeScreen> createState() => _DonorHomeScreenState();
}

class _DonorHomeScreenState extends State<DonorHomeScreen>
    with TickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;
  bool _reqExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleAvailability(bool v) async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) return;

    // Block enabling during cooldown
    if (v && user.cooldownUntil != null && user.cooldownUntil!.isAfter(DateTime.now())) {
      final daysLeft = user.cooldownUntil!.difference(DateTime.now()).inDays;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🔒 Cooldown active — $daysLeft day${daysLeft != 1 ? 's' : ''} remaining'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isAvailable': v});
    auth.refreshUserData();
  }

  // Blood compatibility data
  static const Map<String, List<String>> _canDonateTo = {
    'O-': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'],
    'O+': ['O+', 'A+', 'B+', 'AB+'],
    'A-': ['A-', 'A+', 'AB-', 'AB+'],
    'A+': ['A+', 'AB+'],
    'B-': ['B-', 'B+', 'AB-', 'AB+'],
    'B+': ['B+', 'AB+'],
    'AB-': ['AB-', 'AB+'],
    'AB+': ['AB+'],
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: AppTheme.primaryRed,
        onRefresh: () async => context.read<AuthProvider>().refreshUserData(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _heroSection(isDark, user)),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _availabilityCard(isDark, user),
                const SizedBox(height: 18),
                _statsGrid(isDark, user),
                const SizedBox(height: 22),
                _donationStreak(isDark, user),
                const SizedBox(height: 22),
                _bloodCompatibility(isDark, user),
                const SizedBox(height: 22),
                _quickActions(isDark),
                const SizedBox(height: 22),
                _emergencyBanner(isDark, user),
                const SizedBox(height: 22),
                _recentRequests(isDark, user),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HERO — Deep gradient header with avatar, name, chips, glass stats
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _heroSection(bool isDark, UserModel user) {
    final daysLeft = user.daysUntilNextDonation;
    final canDonate = user.canDonateNow;
    final eligible = user.isEligible ?? false;
    final h = DateTime.now().hour;
    final greet = h < 12 ? 'Good Morning' : h < 17 ? 'Good Afternoon' : 'Good Evening';
    final isMale = (user.gender ?? '').toLowerCase() != 'female';

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradientFor(isDark),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(children: [
          // Decorative circles — directly positioned, no nested Stack
          Positioned(
            top: -60, right: -70,
            child: Container(width: 200, height: 200, decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.06), Colors.transparent]),
            )),
          ),
          Positioned(
            bottom: -30, left: -50,
            child: Container(width: 150, height: 150, decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.04), Colors.transparent]),
            )),
          ),
          Positioned(
            top: 50, right: 40,
            child: Container(width: 40, height: 40, decoration: BoxDecoration(
              shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.03),
            )),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Top bar
              Row(children: [
                Text(greet, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 0.5)),
                const Spacer(),
                _headerIcon(Icons.notifications_outlined, badge: true, onTap: () => context.go(AppRoutes.notifications)),
              ]),
              const SizedBox(height: 20),

              // Profile row
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Avatar with ring + asset image
                AnimatedBuilder(
                  animation: _glowCtrl,
                  builder: (_, _) => Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3 + _glowCtrl.value * 0.2), width: 2.5),
                      boxShadow: [BoxShadow(
                        color: AppTheme.accentPink.withValues(alpha: 0.2 + _glowCtrl.value * 0.15),
                        blurRadius: 20 + _glowCtrl.value * 10,
                        spreadRadius: _glowCtrl.value * 3,
                      )],
                    ),
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      backgroundImage: user.profileImageUrl != null
                          ? NetworkImage(user.profileImageUrl!)
                          : AssetImage(isMale ? 'assets/images/avatar_male.png' : 'assets/images/avatar_female.png'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Flexible(child: _pillChip('🩸 ${user.bloodGroup}', Colors.white.withValues(alpha: 0.15))),
                    const SizedBox(width: 6),
                    Flexible(child: _pillChip('${user.donorLevelEmoji} ${user.donorLevel}', Colors.white.withValues(alpha: 0.15))),
                    if (user.isAvailable) ...[
                      const SizedBox(width: 6),
                      _pillChip('🟢 Online', AppTheme.success.withValues(alpha: 0.25)),
                    ],
                  ]),
                ])),
              ]),
              const SizedBox(height: 24),

              // Glassmorphism stats card
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.04)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 8)),
                        BoxShadow(color: Colors.white.withValues(alpha: 0.05), blurRadius: 1, spreadRadius: 0),
                      ],
                    ),
                    child: Column(children: [
                      Row(children: [
                        _glassStat('${user.donationCount}', 'Donations', Icons.water_drop_rounded, AppTheme.accentPink),
                        _glassDivider(),
                        _glassStat('${user.points}', 'Points', Icons.star_rounded, const Color(0xFFFFD700)),
                        _glassDivider(),
                        _glassReadyStat(eligible && canDonate, daysLeft),
                        _glassDivider(),
                        _glassStat('${(user.donationCount * 3)}', 'Lives', Icons.favorite_rounded, const Color(0xFFFF8A80)),
                      ]),
                      // Cooldown bar
                      if (daysLeft > 0 && eligible) ...[
                        const SizedBox(height: 16),
                        Builder(builder: (_) {
                          // Compute total cooldown from actual dates
                          final totalCooldown = (user.cooldownUntil != null && user.lastDonationDate != null)
                              ? user.cooldownUntil!.difference(user.lastDonationDate!).inDays.toDouble()
                              : 56.0;
                          final total = totalCooldown > 0 ? totalCooldown : 56.0;
                          return Column(children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.calendar_today_rounded, size: 10, color: Colors.white.withValues(alpha: 0.6)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Next: ${user.nextDonationDate != null ? DateFormat('MMM dd, yyyy').format(user.nextDonationDate!) : ''}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6)),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${((1.0 - daysLeft / total) * 100).clamp(0, 100).toInt()}%',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.9))),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: (1.0 - (daysLeft / total)).clamp(0.0, 1.0), minHeight: 5,
                                backgroundColor: Colors.white.withValues(alpha: 0.06),
                                valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                              ),
                            ),
                          ]);
                        }),
                      ],
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _headerIcon(IconData ic, {bool badge = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(ic, color: Colors.white.withValues(alpha: 0.9), size: 20),
        ),
        if (badge) Positioned(top: 6, right: 6, child: Container(
          width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFD700),
            boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.5), blurRadius: 6)]),
        )),
      ]),
    );
  }

  Widget _pillChip(String t, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
    child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
  );

  Widget _glassStat(String val, String lbl, IconData icon, Color iconColor) => Expanded(child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 14, color: iconColor),
      ),
      const SizedBox(height: 5),
      FittedBox(fit: BoxFit.scaleDown, child: Text(val, maxLines: 1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, child: Text(lbl, maxLines: 1, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5), letterSpacing: 0.3))),
    ]),
  ));

  // Premium "Ready" / "Cooldown" indicator replacing ugly ✅ emoji
  Widget _glassReadyStat(bool isReady, int daysLeft) => Expanded(child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Column(children: [
      AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, _) => Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: isReady ? LinearGradient(
              colors: [const Color(0xFF00E676).withValues(alpha: 0.3 + _pulseCtrl.value * 0.15), const Color(0xFF69F0AE).withValues(alpha: 0.15)],
            ) : null,
            color: isReady ? null : const Color(0xFFFFA726).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            boxShadow: isReady ? [
              BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.2 + _pulseCtrl.value * 0.15), blurRadius: 8, spreadRadius: 1),
            ] : [],
          ),
          child: Icon(
            isReady ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
            size: 14,
            color: isReady ? const Color(0xFF00E676) : const Color(0xFFFFA726),
          ),
        ),
      ),
      const SizedBox(height: 5),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: isReady
            ? ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF69F0AE)],
                ).createShader(bounds),
                child: const Text('READY', maxLines: 1, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
              )
            : Text('${daysLeft}d', maxLines: 1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, child: Text(
        isReady ? 'Donate Now' : 'Cooldown',
        maxLines: 1,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5), letterSpacing: 0.3),
      )),
    ]),
  ));

  Widget _glassDivider() => Container(
    width: 1, height: 50, margin: const EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.0), Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.0)],
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  //  AVAILABILITY TOGGLE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _availabilityCard(bool isDark, UserModel user) {
    final on = user.isAvailable;
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: on
            ? LinearGradient(colors: [AppTheme.success.withValues(alpha: isDark ? 0.15 : 0.08), AppTheme.success.withValues(alpha: isDark ? 0.08 : 0.03)])
            : null,
        color: on ? null : (isDark ? AppTheme.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: on ? AppTheme.success.withValues(alpha: 0.35) : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder), width: 1.2),
        boxShadow: [BoxShadow(color: (on ? AppTheme.success : Colors.black).withValues(alpha: on ? 0.1 : 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: on ? const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF43A047)]) : null,
            color: on ? null : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(on ? Icons.volunteer_activism_rounded : Icons.pause_circle_outline_rounded,
              color: on ? Colors.white : AppTheme.textTertiary, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(on ? 'Available to Donate' : 'You\'re Offline',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: on ? AppTheme.success : null)),
          const SizedBox(height: 2),
          Text(on ? 'Recipients can find & contact you' : 'Toggle to start receiving requests',
              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
        ])),
        Switch.adaptive(
          value: on,
          onChanged: (user.cooldownUntil != null && user.cooldownUntil!.isAfter(DateTime.now()))
              ? null  // Disabled during cooldown
              : _toggleAvailability,
          activeThumbColor: AppTheme.success,
          activeTrackColor: AppTheme.success.withValues(alpha: 0.3),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STATS GRID (2×2)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _statsGrid(bool isDark, UserModel user) {
    return Column(children: [
      Row(children: [
        _statTile(isDark, '🩸', '${user.donationCount}', 'Total Donated', AppTheme.primaryRed),
        const SizedBox(width: 10),
        _statTile(isDark, '⭐', '${user.points}', 'Reward Points', const Color(0xFFF59E0B)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _statTile(isDark, '❤️', '${user.donationCount * 3}', 'Lives Saved', const Color(0xFFEC4899)),
        const SizedBox(width: 10),
        _statTile(isDark, user.donorLevelEmoji, user.donorLevel, 'Donor Level', const Color(0xFF8B5CF6)),
      ]),
    ]);
  }

  Widget _statTile(bool isDark, String emoji, String val, String lbl, Color accent) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.darkCard, AppTheme.darkCard]
              : [Colors.white, accent.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18), width: 1.2),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: isDark ? 0.08 : 0.12), blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.white.withValues(alpha: isDark ? 0 : 0.8), blurRadius: 1, spreadRadius: 0),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.06)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: accent.withValues(alpha: 0.1)),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(val, maxLines: 1, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: accent, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 2),
          Text(lbl, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary, letterSpacing: 0.2)),
        ])),
      ]),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DONATION STREAK
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _donationStreak(bool isDark, UserModel user) {
    final streak = user.donationCount; // Simplified: streak = total donations
    final progress = (streak % 4) / 4.0; // Every 4 donations = milestone
    final nextMilestone = ((streak ~/ 4) + 1) * 4;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08),
          const Color(0xFFEF4444).withValues(alpha: isDark ? 0.08 : 0.04),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🔥', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Donation Streak', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : AppTheme.textDark)),
            Text('$streak donation${streak != 1 ? 's' : ''} — $nextMilestone for next milestone!',
                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
            child: Text('$streak 🔥', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
          ),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress, minHeight: 6,
            backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(progress * 100).toInt()}% to milestone', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
          Text('🎯 $nextMilestone donations', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
        ]),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BLOOD COMPATIBILITY INFO
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _bloodCompatibility(bool isDark, UserModel user) {
    if (user.bloodGroup.isEmpty) return const SizedBox.shrink();
    final compatible = _canDonateTo[user.bloodGroup] ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0 : 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: AppTheme.buttonGradient, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Blood Compatibility', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : AppTheme.textDark)),
            Text('Your ${user.bloodGroup} can donate to:', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
          ])),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: compatible.map((bg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: bg == user.bloodGroup
                ? AppTheme.buttonGradient
                : null,
            color: bg != user.bloodGroup ? AppTheme.primaryRed.withValues(alpha: isDark ? 0.1 : 0.06) : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.2)),
          ),
          child: Text(bg, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800,
            color: bg == user.bloodGroup ? Colors.white : AppTheme.primaryRed,
          )),
        )).toList()),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  QUICK ACTIONS (2×2)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _quickActions(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 4, height: 20, margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: AppTheme.buttonGradient)),
        Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const Spacer(),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        _actionTile(isDark, Icons.water_drop_rounded, 'Browse\nRequests', 'Find who needs blood',
            [AppTheme.primaryRedDark, AppTheme.primaryRed], () => context.go(AppRoutes.bloodRequests)),
        const SizedBox(width: 12),
        _actionTile(isDark, Icons.history_rounded, 'Donation\nHistory', 'Past donations',
            const [Color(0xFF1565C0), Color(0xFF1E88E5)], () => context.push(AppRoutes.donationHistory)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _actionTile(isDark, Icons.person_rounded, 'My\nProfile', 'View & edit info',
            const [Color(0xFF6A1B9A), Color(0xFF8E24AA)], () => context.go(AppRoutes.profile)),
        const SizedBox(width: 12),
        _actionTile(isDark, Icons.settings_rounded, 'App\nSettings', 'Preferences & theme',
            const [Color(0xFF37474F), Color(0xFF546E7A)], () => context.push(AppRoutes.settings)),
      ]),
    ]);
  }

  Widget _actionTile(bool isDark, IconData ic, String title, String sub, List<Color> grad, VoidCallback onTap) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.darkCard, AppTheme.darkCard]
              : [Colors.white, grad[0].withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppTheme.darkBorder : grad[0].withValues(alpha: 0.1), width: 1.2),
        boxShadow: [
          BoxShadow(color: grad[0].withValues(alpha: isDark ? 0.06 : 0.1), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: grad[0].withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5)),
              BoxShadow(color: grad[1].withValues(alpha: 0.15), blurRadius: 1, spreadRadius: 0),
            ],
          ),
          child: Icon(ic, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(sub, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary, letterSpacing: 0.1), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    )));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  EMERGENCY BANNER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _emergencyBanner(bool isDark, UserModel user) {
    if (user.bloodGroup.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _fs.getRequestsByBloodGroup(user.bloodGroup),
      builder: (ctx, snap) {
        final reqs = snap.data ?? [];
        final critical = reqs.where((r) => r.isCritical && r.city?.toLowerCase() == user.city?.toLowerCase());
        if (critical.isEmpty) return const SizedBox.shrink();
        final req = critical.first;
        return AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, _) => GestureDetector(
            onTap: () => context.push('${AppRoutes.requestDetail}?id=${req.id}'),
            child: Container(
              width: double.infinity, margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.error.withValues(alpha: 0.1 + _pulseCtrl.value * 0.06),
                  AppTheme.error.withValues(alpha: 0.05 + _pulseCtrl.value * 0.04),
                ]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3 + _pulseCtrl.value * 0.2), width: 1.5),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.emergency_rounded, color: AppTheme.error, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('🚨 Emergency!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.error)),
                  const SizedBox(height: 3),
                  Text('${req.bloodGroup} needed — ${req.hospitalName ?? req.city ?? 'Nearby'}',
                      style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textSecondary : AppTheme.textDarkSecondary)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(14)),
                  child: const Text('View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }


  // ═══════════════════════════════════════════════════════════════════════════
  //  RECENT REQUESTS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _recentRequests(bool isDark, UserModel user) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => setState(() => _reqExpanded = !_reqExpanded),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 4, height: 20, margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: AppTheme.buttonGradient)),
            Text('Recent Requests', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ]),
          Row(children: [
            GestureDetector(
              onTap: () => context.go(AppRoutes.bloodRequests),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: AppTheme.buttonGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('See All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: _reqExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      // Only build the StreamBuilder when expanded (avoids unnecessary Firestore listeners)
      if (_reqExpanded)
        StreamBuilder<List<BloodRequestModel>>(
          stream: user.bloodGroup.isNotEmpty ? _fs.getRequestsByBloodGroup(user.bloodGroup) : _fs.getActiveRequests(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Column(children: List.generate(2, (_) => Container(
                width: double.infinity, height: 82, margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                ),
                child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              )));
            }
            final reqs = snap.data ?? [];
            if (reqs.isEmpty) return _emptyState(isDark);
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: reqs.length,
                itemBuilder: (_, i) => _reqCard(isDark, reqs[i]),
              ),
            );
          },
        ),
    ]);
  }

  Widget _reqCard(bool isDark, BloodRequestModel r) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.requestDetail}?id=${r.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: r.isCritical ? AppTheme.error.withValues(alpha: 0.4) : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
          boxShadow: [BoxShadow(color: (r.isCritical ? AppTheme.error : Colors.black).withValues(alpha: isDark ? 0 : 0.05), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: r.isCritical ? [AppTheme.error, AppTheme.accentPink] : [AppTheme.primaryRedDark, AppTheme.primaryRed]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Center(child: Text(r.bloodGroup, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.recipientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Row(children: [
              Icon(Icons.location_on_rounded, size: 13, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
              const SizedBox(width: 3),
              Expanded(child: Text(r.hospitalName ?? r.city ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
            ]),
          ])),
          _urgencyBadge(r),
        ]),
      ),
    );
  }

  Widget _urgencyBadge(BloodRequestModel r) {
    final c = r.isCritical ? AppTheme.error : r.isUrgent ? AppTheme.warning : AppTheme.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Text(r.urgency, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
    );
  }

  Widget _emptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: Icon(Icons.check_circle_rounded, size: 44, color: AppTheme.success.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 16),
        Text('All Clear! 🎉', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('No pending requests for your blood type.\nWe\'ll notify you when someone needs help.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary, height: 1.5)),
      ]),
    );
  }
}

