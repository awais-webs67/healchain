/// ─────────────────────────────────────────────────────────────────────────────
/// RecipientSignupScreen — 3-step signup flow for blood recipients
/// ─────────────────────────────────────────────────────────────────────────────
/// Step 1: Recipient Type + Org Details
/// Step 2: Personal Info (name, phone, WhatsApp)
/// Step 3: Location + Review & Submit
/// ─────────────────────────────────────────────────────────────────────────────
/// Blood group NOT collected at signup — selected when creating requests.
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
import '../../config/routes.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/location_picker_widget.dart';
import '../../services/location_service.dart';

class RecipientSignupScreen extends StatefulWidget {
  final String recipientType;
  const RecipientSignupScreen({super.key, required this.recipientType});

  @override
  State<RecipientSignupScreen> createState() => _RecipientSignupScreenState();
}

class _RecipientSignupScreenState extends State<RecipientSignupScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 3;

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  final _orgNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  bool _sameAsPhone = true;

  String? _selectedCountry;
  String? _selectedState;
  String? _selectedCity;
  final _addressController = TextEditingController();
  GeoPoint? _geoPoint;
  bool _isLocating = false;

  bool _isSubmitting = false;
  static const _accent = Color(0xFF1E88E5);

  bool get _isOrg => widget.recipientType == 'hospital' || widget.recipientType == 'welfare_org';

  String get _typeLabel {
    switch (widget.recipientType) {
      case 'hospital': return 'Hospital';
      case 'welfare_org': return 'Welfare Organization';
      case 'other': return 'Other Organization';
      default: return 'Individual';
    }
  }

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _nameController.text = user.displayName ?? '';
  }

  @override
  void dispose() {
    _pageController.dispose(); _orgNameController.dispose();
    _nameController.dispose(); _phoneController.dispose();
    _whatsappController.dispose(); _addressController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: if (_isOrg) return _step1Key.currentState?.validate() ?? false; return true;
      case 1: return _step2Key.currentState?.validate() ?? false;
      default: return true;
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services disabled. Please enable GPS.');
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) { _showError('Location permission denied'); setState(() => _isLocating = false); return; }
      }
      if (perm == LocationPermission.deniedForever) { _showError('Permission permanently denied.'); setState(() => _isLocating = false); return; }

      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      _geoPoint = GeoPoint(pos.latitude, pos.longitude);
      final pms = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (pms.isNotEmpty) {
        final p = pms.first;
        final locationService = LocationService();
        final resolved = locationService.resolveGpsLocation(
          country: p.country, adminArea: p.administrativeArea,
          locality: p.locality, subLocality: p.subLocality,
          subAdminArea: p.subAdministrativeArea, street: p.street,
        );
        setState(() {
          _selectedCountry = resolved['country'];
          _selectedState = resolved['province'];
          _selectedCity = resolved['city'];
          _addressController.text = resolved['address'] ?? '';
        });
      }
    } catch (_) { _showError('Could not detect location. Select manually.'); }
    setState(() => _isLocating = false);
  }

  int _getProfileScore() {
    return UserModel.calculateProfileScore(
      role: 'recipient', name: _nameController.text.trim(), mobile: _phoneController.text.trim(),
      bloodGroup: '', whatsappNumber: _sameAsPhone ? _phoneController.text.trim() : _whatsappController.text.trim(),
      city: _selectedCity ?? '', country: _selectedCountry ?? '', address: _addressController.text.trim(),
      recipientType: widget.recipientType, organizationName: _orgNameController.text.trim(),
    );
  }

  Future<void> _submitSignup() async {
    setState(() => _isSubmitting = true);
    final fUser = FirebaseAuth.instance.currentUser;
    if (fUser == null) { _showError('Session expired.'); setState(() => _isSubmitting = false); return; }

    try {
      final userData = UserModel(
        uid: fUser.uid, email: fUser.email ?? '', name: _nameController.text.trim(),
        mobile: _phoneController.text.trim(), bloodGroup: '', role: 'recipient',
        recipientType: widget.recipientType,
        organizationName: _isOrg ? _orgNameController.text.trim() : null,
        whatsappNumber: _sameAsPhone ? _phoneController.text.trim() : _whatsappController.text.trim(),
        location: _geoPoint, address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        city: _selectedCity, state: _selectedState, country: _selectedCountry,
        profileCompletionScore: _getProfileScore(),
      );

      final ok = await context.read<AuthProvider>().completeProfile(userData);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (ok) { context.go(AppRoutes.home); }
      else { _showError(context.read<AuthProvider>().error ?? 'Failed. Try again.'); }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError('Error: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(body: SafeArea(child: Column(children: [
      _buildTopBar(isDark),
      Expanded(child: PageView(controller: _pageController, physics: const NeverScrollableScrollPhysics(), children: [
        _buildStep1OrgDetails(isDark), _buildStep2Personal(isDark), _buildStep3LocationReview(isDark),
      ])),
      _buildBottomButtons(isDark),
    ])));
  }

  Widget _buildTopBar(bool isDark) {
    final labels = ['Type', 'Personal', 'Location'];
    return Padding(padding: const EdgeInsets.fromLTRB(8, 8, 16, 0), child: Column(children: [
      Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: _currentStep > 0 ? _prevStep : () => Navigator.pop(context)),
        const SizedBox(width: 4),
        Text('Recipient Registration', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
          child: Text('${_currentStep + 1}/$_totalSteps', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _accent))),
      ]),
      const SizedBox(height: 12),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Row(
        children: List.generate(_totalSteps, (i) {
          final active = i <= _currentStep; final cur = i == _currentStep;
          return Expanded(child: Column(children: [
            Row(children: [
              if (i > 0) Expanded(child: Container(height: 2.5, color: active ? _accent : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder))),
              Container(width: cur ? 10 : 8, height: cur ? 10 : 8, decoration: BoxDecoration(shape: BoxShape.circle,
                  color: active ? _accent : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  border: cur ? Border.all(color: _accent.withValues(alpha: 0.3), width: 3) : null)),
              if (i < _totalSteps - 1) Expanded(child: Container(height: 2.5, color: i < _currentStep ? _accent : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder))),
            ]),
            const SizedBox(height: 4),
            Text(labels[i], style: TextStyle(fontSize: 10, fontWeight: cur ? FontWeight.w700 : FontWeight.w500,
                color: cur ? _accent : (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
          ]));
        }),
      )),
      const SizedBox(height: 8),
    ]));
  }

  // ══ STEP 1 ════════════════════════════════════════════════════════════
  Widget _buildStep1OrgDetails(bool isDark) {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Form(key: _step1Key,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader(_isOrg ? Icons.business_rounded : Icons.person_rounded, 'Registering as $_typeLabel',
            _isOrg ? 'Tell us about your organization' : 'You\'re signing up as an individual recipient'),
        const SizedBox(height: 28),
        Container(width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_accent.withValues(alpha: 0.08), _accent.withValues(alpha: 0.02)]),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd), border: Border.all(color: _accent.withValues(alpha: 0.2))),
          child: Row(children: [
            Text(_getTypeEmoji(), style: const TextStyle(fontSize: 32)), const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_typeLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _accent)),
              const SizedBox(height: 2),
              Text(_getTypeDescription(), style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
            ])),
          ])),
        if (_isOrg) ...[
          const SizedBox(height: 24),
          TextFormField(controller: _orgNameController,
            validator: (v) => Validators.validateRequired(v, 'Organization name'),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: widget.recipientType == 'hospital' ? 'Hospital Name' : 'Organization Name',
              hintText: widget.recipientType == 'hospital' ? 'e.g. City General Hospital' : 'e.g. Red Crescent Society',
              prefixIcon: const Icon(Icons.business_outlined))),
        ],
        if (!_isOrg) ...[
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.success, size: 20), const SizedBox(width: 10),
              Expanded(child: Text('As an individual, you can create blood requests and find donors near you.',
                  style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textSecondary : AppTheme.textDarkSecondary))),
            ])),
        ],
      ])));
  }

  // ══ STEP 2 ════════════════════════════════════════════════════════════
  Widget _buildStep2Personal(bool isDark) {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Form(key: _step2Key,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader(Icons.person_outline_rounded, _isOrg ? 'Contact Person' : 'Personal Information',
            _isOrg ? 'Person managing blood requests' : 'Tell us about yourself'),
        const SizedBox(height: 28),
        TextFormField(controller: _nameController, validator: Validators.validateName,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: _isOrg ? 'Contact Person' : 'Full Name',
                hintText: 'Enter full name', prefixIcon: const Icon(Icons.badge_outlined))),
        const SizedBox(height: 16),
        TextFormField(controller: _phoneController, validator: Validators.validateMobile, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone Number', hintText: '+92 300 1234567', prefixIcon: Icon(Icons.phone_outlined))),
        const SizedBox(height: 16),
        Row(children: [
          Checkbox(value: _sameAsPhone, onChanged: (v) => setState(() => _sameAsPhone = v ?? true),
              activeColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
          Flexible(child: Text('WhatsApp same as phone', style: Theme.of(context).textTheme.bodyMedium)),
        ]),
        if (!_sameAsPhone) ...[
          const SizedBox(height: 8),
          TextFormField(controller: _whatsappController, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'WhatsApp Number', hintText: '+92 300 1234567', prefixIcon: Icon(Icons.message_outlined))),
        ],
      ])));
  }

  // ══ STEP 3: Location + Review ═════════════════════════════════════════
  Widget _buildStep3LocationReview(bool isDark) {
    final score = _getProfileScore();
    return SingleChildScrollView(padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader(Icons.location_on_outlined, 'Location & Review', _isOrg ? 'Where is your organization?' : 'Helps us find donors near you'),
        const SizedBox(height: 28),

        // GPS
        SizedBox(width: double.infinity, height: 54, child: OutlinedButton.icon(
          onPressed: _isLocating ? null : _detectLocation,
          icon: _isLocating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded),
          label: Text(_isLocating ? 'Detecting...' : 'Auto-detect location'),
          style: OutlinedButton.styleFrom(foregroundColor: _accent, side: BorderSide(color: _accent.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd))),
        )),

        if (_addressController.text.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.3))),
            child: Row(children: [const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20), const SizedBox(width: 10),
              Expanded(child: Text(_addressController.text, style: const TextStyle(fontSize: 13)))])),
        ],

        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Divider(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('OR SELECT MANUALLY', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary, letterSpacing: 1))),
          Expanded(child: Divider(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
        ]),
        const SizedBox(height: 20),

        // Location Picker Widget
        LocationPickerWidget(
          initialCountry: _selectedCountry,
          initialState: _selectedState,
          initialCity: _selectedCity,
          onCountryChanged: (v) => setState(() { _selectedCountry = v; _selectedState = null; _selectedCity = null; }),
          onStateChanged: (v) => setState(() => _selectedState = v),
          onCityChanged: (v) => setState(() => _selectedCity = v),
        ),

        const SizedBox(height: 28),

        // Review summary
        Container(width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _accent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: _accent.withValues(alpha: 0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.fact_check_outlined, color: _accent, size: 18), const SizedBox(width: 8),
              const Text('Profile Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: score >= 80 ? AppTheme.success.withValues(alpha: 0.15) : _accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$score%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: score >= 80 ? AppTheme.success : _accent))),
            ]),
            const SizedBox(height: 12),
            if (_isOrg) _miniRow(_typeLabel, _orgNameController.text),
            _miniRow('Name', _nameController.text),
            _miniRow('Phone', _phoneController.text),
            if (_selectedCity != null && _selectedCity!.isNotEmpty)
              _miniRow('Location', [_selectedCity, _selectedCountry].where((e) => e != null && e.isNotEmpty).join(', ')),
          ])),

        const SizedBox(height: 12),
        Center(child: Text('Blood group will be selected when creating a request.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
      ]));
  }

  Widget _miniRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
      SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
      Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    ]));
  }

  Widget _stepHeader(IconData icon, String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: _accent, size: 24)),
      const SizedBox(height: 14),
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? AppTheme.textSecondary : AppTheme.textDarkSecondary)),
    ]);
  }

  Widget _buildBottomButtons(bool isDark) {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkBg : Colors.white,
          border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 0.5))),
      child: Row(children: [
        if (_currentStep > 0) Expanded(child: SizedBox(height: 52, child: OutlinedButton(
            onPressed: _prevStep, child: const Text('Back', style: TextStyle(fontSize: 15))))),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(flex: 2, child: SizedBox(height: 52, child: ElevatedButton(
          onPressed: _isSubmitting ? null : isLast ? _submitSignup : _nextStep,
          child: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : FittedBox(fit: BoxFit.scaleDown, child: Text(isLast ? 'Save Profile' : 'Next',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
        ))),
      ]),
    );
  }

  String _getTypeEmoji() {
    switch (widget.recipientType) { case 'hospital': return '🏥'; case 'welfare_org': return '🤝'; case 'other': return '📋'; default: return '👤'; }
  }

  String _getTypeDescription() {
    switch (widget.recipientType) {
      case 'hospital': return 'Hospital or medical center requesting blood';
      case 'welfare_org': return 'Welfare or charity organization collecting donations';
      case 'other': return 'Other organization involved in blood donation';
      default: return 'Looking for blood donors for personal needs';
    }
  }
}
