/// BloodRequestsScreen — Shows requests matching donor's blood type compatibility
library;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/blood_request_model.dart';

class BloodRequestsScreen extends StatefulWidget {
  const BloodRequestsScreen({super.key});
  @override
  State<BloodRequestsScreen> createState() => _BloodRequestsScreenState();
}

class _BloodRequestsScreenState extends State<BloodRequestsScreen> {
  final FirestoreService _fs = FirestoreService();
  String _filter = 'All'; // All, Critical, Urgent, Normal

  /// Donor blood group → recipient blood groups that this donor CAN donate to
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
    final myBloodGroup = user?.bloodGroup ?? '';

    // Check if donor is on cooldown
    final isOnCooldown = user?.cooldownUntil != null && user!.cooldownUntil!.isAfter(DateTime.now());
    final cooldownDays = isOnCooldown ? user.daysUntilNextDonation : 0;

    // Get all compatible recipient groups this donor can help
    final compatibleGroups = _canDonateTo[myBloodGroup] ?? [myBloodGroup];

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // ─── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.buttonGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Blood Requests', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(
                  myBloodGroup.isNotEmpty
                    ? '$myBloodGroup can donate to: ${compatibleGroups.join(", ")}'
                    : 'Help someone in need today',
                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ])),
            ]),
          ),

          // ─── Cooldown Banner ───────────────────────────────────────
          if (isOnCooldown) Container(
            margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.timer_rounded, color: AppTheme.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('⏱ Cooldown Active', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.warning)),
                const SizedBox(height: 2),
                Text('You must wait $cooldownDays days before donating again',
                  style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
              ])),
            ]),
          ),

          const SizedBox(height: 14),

          // ─── Filter chips ──────────────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _filterChip('All', Icons.list_rounded, isDark),
                _filterChip('Critical', Icons.emergency_rounded, isDark, color: AppTheme.error),
                _filterChip('Urgent', Icons.warning_rounded, isDark, color: AppTheme.warning),
                _filterChip('Normal', Icons.schedule_rounded, isDark, color: AppTheme.info),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─── Request list — filtered by compatibility ──────────────
          Expanded(
            child: StreamBuilder<List<BloodRequestModel>>(
              // Get all active requests and filter client-side by compatibility
              stream: _fs.getActiveRequests(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var reqs = snap.data ?? [];

                // Filter by blood group compatibility (donor can donate to these groups)
                if (myBloodGroup.isNotEmpty) {
                  reqs = reqs.where((r) => compatibleGroups.contains(r.bloodGroup)).toList();
                }

                // Apply urgency filter
                if (_filter == 'Critical') {
                  reqs = reqs.where((r) => r.urgency == 'Critical').toList();
                } else if (_filter == 'Urgent') {
                  reqs = reqs.where((r) => r.urgency == 'Urgent').toList();
                } else if (_filter == 'Normal') {
                  reqs = reqs.where((r) => r.urgency == 'Normal').toList();
                }

                // Also exclude requests created by this donor
                reqs = reqs.where((r) => r.recipientId != user?.uid).toList();

                if (reqs.isEmpty) {
                  return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inbox_rounded, size: 56, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    const SizedBox(height: 14),
                    Text(
                      'No ${_filter == 'All' ? '' : '$_filter '}requests for $myBloodGroup',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text('Check back later', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
                  ]));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: reqs.length,
                  itemBuilder: (_, i) => _requestCard(isDark, reqs[i], isOnCooldown, cooldownDays),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _filterChip(String label, IconData icon, bool isDark, {Color? color}) {
    final isActive = _filter == label;
    final chipColor = color ?? AppTheme.primaryRed;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? chipColor.withValues(alpha: 0.15) : (isDark ? AppTheme.darkCard : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? chipColor : Colors.transparent, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: isActive ? chipColor : (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? chipColor : (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
        ]),
      ),
    );
  }

  Widget _requestCard(bool isDark, BloodRequestModel r, bool isOnCooldown, int cooldownDays) {
    final urgencyColor = r.isCritical ? AppTheme.error : r.isUrgent ? AppTheme.warning : AppTheme.info;

    return GestureDetector(
      onTap: () => context.push('${AppRoutes.requestDetail}?id=${r.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: isDark
              ? [AppTheme.darkCard, AppTheme.darkCard]
              : [Colors.white, urgencyColor.withValues(alpha: 0.03)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: r.isCritical ? AppTheme.error.withValues(alpha: 0.4) : (isDark ? AppTheme.darkBorder : urgencyColor.withValues(alpha: 0.15)), width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0 : 0.05), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Blood group badge — circular
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: r.isCritical
                      ? [AppTheme.primaryRedDark, AppTheme.primaryRed]
                      : [const Color(0xFF7B1FA2), const Color(0xFFAB47BC)],
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: (r.isCritical ? AppTheme.error : const Color(0xFF7B1FA2)).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Center(child: Text(r.bloodGroup, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.recipientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              if (r.hospitalName != null) Row(children: [
                Icon(Icons.local_hospital_rounded, size: 13, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(r.hospitalName!, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ])),
            Column(children: [
              _urgencyBadge(r),
              const SizedBox(height: 6),
              if (isOnCooldown) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Text('⏱ ${cooldownDays}d', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.warning)),
              ),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _infoChip(Icons.location_on_rounded, r.city ?? 'Unknown', isDark),
            const SizedBox(width: 8),
            _infoChip(Icons.schedule_rounded, _timeAgo(r.createdAt), isDark),
            const SizedBox(width: 8),
            _infoChip(Icons.water_drop_rounded, '${r.unitsNeeded} unit${r.unitsNeeded > 1 ? 's' : ''}', isDark),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: isOnCooldown ? null : const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)]),
                color: isOnCooldown ? Colors.grey.withValues(alpha: 0.2) : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isOnCooldown ? 'On Cooldown' : 'View',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isOnCooldown ? Colors.grey : Colors.white),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _urgencyBadge(BloodRequestModel r) {
    final color = r.isCritical ? AppTheme.error : r.isUrgent ? AppTheme.warning : AppTheme.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Text(r.urgency, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _infoChip(IconData ic, String text, bool isDark) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(ic, size: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
    ]);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
