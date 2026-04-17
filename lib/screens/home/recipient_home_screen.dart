/// ─────────────────────────────────────────────────────────────────────────────
/// RecipientHomeScreen — Premium recipient dashboard (crash-proof)
/// ─────────────────────────────────────────────────────────────────────────────
/// All Firestore queries use simple .where() without orderBy to avoid
/// composite index requirements. All streams have error handling.
/// Uses AppTheme for all colors — supports dark and light mode.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';

import '../../models/user_model.dart';

class RecipientHomeScreen extends StatefulWidget {
  const RecipientHomeScreen({super.key});
  @override
  State<RecipientHomeScreen> createState() => _RecipientHomeScreenState();
}

class _RecipientHomeScreenState extends State<RecipientHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() { _pulseCtrl.dispose(); _glowCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: RefreshIndicator(
        color: Colors.white, backgroundColor: AppTheme.primaryRed,
        onRefresh: () async => context.read<AuthProvider>().refreshUserData(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _heroSection(isDark, user),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _emergencyCTA(isDark),
                const SizedBox(height: 20),
                _nearbyDonors(isDark, user),
                const SizedBox(height: 20),
                _quickActions(isDark),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HERO SECTION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _heroSection(bool isDark, UserModel user) {
    final h = DateTime.now().hour;
    final greet = h < 12 ? 'Good Morning' : h < 17 ? 'Good Afternoon' : 'Good Evening';
    final isMale = (user.gender ?? '').toLowerCase() != 'female';

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradientFor(isDark),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Top bar
            Row(children: [
              Text(greet, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.6))),
              const Spacer(),
              _headerIcon(Icons.notifications_outlined, onTap: () => context.go(AppRoutes.notifications)),
              const SizedBox(width: 8),
              _headerIcon(Icons.settings_outlined, onTap: () => context.push(AppRoutes.settings)),
            ]),
            const SizedBox(height: 20),

            // Profile row
            Row(children: [
              AnimatedBuilder(
                animation: _glowCtrl,
                builder: (_, _) => Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3 + _glowCtrl.value * 0.2), width: 2.5),
                    boxShadow: [BoxShadow(color: AppTheme.primaryRedLight.withValues(alpha: 0.15 + _glowCtrl.value * 0.1), blurRadius: 16)],
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    backgroundImage: user.profileImageUrl != null
                        ? NetworkImage(user.profileImageUrl!)
                        : AssetImage(isMale ? 'assets/images/avatar_male.png' : 'assets/images/avatar_female.png'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hello, ${user.name.split(' ').first}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (user.isOrganization)
                    _pillChip('🏥 ${user.recipientType == 'hospital' ? 'Hospital' : 'Welfare Org'}')
                  else
                    _pillChip('👤 Individual'),
                  if (user.bloodGroup.isNotEmpty) _pillChip('🩸 ${user.bloodGroup}'),
                ]),
              ])),
            ]),
            const SizedBox(height: 22),

            // Stats
            _statsRow(isDark, user),
          ]),
        ),
      ),
    );
  }

  Widget _statsRow(bool isDark, UserModel user) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('blood_requests')
                .where('recipientId', isEqualTo: user.uid).snapshots(),
            builder: (ctx, snap) {
              if (snap.hasError) {
                return _statsFallback(0, 0, 0);
              }
              final docs = snap.data?.docs ?? [];
              final total = docs.length;
              final active = docs.where((d) {
                try { return d['status'] == 'active'; } catch (_) { return false; }
              }).length;
              final fulfilled = docs.where((d) {
                try { final s = d['status']; return s == 'fulfilled' || s == 'completed'; } catch (_) { return false; }
              }).length;
              return _statsFallback(total, active, fulfilled);
            },
          ),
        ),
      ),
    );
  }

  Widget _statsFallback(int total, int active, int fulfilled) {
    return IntrinsicHeight(
      child: Row(children: [
        Expanded(child: _miniStat('$total', 'Requests', Icons.list_alt_rounded, AppTheme.primaryRedLight)),
        _vDiv(),
        Expanded(child: _miniStat('$active', 'Active', Icons.schedule_rounded, AppTheme.warning)),
        _vDiv(),
        Expanded(child: _miniStat('$fulfilled', 'Fulfilled', Icons.check_circle_rounded, AppTheme.success)),
      ]),
    );
  }

  Widget _miniStat(String val, String lbl, IconData icon, Color c) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: c),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
      const SizedBox(height: 2),
      Text(lbl, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5))),
    ]);
  }

  Widget _vDiv() => Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    color: Colors.white.withValues(alpha: 0.12));

  Widget _headerIcon(IconData ic, {VoidCallback? onTap}) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Icon(ic, color: Colors.white.withValues(alpha: 0.9), size: 20),
    ),
  );

  Widget _pillChip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  //  EMERGENCY CTA
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _emergencyCTA(bool isDark) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, _) => GestureDetector(
        onTap: () => context.push(AppRoutes.createRequest),
        child: Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.primaryRedDark.withValues(alpha: 0.9 + _pulseCtrl.value * 0.1),
              AppTheme.primaryRed,
            ]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.2 + _pulseCtrl.value * 0.1), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Need Blood Urgently?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 3),
              Text('Create request to alert nearby donors', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
            ])),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.7), size: 16),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  NEARBY DONORS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _nearbyDonors(bool isDark, UserModel user) {
    if (user.city == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('role', isEqualTo: 'donor')
          .where('isAvailable', isEqualTo: true)
          .where('city', isEqualTo: user.city)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final count = snap.data?.docs.length ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
            boxShadow: [BoxShadow(color: AppTheme.success.withValues(alpha: isDark ? 0.05 : 0.08), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF43A047)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('$count', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32))),
                const SizedBox(width: 6),
                Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.success)),
                const SizedBox(width: 6),
                Expanded(child: Text('Donors in ${user.city}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textDark), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 2),
              Text('Available right now', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
            ])),
            GestureDetector(
              onTap: () => context.go(AppRoutes.donorSearch),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF43A047)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Find', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  QUICK ACTIONS 2×2
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _quickActions(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Quick Actions'),
      const SizedBox(height: 12),
      Row(children: [
        _actionTile(isDark, Icons.add_circle_outline_rounded, 'New Request', [AppTheme.primaryRedDark, AppTheme.primaryRed], () => context.push(AppRoutes.createRequest)),
        const SizedBox(width: 10),
        _actionTile(isDark, Icons.search_rounded, 'Find Donors', const [Color(0xFF2E7D32), Color(0xFF43A047)], () => context.go(AppRoutes.donorSearch)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _actionTile(isDark, Icons.notifications_active_rounded, 'Alerts', [AppTheme.info, AppTheme.primaryRed], () => context.go(AppRoutes.notifications)),
        const SizedBox(width: 10),
        _actionTile(isDark, Icons.list_alt_rounded, 'My Requests', [AppTheme.warning, const Color(0xFFFFA726)], () => context.push(AppRoutes.requestList)),
      ]),
    ]);
  }

  Widget _actionTile(bool isDark, IconData ic, String title, List<Color> grad, VoidCallback onTap) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppTheme.darkBorder : grad[0].withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: grad[0].withValues(alpha: isDark ? 0.04 : 0.08), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(gradient: LinearGradient(colors: grad), borderRadius: BorderRadius.circular(12)),
          child: Icon(ic, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    )));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _sectionHeader(String text) => Row(children: [
    Container(width: 4, height: 18, margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: AppTheme.buttonGradient)),
    Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
  ]);
}
