/// ─────────────────────────────────────────────────────────────────────────────
/// CreateRequestScreen — Blood request form with compatibility + location
/// ─────────────────────────────────────────────────────────────────────────────
/// Enhancements:
///  - Patient name field
///  - City: auto-fetch from profile or manual entry
///  - Blood compatibility info banner (shows which donors will be notified)
///  - Notifies ALL compatible donors in same city
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/blood_request_model.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../providers/auth_provider.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});
  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _hospitalController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _contactController = TextEditingController();
  final _patientNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _firestoreService = FirestoreService();

  String _selectedBloodGroup = 'O+';
  String _selectedUrgency = 'Urgent';
  int _unitsNeeded = 1;
  bool _isSubmitting = false;
  bool _submitted = false;
  bool _fetchingLocation = false;
  double? _lat, _lng;
  late AnimationController _successCtrl;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      if (user.bloodGroup.isNotEmpty) _selectedBloodGroup = user.bloodGroup;
      _contactController.text = user.mobile;
      _cityController.text = user.city ?? '';
      if (user.location != null) {
        _lat = user.location!.latitude;
        _lng = user.location!.longitude;
      }
    }
    _successCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _contactController.dispose();
    _patientNameController.dispose();
    _cityController.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoFetchLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied'), backgroundColor: AppTheme.error));
        setState(() => _fetchingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      _lat = pos.latitude;
      _lng = pos.longitude;
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        // Prefer subAdministrativeArea (city/district) over locality (town/village)
        _cityController.text = pm.subAdministrativeArea ?? pm.locality ?? pm.administrativeArea ?? '';
        if (_addressController.text.isEmpty) {
          _addressController.text = [pm.street, pm.subLocality, pm.locality, pm.subAdministrativeArea, pm.administrativeArea, pm.country].whereType<String>().where((s) => s.isNotEmpty).join(', ');
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location error: $e'), backgroundColor: AppTheme.error));
    }
    if (mounted) setState(() => _fetchingLocation = false);
  }

  List<String> get _compatibleGroups => NotificationService.getCompatibleGroups(_selectedBloodGroup);

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter or auto-fetch city'), backgroundColor: AppTheme.error));
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final user = context.read<AuthProvider>().userModel;
      final city = _cityController.text.trim();
      final request = BloodRequestModel(
        id: '',
        recipientId: FirebaseAuth.instance.currentUser!.uid,
        recipientName: user?.name ?? 'Unknown',
        bloodGroup: _selectedBloodGroup,
        urgency: _selectedUrgency,
        hospitalName: _hospitalController.text.trim(),
        hospitalAddress: _addressController.text.trim(),
        notes: '${_patientNameController.text.trim().isNotEmpty ? "Patient: ${_patientNameController.text.trim()}\n" : ""}${_notesController.text.trim()}',
        unitsNeeded: _unitsNeeded,
        contactNumber: _contactController.text.trim(),
        city: city,
        country: user?.country ?? 'Pakistan',
        location: (_lat != null && _lng != null)
            ? GeoPoint(_lat!, _lng!)
            : user?.location,
      );

      final requestId = await _firestoreService.createBloodRequest(request);

      // Notify ALL compatible donors in the SAME city
      await NotificationService().notifyMatchingDonors(
        bloodGroup: _selectedBloodGroup,
        recipientName: user?.name ?? 'Someone',
        hospital: _hospitalController.text.trim(),
        requestId: requestId,
        urgency: _selectedUrgency,
        recipientId: user?.uid ?? '',
        city: city,
      );

      setState(() { _isSubmitting = false; _submitted = true; });
      _successCtrl.forward();
      Future.delayed(const Duration(seconds: 2), () { if (mounted) context.pop(); });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_submitted) return _successScreen(isDark);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            leading: IconButton(
              icon: Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18)),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(
                  colors: [Color(0xFF5C0000), Color(0xFF8B0000), AppTheme.primaryRedDark], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(60, 0, 20, 16),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Create Blood Request', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Compatible donors in your city will be alerted', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                  ]),
                )),
              ),
            ),
          ),

          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ─── Blood Group ───────────────────────────────────────────
              _sectionLabel('Blood Group Needed', Icons.water_drop_rounded, AppTheme.primaryRed),
              const SizedBox(height: 12),
              _buildBloodGroupSelector(isDark),
              const SizedBox(height: 8),
              _compatibilityInfo(isDark),
              const SizedBox(height: 20),

              // ─── Urgency ──────────────────────────────────────────────
              _sectionLabel('Urgency Level', Icons.priority_high_rounded, AppTheme.warning),
              const SizedBox(height: 12),
              _buildUrgencySelector(isDark),
              const SizedBox(height: 20),

              // ─── Units ────────────────────────────────────────────────
              _sectionLabel('Units Needed', Icons.science_rounded, const Color(0xFF5C6BC0)),
              const SizedBox(height: 12),
              _buildUnitSelector(isDark),
              const SizedBox(height: 20),

              // ─── Location ─────────────────────────────────────────────
              _sectionLabel('Location', Icons.location_on_rounded, const Color(0xFF2E7D32)),
              const SizedBox(height: 12),
              _locationSection(isDark),
              const SizedBox(height: 20),

              // ─── Hospital & Patient ───────────────────────────────────
              _sectionLabel('Hospital & Patient', Icons.local_hospital_rounded, const Color(0xFF00838F)),
              const SizedBox(height: 12),
              _premiumField(isDark, _patientNameController, 'Patient Name', Icons.person_outlined, false),
              const SizedBox(height: 10),
              _premiumField(isDark, _hospitalController, 'Hospital Name', Icons.local_hospital_outlined, true),
              const SizedBox(height: 10),
              _premiumField(isDark, _addressController, 'Hospital Address', Icons.location_on_outlined, false),
              const SizedBox(height: 10),
              _premiumField(isDark, _contactController, 'Contact Number', Icons.phone_outlined, true, keyboard: TextInputType.phone),
              const SizedBox(height: 10),
              _premiumField(isDark, _notesController, 'Additional Notes (optional)', Icons.notes_outlined, false, maxLines: 3),
              const SizedBox(height: 28),

              // ─── Summary & Submit ─────────────────────────────────────
              _requestSummary(isDark),
              const SizedBox(height: 18),
              _submitButton(isDark),
              const SizedBox(height: 20),
            ])),
          )),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  COMPATIBILITY INFO BANNER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _compatibilityInfo(bool isDark) {
    final groups = _compatibleGroups;
    if (groups.length <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isDark
            ? [const Color(0xFF1B5E20).withValues(alpha: 0.15), const Color(0xFF2E7D32).withValues(alpha: 0.08)]
            : [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF66BB6A).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2E7D32)),
        const SizedBox(width: 10),
        Expanded(child: RichText(text: TextSpan(
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : AppTheme.textDark, height: 1.4),
          children: [
            const TextSpan(text: 'Your request will also reach '),
            TextSpan(text: groups.join(', '), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
            const TextSpan(text: ' donors'),
          ],
        ))),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LOCATION SECTION — Auto-fetch or manual city
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _locationSection(bool isDark) {
    return Column(children: [
      Row(children: [
        Expanded(child: _premiumField(isDark, _cityController, 'City (required)', Icons.location_city_outlined, false)),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _fetchingLocation ? null : _autoFetchLocation,
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: _fetchingLocation ? null : const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF43A047)]),
              color: _fetchingLocation ? Colors.grey : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: const Color(0xFF2E7D32).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: _fetchingLocation
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : const Icon(Icons.my_location_rounded, color: Colors.white, size: 22),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      if (_cityController.text.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Donors in ${_cityController.text} will be notified',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
        ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STANDARD WIDGETS (unchanged from before, just cleaner)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _sectionLabel(String text, IconData icon, Color accent) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: accent)),
      const SizedBox(width: 10),
      Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textDark)),
    ]);
  }

  Widget _buildBloodGroupSelector(bool isDark) {
    return Wrap(spacing: 10, runSpacing: 10,
      children: AppConstants.bloodGroups.map((bg) {
        final isSelected = bg == _selectedBloodGroup;
        return GestureDetector(
          onTap: () => setState(() => _selectedBloodGroup = bg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: isSelected ? AppTheme.buttonGradient : null,
              color: isSelected ? null : (isDark ? AppTheme.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isSelected ? Colors.transparent : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder), width: 1.5),
              boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))]
                  : [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(bg, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textDark))),
              if (isSelected) Container(margin: const EdgeInsets.only(top: 4), width: 20, height: 3,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2))),
            ])),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUrgencySelector(bool isDark) {
    final urgencies = [
      ('Critical', AppTheme.error, Icons.warning_amber_rounded, 'Life-threatening'),
      ('Urgent', AppTheme.warning, Icons.schedule_rounded, 'Within 24 hours'),
      ('Normal', AppTheme.info, Icons.info_outline_rounded, 'Planned need'),
    ];
    return Row(
      children: urgencies.map((u) {
        final isSelected = u.$1 == _selectedUrgency;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _selectedUrgency = u.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: u.$1 != 'Normal' ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              gradient: isSelected ? LinearGradient(colors: [u.$2.withValues(alpha: 0.15), u.$2.withValues(alpha: 0.05)]) : null,
              color: isSelected ? null : (isDark ? AppTheme.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? u.$2 : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder), width: isSelected ? 2 : 1.2),
              boxShadow: isSelected ? [BoxShadow(color: u.$2.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))] : [],
            ),
            child: Column(children: [
              Icon(u.$3, size: 22, color: isSelected ? u.$2 : (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
              const SizedBox(height: 6),
              Text(u.$1, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? u.$2 : null)),
              const SizedBox(height: 2),
              Text(u.$4, style: TextStyle(fontSize: 8, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary), textAlign: TextAlign.center),
            ]),
          ),
        ));
      }).toList(),
    );
  }

  Widget _buildUnitSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1.2),
      ),
      child: Row(children: [
        Text('Units:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textDark)),
        const Spacer(),
        GestureDetector(
          onTap: _unitsNeeded > 1 ? () => setState(() => _unitsNeeded--) : null,
          child: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: _unitsNeeded > 1 ? AppTheme.primaryRed.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.remove_rounded, size: 20, color: _unitsNeeded > 1 ? AppTheme.primaryRed : Colors.grey)),
        ),
        Container(width: 50, alignment: Alignment.center,
          child: Text('$_unitsNeeded', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
        GestureDetector(
          onTap: () => setState(() => _unitsNeeded++),
          child: Container(width: 36, height: 36,
            decoration: BoxDecoration(gradient: AppTheme.buttonGradient, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.add_rounded, size: 20, color: Colors.white)),
        ),
      ]),
    );
  }

  Widget _premiumField(bool isDark, TextEditingController ctrl, String label, IconData icon, bool required, {int maxLines = 1, TextInputType? keyboard}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : AppTheme.textDark),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: isDark ? AppTheme.darkCard : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryRed, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    );
  }

  Widget _requestSummary(bool isDark) {
    final urgencyColor = _selectedUrgency == 'Critical' ? AppTheme.error : _selectedUrgency == 'Urgent' ? AppTheme.warning : AppTheme.info;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isDark ? [AppTheme.darkCard, AppTheme.darkCard] : [const Color(0xFFFFF3E0), const Color(0xFFFFF8E1)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: urgencyColor.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.summarize_rounded, size: 18, color: urgencyColor),
          const SizedBox(width: 8),
          Text('Request Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.textDark)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _summaryChip('🩸 $_selectedBloodGroup', AppTheme.primaryRed),
          _summaryChip('⚡ $_selectedUrgency', urgencyColor),
          _summaryChip('💉 $_unitsNeeded unit${_unitsNeeded != 1 ? 's' : ''}', const Color(0xFF5C6BC0)),
          if (_cityController.text.isNotEmpty) _summaryChip('📍 ${_cityController.text}', const Color(0xFF2E7D32)),
          _summaryChip('🔔 ${_compatibleGroups.length} donor groups', const Color(0xFFF57C00)),
        ]),
      ]),
    );
  }

  Widget _summaryChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
  );

  Widget _submitButton(bool isDark) {
    return GestureDetector(
      onTap: _isSubmitting ? null : _submitRequest,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          gradient: _isSubmitting ? null : AppTheme.buttonGradient,
          color: _isSubmitting ? Colors.grey : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _isSubmitting ? [] : [BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Center(child: _isSubmitting
            ? const Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Notifying compatible donors...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ])
            : const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.send_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Submit Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ])),
      ),
    );
  }

  Widget _successScreen(bool isDark) {
    final groups = _compatibleGroups;
    return Scaffold(
      body: Center(child: ScaleTransition(
        scale: CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.success.withValues(alpha: 0.15), AppTheme.success.withValues(alpha: 0.05)]),
              shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppTheme.success.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 5)]),
            child: const Icon(Icons.check_circle_rounded, size: 72, color: AppTheme.success)),
          const SizedBox(height: 24),
          const Text('Request Sent!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Notifying ${groups.join(", ")} donors in ${_cityController.text}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
          const SizedBox(height: 8),
          Text('Redirecting...', style: TextStyle(fontSize: 12, color: (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary).withValues(alpha: 0.5))),
        ]),
      )),
    );
  }
}
