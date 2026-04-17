/// ─────────────────────────────────────────────────────────────────────────────
/// DonorSearchScreen — Find donors with compatibility & profile popup
/// ─────────────────────────────────────────────────────────────────────────────
/// Features:
///  - Default country Pakistan
///  - Multi-select blood group with compatibility suggestions
///  - City-only filtering (shows donors in selected city only)
///  - Donor profile popup with health info, contact buttons (Call/WhatsApp)
///  - Send Request button creates chat session
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../config/constants.dart';

import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/blood_request_model.dart';
import '../../providers/auth_provider.dart';

class DonorSearchScreen extends StatefulWidget {
  const DonorSearchScreen({super.key});
  @override
  State<DonorSearchScreen> createState() => _DonorSearchScreenState();
}

class _DonorSearchScreenState extends State<DonorSearchScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Multi-select blood groups
  Set<String> _selectedGroups = {};
  String _cityFilter = '';
  bool _isLoading = false;
  List<UserModel> _results = [];
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      _cityFilter = user.city ?? '';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  Future<void> _search() async {
    setState(() { _isLoading = true; _hasSearched = true; });
    try {
      // If groups selected, search those; else search all
      final groups = _selectedGroups.isNotEmpty ? _selectedGroups.toList() : null;
      var donors = await _firestoreService.searchDonors(
        bloodGroup: groups != null && groups.length == 1 ? groups.first : null,
        city: _cityFilter.isNotEmpty ? _cityFilter : null,
        country: 'Pakistan',
      );

      // Client-side filter for multi-group selection
      if (groups != null && groups.length > 1) {
        donors = donors.where((d) => groups.contains(d.bloodGroup)).toList();
      }

      // Filter out current user, non-donors, and donors on cooldown
      if (!mounted) return;
      final myUid = context.read<AuthProvider>().userModel?.uid;
      final now = DateTime.now();
      donors = donors.where((d) {
        if (d.uid == myUid || d.role != 'donor') return false;
        // Check cooldown
        if (d.cooldownUntil != null && d.cooldownUntil!.isAfter(now)) return false;
        return true;
      }).toList();

      setState(() { _results = donors; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  void _suggestCompatibleGroups(String bg) {
    final compat = NotificationService.getCompatibleGroups(bg);
    setState(() {
      _selectedGroups = compat.toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── Header ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(
                  colors: [AppTheme.darkBg, AppTheme.primaryRedDark, AppTheme.primaryRed],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(60, 0, 20, 16),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Find Donors', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Search available donors in Pakistan', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                  ]),
                )),
              ),
            ),
          ),

          // ─── Filters ──────────────────────────────────────────────────
          SliverToBoxAdapter(child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // City filter
              _filterLabel('City', Icons.location_city_rounded, const Color(0xFF2E7D32)),
              const SizedBox(height: 10),
              TextField(
                controller: TextEditingController(text: _cityFilter),
                onChanged: (v) => _cityFilter = v,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white : AppTheme.textDark),
                decoration: InputDecoration(
                  hintText: 'Enter city name',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkCard : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1.2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryRed, width: 2)),
                ),
              ),
              const SizedBox(height: 16),

              // Blood group multi-select
              _filterLabel('Blood Groups (tap to multi-select)', Icons.water_drop_rounded, AppTheme.primaryRed),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _bgChip(isDark, 'All', _selectedGroups.isEmpty, () => setState(() => _selectedGroups.clear())),
                ...AppConstants.bloodGroups.map((bg) => GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedGroups.contains(bg)) {
                        _selectedGroups.remove(bg);
                      } else {
                        _selectedGroups.add(bg);
                      }
                    });
                  },
                  onLongPress: () => _suggestCompatibleGroups(bg),
                  child: _bgChipWidget(isDark, bg, _selectedGroups.contains(bg)),
                )),
              ]),
              if (_selectedGroups.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('💡 Long press a blood group to auto-select compatible donors',
                      style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
                ),
              const SizedBox(height: 16),

              // Search button
              GestureDetector(
                onTap: _isLoading ? null : _search,
                child: Container(
                  width: double.infinity, height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primaryRed, AppTheme.primaryRedLight]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 5))],
                  ),
                  child: Center(child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.search_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Search Donors', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        ])),
                ),
              ),
            ]),
          )),

          // ─── Results count ─────────────────────────────────────────────
          if (_hasSearched && !_isLoading)
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(children: [
                Container(width: 4, height: 16, margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: const LinearGradient(colors: [AppTheme.primaryRed, AppTheme.primaryRedLight]))),
                Text('${_results.length} donor${_results.length != 1 ? 's' : ''} found${_cityFilter.isNotEmpty ? ' in $_cityFilter' : ''}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textDark)),
              ]),
            )),

          // ─── Results ───────────────────────────────────────────────────
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (!_hasSearched)
            SliverFillRemaining(child: _placeholderState(isDark))
          else if (_results.isEmpty)
            SliverFillRemaining(child: _emptyState(isDark))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (context, index) => _donorCard(isDark, _results[index]),
                childCount: _results.length,
              )),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FILTER WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _filterLabel(String text, IconData icon, Color accent) => Row(children: [
    Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 14, color: accent)),
    const SizedBox(width: 8),
    Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textDark)),
  ]);

  Widget _bgChip(bool isDark, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: _bgChipWidget(isDark, label, isSelected));
  }

  Widget _bgChipWidget(bool isDark, String label, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: isSelected ? const LinearGradient(colors: [AppTheme.primaryRed, AppTheme.primaryRedLight]) : null,
        color: isSelected ? null : (isDark ? AppTheme.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: isSelected ? null : Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1.2),
        boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : [],
      ),
      child: Text(label, style: TextStyle(
        fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : (isDark ? AppTheme.textSecondary : AppTheme.textDarkSecondary),
      )),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DONOR CARD — Tappable, shows mini info
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _donorCard(bool isDark, UserModel donor) {
    final isMale = (donor.gender ?? '').toLowerCase() != 'female';
    final isAvailable = donor.isAvailable;

    return GestureDetector(
      onTap: () => _showDonorProfile(isDark, donor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAvailable ? const Color(0xFF66BB6A).withValues(alpha: 0.3) : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.04 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          // Avatar
          Stack(children: [
            CircleAvatar(radius: 24,
              backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.1),
              backgroundImage: donor.profileImageUrl != null ? NetworkImage(donor.profileImageUrl!)
                  : AssetImage(isMale ? 'assets/images/avatar_male.png' : 'assets/images/avatar_female.png')),
            if (isAvailable) Positioned(bottom: 0, right: 0,
              child: Container(width: 14, height: 14,
                decoration: BoxDecoration(color: const Color(0xFF66BB6A), shape: BoxShape.circle,
                  border: Border.all(color: isDark ? AppTheme.darkCard : Colors.white, width: 2)))),
          ]),
          const SizedBox(width: 14),

          // Blood badge
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primaryRed, AppTheme.primaryRedLight]),
              borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(donor.bloodGroup, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)))),
          const SizedBox(width: 14),

          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(donor.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            if (donor.city != null) Row(children: [
              Icon(Icons.location_on_rounded, size: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
              const SizedBox(width: 2),
              Text(donor.city!, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
            ]),
            if (donor.donationCount > 0)
              Padding(padding: const EdgeInsets.only(top: 3),
                child: Text('${donor.donationCount} donation${donor.donationCount != 1 ? 's' : ''} • ${donor.donorLevel}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primaryRed.withValues(alpha: 0.7)))),
          ])),

          // Arrow indicator
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DONOR PROFILE POPUP — Full info + contact buttons
  // ═══════════════════════════════════════════════════════════════════════════
  void _showDonorProfile(bool isDark, UserModel donor) {
    final isMale = (donor.gender ?? '').toLowerCase() != 'female';
    final isAvailable = donor.isAvailable;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: Column(children: [
              // Handle bar
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),

              // Avatar + Name
              CircleAvatar(radius: 40,
                backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.1),
                backgroundImage: donor.profileImageUrl != null ? NetworkImage(donor.profileImageUrl!)
                    : AssetImage(isMale ? 'assets/images/avatar_male.png' : 'assets/images/avatar_female.png')),
              const SizedBox(height: 12),
              Text(donor.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Wrap(spacing: 8, children: [
                _profileChip('🩸 ${donor.bloodGroup}', AppTheme.primaryRed),
                _profileChip(isAvailable ? '🟢 Available' : '🔴 Offline',
                    isAvailable ? const Color(0xFF66BB6A) : AppTheme.warning),
                _profileChip('${donor.donorLevelEmoji} ${donor.donorLevel}', AppTheme.primaryRed),
              ]),

              const SizedBox(height: 20),

              // Stats row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(18)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _profileStat('${donor.donationCount}', 'Donations'),
                  Container(width: 1, height: 28, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  _profileStat(donor.lastDonationDate != null ? DateFormat('MMM yyyy').format(donor.lastDonationDate!) : 'Never', 'Last Donated'),
                  Container(width: 1, height: 28, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  _profileStat(donor.city ?? '—', 'City'),
                ]),
              ),

              const SizedBox(height: 16),

              // Health info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Health Info', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textDark)),
                  const SizedBox(height: 12),
                  _infoRow('Blood Group', donor.bloodGroup),
                  if (donor.age != null) _infoRow('Age', '${donor.age} years'),
                  if (donor.weight != null) _infoRow('Weight', '${donor.weight} kg'),
                  if (donor.hemoglobin != null) _infoRow('Hemoglobin', '${donor.hemoglobin} g/dL'),
                  if (donor.gender != null) _infoRow('Gender', donor.gender!),
                  _infoRow('Eligible', (donor.isEligible ?? false) ? '✅ Yes' : '❌ No'),
                ]),
              ),

              const SizedBox(height: 20),

              // Contact buttons
              Row(children: [
                Expanded(child: _contactButton(
                  icon: Icons.phone_rounded,
                  label: 'Call',
                  color: const Color(0xFF2E7D32),
                  onTap: () => _launchUrl('tel:${donor.mobile}'),
                )),
                const SizedBox(width: 10),
                Expanded(child: _contactButton(
                  icon: Icons.message_rounded,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () {
                    final number = (donor.whatsappNumber ?? donor.mobile).replaceAll(RegExp(r'[^0-9+]'), '');
                    _launchUrl('https://wa.me/$number');
                  },
                )),
              ]),

              const SizedBox(height: 12),

              // Send Request button
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  await _sendRequestToDonor(donor);
                },
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    gradient: AppTheme.buttonGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))]),
                  child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Send Blood Request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ])),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _profileChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );

  Widget _profileStat(String value, String label) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
  ]);

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _contactButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ])),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _sendRequestToDonor(UserModel donor) async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;

    try {
      final request = BloodRequestModel(
        id: '',
        recipientId: user.uid,
        recipientName: user.name,
        bloodGroup: user.bloodGroup,
        urgency: 'Urgent',
        hospitalName: null,
        notes: 'Direct request to ${donor.name}',
        unitsNeeded: 1,
        contactNumber: user.mobile,
        city: user.city,
        country: user.country ?? 'Pakistan',
        location: user.location,
      );

      final requestId = await _firestoreService.createBloodRequest(request);

      // Send notification to donor — NOT a chat session
      // Chat is created when the DONOR accepts from their side
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': donor.uid,
        'title': '🩸 ${user.bloodGroup} Blood Request',
        'body': '${user.name} needs ${user.bloodGroup} blood. Tap to respond.',
        'type': 'request',
        'isRead': false,
        'requestId': requestId,
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Request sent to ${donor.name}! They will be notified.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }



  // ═══════════════════════════════════════════════════════════════════════════
  //  EMPTY / PLACEHOLDER STATES
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _placeholderState(bool isDark) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.06), shape: BoxShape.circle),
      child: Icon(Icons.search_rounded, size: 48, color: AppTheme.primaryRed.withValues(alpha: 0.4))),
    const SizedBox(height: 16),
    Text('Search for Donors', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    Text('Use the filters above to find\ncompatible donors near you', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary, height: 1.5)),
  ]));

  Widget _emptyState(bool isDark) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.06), shape: BoxShape.circle),
      child: Icon(Icons.person_off_rounded, size: 48, color: AppTheme.warning.withValues(alpha: 0.5))),
    const SizedBox(height: 16),
    Text('No donors found', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    Text('Try adjusting your filters\nor searching in a different city', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary, height: 1.5)),
  ]));
}
