/// DonationHistoryScreen — Detailed donation cards with tap-to-expand
library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class DonationHistoryScreen extends StatelessWidget {
  const DonationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: CustomScrollView(slivers: [
        // ─── Gradient Header ──────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 160, pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(children: [
                Positioned(top: -40, right: -40, child: Container(width: 120, height: 120,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.04)))),
                Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(height: 50),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.history_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 12),
                  const Text('Donation History', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  Text('${user.donationCount} total donation${user.donationCount != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
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
        ),

        // ─── Donation Cards ────────────────────────────────────────
        SliverToBoxAdapter(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations')
                .where('donorId', isEqualTo: user.uid)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
              }
              final docs = snap.data?.docs ?? [];

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('chats')
                    .where('donorId', isEqualTo: user.uid)
                    .where('donationStatus', whereIn: ['donated', 'completed'])
                    .snapshots(),
                builder: (ctx2, chatSnap) {
                  final chatDocs = chatSnap.data?.docs ?? [];

                  if (docs.isEmpty && chatDocs.isEmpty) {
                    return _emptyState(isDark);
                  }

                  final allDonations = <_DonationItem>[];

                  // From 'donations' collection
                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final donDate = (data['donationDate'] as Timestamp?)?.toDate() ?? DateTime.now();
                    allDonations.add(_DonationItem(
                      id: doc.id,
                      recipientName: data['recipientName'] as String? ?? 'Unknown',
                      donorName: data['donorName'] as String? ?? user.name,
                      hospital: data['hospital'] as String? ?? '',
                      bloodGroup: data['bloodGroup'] as String? ?? user.bloodGroup,
                      units: data['units'] as int? ?? 1,
                      notes: data['notes'] as String?,
                      date: donDate,
                      isVerified: data['verifiedByRecipient'] as bool? ?? false,
                      source: 'donation',
                      patientName: data['patientName'] as String?,
                      contactNumber: data['contactNumber'] as String?,
                      city: data['city'] as String?,
                    ));
                  }

                  // From 'chats' collection
                  for (var doc in chatDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final lastMsg = (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final chatId = doc.id;
                    if (allDonations.any((d) => d.id == chatId)) continue;
                    allDonations.add(_DonationItem(
                      id: chatId,
                      recipientName: data['recipientName'] as String? ?? 'Unknown',
                      donorName: data['donorName'] as String? ?? user.name,
                      hospital: data['hospitalName'] as String? ?? '',
                      bloodGroup: data['bloodGroup'] as String? ?? user.bloodGroup,
                      units: 1,
                      notes: null,
                      date: lastMsg,
                      isVerified: data['donationStatus'] == 'completed',
                      source: 'chat',
                      patientName: data['patientName'] as String?,
                      contactNumber: data['contactNumber'] as String?,
                      city: data['city'] as String?,
                    ));
                  }

                  allDonations.sort((a, b) => b.date.compareTo(a.date));

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    child: Column(
                      children: allDonations.asMap().entries.map((entry) {
                        return _DonationCard(
                          isDark: isDark,
                          item: entry.value,
                          index: entry.key + 1,
                          total: allDonations.length,
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _emptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(50),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A237E).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.history_rounded, size: 48, color: const Color(0xFF1A237E).withValues(alpha: 0.3)),
        ),
        const SizedBox(height: 20),
        Text('No Donations Yet', style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 18,
          color: isDark ? Colors.white : AppTheme.textDark)),
        const SizedBox(height: 8),
        Text('Your completed donations will appear here.\nStart by accepting a blood request!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
      ]),
    );
  }
}

// ─── Data class for merged donation entries ─────────────────────────────
class _DonationItem {
  final String id;
  final String recipientName;
  final String donorName;
  final String hospital;
  final String bloodGroup;
  final int units;
  final String? notes;
  final DateTime date;
  final bool isVerified;
  final String source;
  final String? patientName;
  final String? contactNumber;
  final String? city;

