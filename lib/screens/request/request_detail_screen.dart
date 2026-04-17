/// ─────────────────────────────────────────────────────────────────────────────
/// RequestDetailScreen — Role-aware blood request details
/// ─────────────────────────────────────────────────────────────────────────────
/// DONOR sees: request info + "I'm Donating" (or "See Chat" if already accepted)
/// RECIPIENT sees: their request STATUS + who accepted
/// OTHER DONORS see: "Donated" if already taken
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../services/chat_service.dart';
import '../../models/blood_request_model.dart';
import '../../providers/auth_provider.dart';

class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  const RequestDetailScreen({super.key, required this.requestId});
  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool _donating = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('blood_requests').doc(widget.requestId).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
              ),
              const SizedBox(height: 16),
              const Text('Request not found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              TextButton(onPressed: () => context.pop(), child: const Text('Go Back')),
            ]));
          }
          final data = snap.data!.data() as Map<String, dynamic>;
          final req = BloodRequestModel.fromMap(data, snap.data!.id);
          return _buildContent(context, isDark, req);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, BloodRequestModel req) {
    final user = context.watch<AuthProvider>().userModel;
    final myUid = user?.uid ?? '';
    final isRecipient = myUid == req.recipientId;
    final isDonor = user?.role == 'donor';
    final isAdmin = user?.role == 'admin';
    final urgencyColor = req.isCritical ? AppTheme.error : req.isUrgent ? AppTheme.warning : AppTheme.info;

    return CustomScrollView(slivers: [
      // ─── Premium Gradient Header ────────────────────────────────
      SliverAppBar(
        expandedHeight: 220,
        pinned: true,
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: req.isCritical
                    ? [const Color(0xFF5C0000), const Color(0xFF8B0000), AppTheme.primaryRed]
                    : [const Color(0xFF1A0033), const Color(0xFF4A0072), const Color(0xFF7B1FA2)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(children: [
              Positioned(top: -40, right: -40, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
              Positioned(bottom: -30, left: -30, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.03)))),
              Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 50),
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Center(child: Text(req.bloodGroup, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white))),
                ),
                const SizedBox(height: 14),
                Text('${req.bloodGroup} Blood Needed', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
                const SizedBox(height: 8),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _headerChip(urgencyColor, req.isCritical ? Icons.warning_amber_rounded : Icons.schedule_rounded, req.urgency),
                  const SizedBox(width: 8),
                  _headerChip(Colors.white.withValues(alpha: 0.3), Icons.water_drop_rounded, '${req.unitsNeeded} unit${req.unitsNeeded != 1 ? 's' : ''}'),
                  const SizedBox(width: 8),
                  _headerChip(_statusBadgeColor(req.status), Icons.circle, req.status.toUpperCase()),
                ]),
              ])),
            ]),
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Delete button: admin (unfulfilled only) + recipient (own request)
          if ((isAdmin && req.status != 'fulfilled') || isRecipient)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
              ),
              onPressed: () => _deleteRequest(req),
            ),
        ],
      ),

      // ─── Content ────────────────────────────────────────────────
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Recipient info
          _card(isDark, 'Recipient', Icons.person_rounded, const Color(0xFF7B1FA2), [
            _infoRow('Name', req.recipientName, isDark),
            if (req.hospitalName != null) _infoRow('Hospital', req.hospitalName!, isDark),
            _infoRow('City', req.city ?? 'Unknown', isDark),
            if (req.country != null) _infoRow('Country', req.country!, isDark),
          ]),
          const SizedBox(height: 14),

          // Request details
          _card(isDark, 'Request Details', Icons.info_rounded, const Color(0xFFF57C00), [
            _infoRow('Blood Group', req.bloodGroup, isDark),
            _infoRow('Units Needed', '${req.unitsNeeded}', isDark),
            _infoRow('Urgency', req.urgency, isDark),
            _infoRow('Status', req.status[0].toUpperCase() + req.status.substring(1), isDark),
            _infoRow('Posted', DateFormat('MMM dd, yyyy • h:mm a').format(req.createdAt), isDark),
            if (req.notes != null && req.notes!.isNotEmpty) _infoRow('Notes', req.notes!, isDark),
          ]),
          const SizedBox(height: 24),

          // ─── ROLE-BASED ACTION SECTION ─────────────────────────────
          if (isRecipient)
            _recipientActions(isDark, req)
          else if (isDonor)
            _donorActions(isDark, req, myUid)
          else
            const SizedBox.shrink(),
        ]),
      )),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RECIPIENT VIEW — Shows status, NO donate button
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _recipientActions(bool isDark, BloodRequestModel req) {
    if (req.status == 'fulfilled') {
      return Column(children: [
        _statusBanner(isDark, '✅ Request Fulfilled', 'A donor has completed the donation', AppTheme.success),
        if (req.fulfilledBy != null) ...[
          const SizedBox(height: 16),
          _donorDetailsCard(isDark, req.fulfilledBy!),
        ],
        const SizedBox(height: 14),
        // Thank you banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFFFFD700).withValues(alpha: 0.12),
              const Color(0xFFFFD700).withValues(alpha: 0.05),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Text('🎉', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Life Saved!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : AppTheme.textDark)),
              const SizedBox(height: 2),
              Text('Thank you for using HealChain', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
            ])),
          ]),
        ),
      ]);
    }
    if (req.status == 'in_progress') {
      return Column(children: [
        _statusBanner(isDark, '🔄 Donor Accepted', 'A donor is on their way to help', AppTheme.warning),
        const SizedBox(height: 14),
        // Chat button — query for associated chat
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('chats')
              .where('requestId', isEqualTo: req.id).limit(1).get(),
          builder: (_, chatSnap) {
            if (!chatSnap.hasData || chatSnap.data!.docs.isEmpty) return const SizedBox.shrink();
            final chatId = chatSnap.data!.docs.first.id;
            return _fullWidthButton(
              icon: Icons.chat_rounded,
              label: 'Open Chat with Donor',
              colors: [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
              onTap: () => context.push('${AppRoutes.conversation}?id=$chatId'),
            );
          },
        ),
      ]);
    }
    return Column(children: [
      _statusBanner(isDark, '⏳ Waiting for Donors', 'Your request is live and visible to compatible donors', AppTheme.info),
      const SizedBox(height: 14),
      // Contact buttons
      Row(children: [
        Expanded(child: _actionBtn(Icons.phone_rounded, 'Call', const Color(0xFF43A047), () => _makeCall(req))),
        const SizedBox(width: 12),
        Expanded(child: _actionBtn(Icons.message_rounded, 'WhatsApp', const Color(0xFF25D366), () => _openWhatsApp(req))),
      ]),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DONOR VIEW — "I'm Donating" / "See Chat" / "Already Taken"
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _donorActions(bool isDark, BloodRequestModel req, String myUid) {
    final user = context.read<AuthProvider>().userModel;

    // Request already fulfilled
    if (req.status == 'fulfilled') {
      return _statusBanner(isDark, '✅ Already Donated', 'This request has been fulfilled', AppTheme.success);
    }

    // CHECK COOLDOWN — block donor from donating
    final isOnCooldown = user?.cooldownUntil != null && user!.cooldownUntil!.isAfter(DateTime.now());
    if (isOnCooldown) {
      final daysLeft = user.cooldownUntil!.difference(DateTime.now()).inDays;
      return _statusBanner(isDark, '⏱ Cooldown Active — $daysLeft days remaining',
          'You must complete your cooldown period before donating again. Thank you for your previous donation!', AppTheme.warning);
    }

    return Column(children: [
      Row(children: [
        Expanded(child: _actionBtn(Icons.phone_rounded, 'Call', const Color(0xFF43A047), () => _makeCall(req))),
        const SizedBox(width: 12),
        Expanded(child: _actionBtn(Icons.message_rounded, 'WhatsApp', const Color(0xFF25D366), () => _openWhatsApp(req))),
      ]),
      const SizedBox(height: 16),

      // Check if THIS donor already has a chat for this request
      FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('chats')
            .where('requestId', isEqualTo: req.id)
            .where('donorId', isEqualTo: myUid)
            .limit(1).get(),
        builder: (ctx, chatSnap) {
          if (chatSnap.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()));
          }

          // THIS donor already accepted → Show "See Chat"
          if (chatSnap.hasData && chatSnap.data!.docs.isNotEmpty) {
            final chatId = chatSnap.data!.docs.first.id;
            return _fullWidthButton(
              icon: Icons.chat_rounded,
              label: 'See Chat',
              colors: [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
              onTap: () => context.push('${AppRoutes.conversation}?id=$chatId'),
            );
          }

          // Request taken by ANOTHER donor
          if (req.status == 'in_progress' && req.fulfilledBy != null && req.fulfilledBy != myUid) {
            return _statusBanner(isDark, '🔒 Already Being Handled', 'Another donor has accepted this request', AppTheme.warning);
          }

          // Request is active → Show "I'm Donating"
          return _fullWidthButton(
            icon: Icons.volunteer_activism_rounded,
            label: "I'm Donating",
            colors: req.isCritical ? [AppTheme.primaryRedDark, AppTheme.primaryRed] : [const Color(0xFF7B1FA2), const Color(0xFFAB47BC)],
            onTap: _donating ? null : () => _handleDonate(req),
            isLoading: _donating,
          );
        },
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DONOR DETAILS CARD — fetches donor profile for completed requests
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _donorDetailsCard(bool isDark, String donorUid) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(donorUid).get(),
      builder: (_, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.15)),
            ),
            child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final d = snap.data!.data() as Map<String, dynamic>;
        final name = d['name'] ?? 'Donor';
        final bg = d['bloodGroup'] ?? '';
        final city = d['city'] ?? '';
        final phone = d['phone'] ?? '';
        final gender = d['gender'] ?? '';
        final donations = d['donationCount'] ?? 0;
        final points = d['points'] ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [AppTheme.darkCard, const Color(0xFF1565C0).withValues(alpha: 0.08)]
                  : [Colors.white, const Color(0xFF1565C0).withValues(alpha: 0.04)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.15)),
            boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: isDark ? 0.06 : 0.08), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Section title
            Row(children: [
              Container(width: 4, height: 18, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]))),
              Text('Donor Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textDark)),
            ]),
            const SizedBox(height: 14),

            // Donor avatar + name
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Center(child: Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : AppTheme.textDark)),
                const SizedBox(height: 3),
                Row(children: [
                  if (bg.isNotEmpty) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(gradient: AppTheme.buttonGradient, borderRadius: BorderRadius.circular(8)),
                    child: Text(bg, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  if (gender.isNotEmpty)
                    Text(gender, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
                ]),
              ])),
            ]),

            const SizedBox(height: 14),

            // Divider
            Container(
              height: 1,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [
                Colors.transparent, (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06), Colors.transparent,
              ])),
            ),

            const SizedBox(height: 14),

            // Details grid
            Row(children: [
              Expanded(child: _donorDetailItem(isDark, Icons.location_on_rounded, 'City', city.isEmpty ? 'N/A' : city)),
              Expanded(child: _donorDetailItem(isDark, Icons.phone_rounded, 'Phone', phone.isEmpty ? 'N/A' : phone)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _donorDetailItem(isDark, Icons.favorite_rounded, 'Donations', '$donations')),
              Expanded(child: _donorDetailItem(isDark, Icons.star_rounded, 'Points', '$points')),
            ]),
          ]),
        );
      },
    );
  }

  Widget _donorDetailItem(bool isDark, IconData ic, String label, String value) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: Icon(ic, size: 14, color: const Color(0xFF42A5F5)),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _headerChip(Color bg, IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: bg.withValues(alpha: 0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: Colors.white), const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
    ]),
  );

  Widget _statusBanner(bool isDark, String title, String subtitle, Color color) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Icon(Icons.info_rounded, color: color, size: 22)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
      ])),
    ]),
  );

  Widget _fullWidthButton({required IconData icon, required String label, required List<Color> colors, VoidCallback? onTap, bool isLoading = false}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: onTap == null && !isLoading ? null : LinearGradient(colors: colors),
          color: onTap == null && !isLoading ? Colors.grey : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: onTap != null ? [BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))] : [],
        ),
        child: Center(child: isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 10),
                Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
        ),
      ),
    );

  Color _statusBadgeColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'in_progress': return Colors.orange;
      case 'fulfilled': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Widget _card(bool isDark, String title, IconData icon, Color accent, List<Widget> children) => Container(
    width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: isDark ? [AppTheme.darkCard, AppTheme.darkCard] : [Colors.white, accent.withValues(alpha: 0.02)]),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: isDark ? AppTheme.darkBorder : accent.withValues(alpha: 0.1), width: 1.2),
      boxShadow: [BoxShadow(color: accent.withValues(alpha: isDark ? 0.04 : 0.06), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: accent)),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : AppTheme.textDark)),
      ]),
      const SizedBox(height: 14),
      ...children,
    ]),
  );

  Widget _infoRow(String label, String value, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    ]),
  );

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.03)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.2),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 20), const SizedBox(width: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
      ]),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Donor taps "I'm Donating" — lock request + create chat + navigate
  Future<void> _handleDonate(BloodRequestModel req) async {
    setState(() => _donating = true);
    try {
      final user = context.read<AuthProvider>().userModel;
      if (user == null) throw 'Not authenticated';

      final db = FirebaseFirestore.instance;

      // 1. Lock the request — mark as in_progress so other donors see it's taken
      await db.collection('blood_requests').doc(req.id).update({
        'status': 'in_progress',
        'fulfilledBy': user.uid,
      });

      // 2. Notify the recipient that a donor accepted
      await db.collection('notifications').add({
        'userId': req.recipientId,
        'title': '🎉 Donor Found!',
        'body': '${user.name} has accepted your ${req.bloodGroup} blood request and is coming to help!',
        'type': 'donor_accepted',
        'isRead': false,
        'requestId': req.id,
        'createdAt': Timestamp.now(),
      });

      // 3. Create chat
      final cs = ChatService();
      final chatId = await cs.createOrGetChat(
        requestId: req.id,
        donorId: user.uid,
        donorName: user.name,
        recipientId: req.recipientId,
        recipientName: req.recipientName,
        bloodGroup: req.bloodGroup,
        hospitalName: req.hospitalName,
      );

      // 4. Navigate to chat
      if (mounted) context.push('${AppRoutes.conversation}?id=$chatId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _donating = false);
  }

  /// Delete a request — CASCADE: also delete chats, messages, notifications
  Future<void> _deleteRequest(BloodRequestModel req) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request?'),
        content: Text(req.status == 'in_progress'
            ? 'This will also cancel the ongoing chat with the donor. This action cannot be undone.'
            : 'This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final db = FirebaseFirestore.instance;

    // Find and delete associated chats + messages
    final chatSnap = await db.collection('chats').where('requestId', isEqualTo: req.id).get();
    for (final chatDoc in chatSnap.docs) {
      final messagesSnap = await db.collection('chats').doc(chatDoc.id).collection('messages').get();
      for (final msg in messagesSnap.docs) {
        await msg.reference.delete();
      }
      await chatDoc.reference.delete();
    }

    // Delete related notifications
    final notifSnap = await db.collection('notifications').where('requestId', isEqualTo: req.id).get();
    for (final notif in notifSnap.docs) {
      await notif.reference.delete();
    }

    // Delete the request
    await db.collection('blood_requests').doc(req.id).delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request deleted'), behavior: SnackBarBehavior.floating));
      context.pop();
    }
  }

  void _makeCall(BloodRequestModel req) async {
    final phone = req.contactNumber ?? '0300000000';
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _openWhatsApp(BloodRequestModel req) async {
    final phone = req.contactNumber ?? '92300000000';
    final uri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }
}
