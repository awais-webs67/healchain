/// ─────────────────────────────────────────────────────────────────────────────
/// ProfileScreen — Premium profile with role-aware tabs
/// ─────────────────────────────────────────────────────────────────────────────
/// Donor Tabs: Personal Info | Health & Blood | Location | Settings
/// Recipient Tabs: Personal Info | Location | Settings
/// All fields are editable with inline edit buttons
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _updatingGps = false;

  @override
  void initState() {
    super.initState();
    final isDonor = context.read<AuthProvider>().userModel?.isDonor ?? false;
    _tabCtrl = TabController(length: isDonor ? 4 : 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateField(String field, dynamic value) async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;

    final updates = <String, dynamic>{field: value};

    // Auto-recalculate BMI when weight or height changes
    final w = field == 'weight' ? (value as num).toDouble() : user.weight;
    final h = field == 'height' ? (value as num).toDouble() : user.height;
    if ((field == 'weight' || field == 'height') && w != null && h != null && h > 0) {
      final heightM = h / 100.0;
      final bmi = w / (heightM * heightM);
      updates['bmi'] = double.parse(bmi.toStringAsFixed(1));
    }

    // Auto-recalculate eligibility when any health field changes
    if (['weight', 'height', 'age', 'hemoglobin'].contains(field)) {
      final age = field == 'age' ? (value as num).toInt() : user.age;
      final weight = field == 'weight' ? (value as num).toDouble() : user.weight;
      final hemo = field == 'hemoglobin' ? (value as num).toDouble() : user.hemoglobin;
      final bmi = updates['bmi'] as double? ?? user.bmi;
      final cooldownPassed = user.canDonateNow;

      bool eligible = true;
      if (age != null && (age < 17 || age > 65)) eligible = false;
      if (weight != null && weight < 50) eligible = false;
      if (hemo != null && hemo < 12.5) eligible = false;
      if (bmi != null && (bmi < 18.5 || bmi > 40)) eligible = false;
      if (!cooldownPassed) eligible = false;

      updates['isEligible'] = eligible;
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updates);
    if (!mounted) return;
    await context.read<AuthProvider>().refreshUserData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Updated successfully ✓'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  /// Show gender picker dialog instead of free text input
  void _showGenderPicker() {
    final user = context.read<AuthProvider>().userModel;
    final current = user?.gender ?? '';
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Select Gender', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final g in ['Male', 'Female', 'Other'])
              ListTile(
                leading: Icon(
                  g == 'Male' ? Icons.male_rounded : g == 'Female' ? Icons.female_rounded : Icons.transgender_rounded,
                  color: current.toLowerCase() == g.toLowerCase() ? AppTheme.primaryRed : (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
                ),
                title: Text(g, style: TextStyle(fontWeight: current.toLowerCase() == g.toLowerCase() ? FontWeight.w700 : FontWeight.w500)),
                trailing: current.toLowerCase() == g.toLowerCase()
                    ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryRed, size: 22)
                    : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: current.toLowerCase() == g.toLowerCase()
                    ? AppTheme.primaryRed.withValues(alpha: 0.08)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _updateField('gender', g);
                },
              ),
          ]),
        );
      },
    );
  }

  /// Fetch current GPS, reverse geocode, and update Firestore
  Future<void> _updateGpsLocation() async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;
    setState(() => _updatingGps = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled';
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) throw 'Location permission denied';
      }
      if (perm == LocationPermission.deniedForever) throw 'Location permission permanently denied';
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      // Reverse geocode
      String? city, state, country, address;
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          city = p.subAdministrativeArea ?? p.locality;
          state = p.administrativeArea;
          country = p.country;
          address = [p.street, p.subLocality, p.locality, p.administrativeArea, p.country]
              .where((e) => e != null && e.isNotEmpty).join(', ');
        }
      } catch (_) {}
      final updates = <String, dynamic>{'location': GeoPoint(pos.latitude, pos.longitude)};
      if (city != null) updates['city'] = city;
      if (state != null) updates['state'] = state;
      if (country != null) updates['country'] = country;
      if (address != null) updates['address'] = address;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updates);
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('📍 Location updated from GPS!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _updatingGps = false);
  }

  /// Strip display suffixes ("23 years", "65.0 kg", "170 cm", "14.5 g/dL") to get raw value
  String _stripDisplaySuffix(String val) {
    return val
        .replaceAll(RegExp(r'\s*(years?|kg|cm|g/dL)\s*$', caseSensitive: false), '')
        .trim();
  }

  void _showEditDialog(String title, String field, String currentVal, {TextInputType keyboardType = TextInputType.text}) {
    // Strip unit suffixes for numeric fields so user sees just the number
    final cleanVal = keyboardType == TextInputType.number ? _stripDisplaySuffix(currentVal) : currentVal;
    final ctrl = TextEditingController(text: cleanVal);
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit $title', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          content: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter $title',
              filled: true,
              fillColor: isDark ? AppTheme.darkSurface : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryRed, width: 1.5)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final raw = ctrl.text.trim();
                if (raw.isEmpty) return;
                dynamic val;
                if (keyboardType == TextInputType.number) {
                  // Try int first, then double, fall back to string
                  final doubleFields = ['weight', 'height', 'hemoglobin', 'bmi'];
                  if (doubleFields.contains(field)) {
                    val = double.tryParse(raw) ?? raw;
                  } else {
                    val = int.tryParse(raw) ?? raw;
                  }
                } else {
                  val = raw;
                }
                _updateField(field, val);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxScrolled) => [
          // Profile header
          SliverToBoxAdapter(child: _profileHeader(isDark, user)),
          // Tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabBar: TabBar(
                controller: _tabCtrl,
                labelColor: AppTheme.primaryRed,
                unselectedLabelColor: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                indicatorColor: AppTheme.primaryRed,
                indicatorWeight: 3,
                dividerColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                tabs: user.isDonor
                    ? const [
                        Tab(text: 'Personal'),
                        Tab(text: 'Health'),
                        Tab(text: 'Location'),
                        Tab(text: 'Settings'),
                      ]
                    : const [
                        Tab(text: 'Personal'),
                        Tab(text: 'Location'),
                        Tab(text: 'Settings'),
                      ],
              ),
              isDark: isDark,
            ),
          ),
        ],
        body: TabBarView(controller: _tabCtrl, children: user.isDonor
            ? [
                _personalTab(isDark, user),
                _healthTab(isDark, user),
                _locationTab(isDark, user),
                _settingsTab(isDark, user),
              ]
            : [
                _personalTab(isDark, user),
                _locationTab(isDark, user),
                _settingsTab(isDark, user),
              ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PROFILE HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _profileHeader(bool isDark, UserModel user) {
    final isDonor = user.isDonor;
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradientFor(isDark),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(children: [
            // Top actions
            Row(children: [
              GestureDetector(
                onTap: () => context.go(AppRoutes.home),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push(AppRoutes.settings),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // Avatar
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
              ),
              child: CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                backgroundImage: user.profileImageUrl != null
                    ? NetworkImage(user.profileImageUrl!)
                    : AssetImage((user.gender ?? '').toLowerCase() == 'female'
                        ? 'assets/images/avatar_female.png'
                        : 'assets/images/avatar_male.png'),
              ),
            ),
            const SizedBox(height: 12),
            Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            Text(user.email, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
            const SizedBox(height: 10),
            // Chips
            Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
              if (user.bloodGroup.isNotEmpty) _chip('🩸 ${user.bloodGroup}'),
              if (isDonor) ...[
                _chip('${user.donorLevelEmoji} ${user.donorLevel}'),
                _chip(user.isAvailable ? '🟢 Available' : '🔴 Offline'),
              ] else ...[
                _chip(user.recipientType == 'hospital' ? '🏥 Hospital'
                    : user.recipientType == 'welfare_org' ? '🏥 Welfare Org'
                    : '👤 Recipient'),
              ],
            ]),
            // Donor stats row (only for donors)
            if (isDonor) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _headerStat('${user.donationCount}', 'Donations'),
                  Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.15)),
                  _headerStat('${user.points}', 'Points'),
                  Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.15)),
                  _headerStat('${user.profileCompletionScore}%', 'Profile'),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _chip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
  );

  Widget _headerStat(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
    const SizedBox(height: 2),
    Text(l, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6))),
  ]);

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 1: PERSONAL INFO
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _personalTab(bool isDark, UserModel user) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      _sectionTitle('Basic Information'),
      _editableField(isDark, Icons.person_rounded, 'Full Name', user.name, 'name'),
      _infoField(isDark, Icons.email_rounded, 'Email', user.email),
      _editableField(isDark, Icons.phone_rounded, 'Mobile', user.mobile, 'mobile'),
      _editableField(isDark, Icons.message_rounded, 'WhatsApp', user.whatsappNumber ?? 'Not set', 'whatsappNumber'),
      _pickerField(isDark, Icons.wc_rounded, 'Gender', user.gender ?? 'Not set', _showGenderPicker),
      // Donor-only: age
      if (user.isDonor)
        _editableField(isDark, Icons.cake_rounded, 'Age', user.age != null ? '${user.age} years' : 'Not set', 'age', keyboardType: TextInputType.number),
      // Recipient-only: recipient type and org name
      if (!user.isDonor) ...[
        const SizedBox(height: 20),
        _sectionTitle('Recipient Details'),
        _infoField(isDark, Icons.category_rounded, 'Recipient Type',
            user.recipientType == 'hospital' ? 'Hospital'
            : user.recipientType == 'welfare_org' ? 'Welfare Organization'
            : user.recipientType == 'other' ? 'Other Organization'
            : 'Individual'),
        if (user.organizationName != null && user.organizationName!.isNotEmpty)
          _editableField(isDark, Icons.business_rounded, 'Organization Name', user.organizationName!, 'organizationName'),
        if (user.bloodGroup.isNotEmpty)
          _infoField(isDark, Icons.water_drop_rounded, 'Blood Group', user.bloodGroup, color: AppTheme.primaryRed),
      ],
      const SizedBox(height: 20),
      _sectionTitle('Account'),
      _infoField(isDark, Icons.badge_rounded, 'Role', user.role.toUpperCase()),
      _infoField(isDark, Icons.calendar_today_rounded, 'Joined', DateFormat('MMM dd, yyyy').format(user.createdAt)),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 2: HEALTH & BLOOD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _healthTab(bool isDark, UserModel user) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      _sectionTitle('Blood Information'),
      _infoField(isDark, Icons.water_drop_rounded, 'Blood Group', user.bloodGroup, color: AppTheme.primaryRed),
      _infoField(isDark, Icons.check_circle_rounded, 'Eligibility',
          (user.isEligible ?? false) ? '✅ Eligible to Donate' : '❌ Not Eligible',
          color: (user.isEligible ?? false) ? AppTheme.success : AppTheme.error),
      if (user.lastDonationDate != null)
        _infoField(isDark, Icons.event_rounded, 'Last Donation', DateFormat('MMM dd, yyyy').format(user.lastDonationDate!)),
      if (user.nextDonationDate != null && user.daysUntilNextDonation > 0)
        _infoField(isDark, Icons.schedule_rounded, 'Next Eligible', '${DateFormat('MMM dd, yyyy').format(user.nextDonationDate!)} (${user.daysUntilNextDonation} days)'),
      const SizedBox(height: 20),
      _sectionTitle('Health Metrics'),
      _editableField(isDark, Icons.monitor_weight_rounded, 'Weight', user.weight != null ? '${user.weight!.toStringAsFixed(1)} kg' : 'Not set', 'weight', keyboardType: TextInputType.number),
      _editableField(isDark, Icons.height_rounded, 'Height', user.height != null ? '${user.height!.toStringAsFixed(0)} cm' : 'Not set', 'height', keyboardType: TextInputType.number),
      _infoField(isDark, Icons.speed_rounded, 'BMI', user.bmi != null ? user.bmi!.toStringAsFixed(1) : 'Not calculated'),
      _editableField(isDark, Icons.science_rounded, 'Hemoglobin', user.hemoglobin != null ? '${user.hemoglobin!.toStringAsFixed(1)} g/dL' : 'Not set', 'hemoglobin', keyboardType: TextInputType.number),
      const SizedBox(height: 20),
      _sectionTitle('Rewards'),
      _infoField(isDark, Icons.emoji_events_rounded, 'Level', '${user.donorLevelEmoji} ${user.donorLevel}'),
      _infoField(isDark, Icons.stars_rounded, 'Points', '${user.points} pts'),
      _infoField(isDark, Icons.water_drop_rounded, 'Total Donations', '${user.donationCount}'),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 3: LOCATION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _locationTab(bool isDark, UserModel user) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      // GPS Update button
      GestureDetector(
        onTap: _updatingGps ? null : _updateGpsLocation,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: _updatingGps
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.my_location_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_updatingGps ? 'Updating...' : 'Update via GPS', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('Auto-detect your current location', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
            ])),
            Icon(Icons.gps_fixed_rounded, color: Colors.white.withValues(alpha: 0.6), size: 22),
          ]),
        ),
      ),

      _sectionTitle('Current Location'),
      _editableField(isDark, Icons.flag_rounded, 'Country', user.country ?? 'Not set', 'country'),
      _editableField(isDark, Icons.map_rounded, 'Province', user.state ?? 'Not set', 'state'),
      _editableField(isDark, Icons.location_city_rounded, 'City', user.city ?? 'Not set', 'city'),
      _editableField(isDark, Icons.home_rounded, 'Address', user.address ?? 'Not set', 'address'),
      if (user.location != null) ...[
        const SizedBox(height: 20),
        _sectionTitle('GPS Coordinates'),
        _infoField(isDark, Icons.gps_fixed_rounded, 'Latitude', user.location!.latitude.toStringAsFixed(6)),
        _infoField(isDark, Icons.gps_fixed_rounded, 'Longitude', user.location!.longitude.toStringAsFixed(6)),
      ],
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 4: SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _settingsTab(bool isDark, UserModel user) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      _sectionTitle('Preferences'),
      if (user.isDonor) ...[
        // Cooldown-aware availability toggle
        Builder(builder: (_) {
          final isOnCooldown = user.cooldownUntil != null && user.cooldownUntil!.isAfter(DateTime.now());
          final daysLeft = isOnCooldown ? user.cooldownUntil!.difference(DateTime.now()).inDays : 0;
          if (isOnCooldown) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.timer_rounded, color: AppTheme.warning, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Cooldown Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.warning)),
                  Text('Wait $daysLeft days before donating', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
                ])),
                Switch.adaptive(value: false, onChanged: null, activeThumbColor: AppTheme.success),
              ]),
            );
          }
          return _toggleField(isDark, Icons.volunteer_activism_rounded, 'Available to Donate', user.isAvailable, (v) => _updateField('isAvailable', v));
        }),
      ],
      _toggleField(isDark, Icons.notifications_rounded, 'Push Notifications', user.notificationsEnabled, (v) => _updateField('notificationsEnabled', v)),
      _toggleField(isDark, Icons.dark_mode_rounded, 'Dark Mode', user.darkMode, (v) {
        _updateField('darkMode', v);
        final themeProvider = context.read<ThemeProvider>();
        if (themeProvider.isDarkMode != v) {
          themeProvider.toggleTheme();
        }
      }),

      const SizedBox(height: 24),
      _sectionTitle('Account Actions'),

      if (user.isAdmin) ...[
        _actionBtn(isDark, Icons.admin_panel_settings_rounded, 'Admin Panel', 'Manage app settings', const Color(0xFF7C3AED),
            () => context.push(AppRoutes.adminDashboard)),
        const SizedBox(height: 10),
      ],

      _actionBtn(isDark, Icons.logout_rounded, 'Sign Out', 'Log out of your account', AppTheme.error, () async {
        await context.read<AuthProvider>().signOut();
        if (mounted) context.go(AppRoutes.login);
      }),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  REUSABLE WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primaryRed, letterSpacing: 0.5)),
  );

  Widget _editableField(bool isDark, IconData ic, String label, String value, String field, {TextInputType keyboardType = TextInputType.text}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(ic, color: AppTheme.primaryRed, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ])),
        GestureDetector(
          onTap: () => _showEditDialog(label, field, value == 'Not set' ? '' : value, keyboardType: keyboardType),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.primaryRed),
          ),
        ),
      ]),
    );
  }

  /// Field with a dropdown/picker instead of text input (e.g. Gender)
  Widget _pickerField(bool isDark, IconData ic, String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(ic, color: AppTheme.primaryRed, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ])),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.expand_more_rounded, size: 16, color: AppTheme.primaryRed),
          ),
        ]),
      ),
    );
  }

  Widget _infoField(bool isDark, IconData ic, String label, String value, {Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: (color ?? AppTheme.info).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(ic, color: color ?? AppTheme.info, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ])),
      ]),
    );
  }

  Widget _toggleField(bool isDark, IconData ic, String label, bool val, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(ic, color: AppTheme.primaryRed, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        Switch.adaptive(value: val, onChanged: onChanged, activeThumbColor: AppTheme.success),
      ]),
    );
  }

  Widget _actionBtn(bool isDark, IconData ic, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(ic, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
          ])),
          Icon(Icons.chevron_right_rounded, color: color, size: 22),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Persistent tab bar delegate
// ═══════════════════════════════════════════════════════════════════════════
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;
  _TabBarDelegate({required this.tabBar, required this.isDark});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