  _DonationItem({
    required this.id,
    required this.recipientName,
    required this.donorName,
    required this.hospital,
    required this.bloodGroup,
    required this.units,
    this.notes,
    required this.date,
    required this.isVerified,
    required this.source,
    this.patientName,
    this.contactNumber,
    this.city,
  });
}

// ─── Expandable Donation Card ──────────────────────────────────────────
class _DonationCard extends StatefulWidget {
  final bool isDark;
  final _DonationItem item;
  final int index;
  final int total;

  const _DonationCard({required this.isDark, required this.item, required this.index, required this.total});

  @override
  State<_DonationCard> createState() => _DonationCardState();
}

class _DonationCardState extends State<_DonationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.item;
    final isDark = widget.isDark;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.darkCard, const Color(0xFF1A237E).withValues(alpha: 0.12)]
                : [Colors.white, const Color(0xFF1A237E).withValues(alpha: 0.03)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: d.isVerified
                ? AppTheme.success.withValues(alpha: 0.3)
                : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(color: const Color(0xFF1A237E).withValues(alpha: isDark ? 0.06 : 0.05), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(children: [
          // ─── Main Row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Blood group badge
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.buttonGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppTheme.primaryRedDark.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.water_drop_rounded, color: Colors.white, size: 18),
                    const SizedBox(height: 2),
                    Text(d.bloodGroup, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.recipientName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                  color: isDark ? Colors.white : AppTheme.textDark)),
                const SizedBox(height: 3),
                Text(DateFormat('MMM dd, yyyy').format(d.date),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (d.isVerified ? AppTheme.success : const Color(0xFF1565C0)).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(d.isVerified ? '✅ Verified' : '🩸 Donated',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: d.isVerified ? AppTheme.success : const Color(0xFF1565C0))),
                  ),
                  const SizedBox(width: 6),
                  Text('#${widget.index}/${widget.total}',
                    style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
                ]),
              ])),
              Icon(
                _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary,
              ),
            ]),
          ),

          // ─── Expanded Details ────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : const Color(0xFF1A237E)).withValues(alpha: 0.03),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(22), bottomRight: Radius.circular(22)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: [
                // Divider
                Container(
                  height: 1, margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      Colors.transparent,
                    ]),
                  ),
                ),
                _detailRow(isDark, Icons.person_rounded, 'Recipient', d.recipientName),
                if (d.patientName != null && d.patientName!.isNotEmpty)
                  _detailRow(isDark, Icons.personal_injury_rounded, 'Patient', d.patientName!),
                _detailRow(isDark, Icons.volunteer_activism_rounded, 'Donor', d.donorName),
                if (d.hospital.isNotEmpty)
                  _detailRow(isDark, Icons.local_hospital_rounded, 'Hospital', d.hospital),
                if (d.city != null && d.city!.isNotEmpty)
                  _detailRow(isDark, Icons.location_on_rounded, 'City', d.city!),
                _detailRow(isDark, Icons.water_drop_rounded, 'Blood Group', d.bloodGroup),
                _detailRow(isDark, Icons.science_rounded, 'Units', '${d.units}'),
                _detailRow(isDark, Icons.calendar_today_rounded, 'Date & Time', DateFormat('MMMM dd, yyyy • h:mm a').format(d.date)),
                if (d.contactNumber != null && d.contactNumber!.isNotEmpty)
                  _detailRow(isDark, Icons.phone_rounded, 'Contact', d.contactNumber!),
                _detailRow(isDark, Icons.verified_rounded, 'Status', d.isVerified ? 'Verified by Recipient' : 'Pending Verification'),
                if (d.notes != null && d.notes!.isNotEmpty)
                  _detailRow(isDark, Icons.notes_rounded, 'Notes', d.notes!),
                const SizedBox(height: 10),
                // Points earned
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFD700)),
                    const SizedBox(width: 8),
                    Text('You saved a life! +25 points earned 🎉', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textDark)),
                  ]),
                ),
              ]),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ]),
      ),
    );
  }

  Widget _detailRow(bool isDark, IconData ic, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: const Color(0xFF1A237E).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Icon(ic, size: 14, color: const Color(0xFF3949AB)),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
