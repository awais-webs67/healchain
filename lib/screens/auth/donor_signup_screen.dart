/// ─────────────────────────────────────────────────────────────────────────────
/// DonorSignupScreen — 5-step signup flow for blood donors
/// ─────────────────────────────────────────────────────────────────────────────
/// Step 1: Personal Info (name, phone, WhatsApp)
/// Step 2: Location (GPS auto-detect OR searchable country/state/city picker)
/// Step 3: Blood & Health (blood group, gender, age)
/// Step 4: Eligibility (weight, height → BMI calc, hemoglobin) — skippable
/// Step 5: Review & Submit (profile score, summary card)
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

class DonorSignupScreen extends StatefulWidget {
  const DonorSignupScreen({super.key});

  @override
  State<DonorSignupScreen> createState() => _DonorSignupScreenState();
}

class _DonorSignupScreenState extends State<DonorSignupScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  final _step1Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _step4Key = GlobalKey<FormState>();

  // Step 1: Personal Info
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  bool _sameAsPhone = true;

  // Step 2: Location
  String? _selectedCountry;
  String? _selectedState;
  String? _selectedCity;
  final _addressController = TextEditingController();
  GeoPoint? _geoPoint;
  bool _isLocating = false;

  // Step 3: Blood & Health
  String? _selectedBloodGroup;
  String? _selectedGender;
  final _ageController = TextEditingController();

  // Step 4: Eligibility (skippable)
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _hemoglobinController = TextEditingController();
  bool _eligibilitySkipped = false;

  bool _isSubmitting = false;

  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _nameController.text = user.displayName ?? '';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _hemoglobinController.dispose();
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
      case 0: return _step1Key.currentState?.validate() ?? false;
      case 1: return true;
      case 2:
        if (_selectedBloodGroup == null) { _showError('Please select your blood group'); return false; }
        if (_selectedGender == null) { _showError('Please select your gender'); return false; }
        return _step3Key.currentState?.validate() ?? false;
      case 3:
        if (_eligibilitySkipped) return true;
        return _step4Key.currentState?.validate() ?? false;
      default: return true;
    }
  }

  // ── GPS auto-detect location ─────────────────────────────────────────
  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled. Please enable GPS.');
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied');
          setState(() => _isLocating = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showError('Location permanently denied. Enable from settings.');
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      _geoPoint = GeoPoint(position.latitude, position.longitude);

      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        // Use LocationService for smart Pakistan city/province matching
        final locationService = LocationService();
        final resolved = locationService.resolveGpsLocation(
          country: p.country,
          adminArea: p.administrativeArea,
          locality: p.locality,
          subLocality: p.subLocality,
          subAdminArea: p.subAdministrativeArea,
          street: p.street,
        );

        setState(() {
          _selectedCountry = resolved['country'];
          _selectedState = resolved['province'];
          _selectedCity = resolved['city'];
          _addressController.text = resolved['address'] ?? '';
        });
      }
    } catch (e) {
      _showError('Could not detect location. Select manually.');
    }
    setState(() => _isLocating = false);
  }

  double? _calculateBMI() {
    final w = double.tryParse(_weightController.text.trim());
    final h = double.tryParse(_heightController.text.trim());
    if (w != null && h != null && h > 0) return w / ((h / 100) * (h / 100));
    return null;
  }

  bool _checkEligibility() {
    final age = int.tryParse(_ageController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final hb = double.tryParse(_hemoglobinController.text.trim());
    if (age != null && (age < 18 || age > 65)) return false;
    if (weight != null && weight < 50) return false;
    if (hb != null && hb < 12.5) return false;
    return true;
  }

  int _getProfileScore() {
    return UserModel.calculateProfileScore(
      role: 'donor', name: _nameController.text.trim(), mobile: _phoneController.text.trim(),
      bloodGroup: _selectedBloodGroup ?? '',
      whatsappNumber: _sameAsPhone ? _phoneController.text.trim() : _whatsappController.text.trim(),
      city: _selectedCity ?? '', country: _selectedCountry ?? '', address: _addressController.text.trim(),
      age: int.tryParse(_ageController.text.trim()), gender: _selectedGender,
      weight: double.tryParse(_weightController.text.trim()), height: double.tryParse(_heightController.text.trim()),
      hemoglobin: double.tryParse(_hemoglobinController.text.trim()),
    );
  }

  Future<void> _submitSignup() async {
    setState(() => _isSubmitting = true);
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _showError('Session expired. Please login again.');
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      final bmi = _calculateBMI();
      final userData = UserModel(
        uid: firebaseUser.uid, email: firebaseUser.email ?? '', name: _nameController.text.trim(),
        mobile: _phoneController.text.trim(), bloodGroup: _selectedBloodGroup ?? '', role: 'donor',
        whatsappNumber: _sameAsPhone ? _phoneController.text.trim() : _whatsappController.text.trim(),
        location: _geoPoint, address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        city: _selectedCity, state: _selectedState, country: _selectedCountry,
        age: int.tryParse(_ageController.text.trim()), gender: _selectedGender,
        weight: double.tryParse(_weightController.text.trim()), height: double.tryParse(_heightController.text.trim()),
        bmi: bmi, hemoglobin: double.tryParse(_hemoglobinController.text.trim()),
        isEligible: _checkEligibility(), profileCompletionScore: _getProfileScore(),
      );

      final success = await context.read<AuthProvider>().completeProfile(userData);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (success) { context.go(AppRoutes.home); }
      else { _showError(context.read<AuthProvider>().error ?? 'Failed to save. Try again.'); }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError('Error: ${e.toString()}');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: AppTheme.error,
      behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(isDark),
          Expanded(
            child: PageView(
              controller: _pageController, physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1Personal(isDark), _buildStep2Location(isDark),
                _buildStep3BloodHealth(isDark), _buildStep4Eligibility(isDark), _buildStep5Review(isDark),
              ],
            ),
          ),
          _buildBottomButtons(isDark),
        ]),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    final labels = ['Personal', 'Location', 'Blood', 'Health', 'Review'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Column(children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              onPressed: _currentStep > 0 ? _prevStep : () => Navigator.pop(context)),
          const SizedBox(width: 4),
          Text('Donor Registration', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
            child: Text('${_currentStep + 1}/$_totalSteps',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryRed)),
          ),
        ]),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: List.generate(_totalSteps, (i) {
            final active = i <= _currentStep; final cur = i == _currentStep;
            return Expanded(child: Column(children: [
              Row(children: [
                if (i > 0) Expanded(child: Container(height: 2.5, color: active ? AppTheme.primaryRed : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder))),
                Container(width: cur ? 10 : 8, height: cur ? 10 : 8, decoration: BoxDecoration(shape: BoxShape.circle,
                    color: active ? AppTheme.primaryRed : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    border: cur ? Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3), width: 3) : null)),
                if (i < _totalSteps - 1) Expanded(child: Container(height: 2.5, color: i < _currentStep ? AppTheme.primaryRed : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder))),
              ]),
              const SizedBox(height: 4),
              Text(labels[i], style: TextStyle(fontSize: 9, fontWeight: cur ? FontWeight.w700 : FontWeight.w500,
                  color: cur ? AppTheme.primaryRed : (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
            ]));
          })),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ══ STEP 1: Personal ══════════════════════════════════════════════════
  Widget _buildStep1Personal(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(key: _step1Key, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader(Icons.person_outline_rounded, 'Personal Information', 'Tell us about yourself'),
        const SizedBox(height: 28),
        TextFormField(controller: _nameController, validator: Validators.validateName,
            textInputAction: TextInputAction.next, textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full Name', hintText: 'Enter your full name', prefixIcon: Icon(Icons.badge_outlined))),
        const SizedBox(height: 16),
        TextFormField(controller: _phoneController, validator: Validators.validateMobile,
            keyboardType: TextInputType.phone, textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Phone Number', hintText: '+92 300 1234567', prefixIcon: Icon(Icons.phone_outlined))),
        const SizedBox(height: 16),
        Row(children: [
          Checkbox(value: _sameAsPhone, onChanged: (v) => setState(() => _sameAsPhone = v ?? true),
              activeColor: AppTheme.primaryRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
          Flexible(child: Text('WhatsApp same as phone', style: Theme.of(context).textTheme.bodyMedium)),
        ]),
        if (!_sameAsPhone) ...[
          const SizedBox(height: 8),
          TextFormField(controller: _whatsappController, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'WhatsApp Number', hintText: '+92 300 1234567', prefixIcon: Icon(Icons.message_outlined))),
        ],
      ])),
    );
  }

  // ══ STEP 2: Location ═══════════════════════════════════════════════════
  Widget _buildStep2Location(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader(Icons.location_on_outlined, 'Your Location', 'We use your location to find nearby blood requests'),
        const SizedBox(height: 28),

        // GPS button
        SizedBox(width: double.infinity, height: 54, child: OutlinedButton.icon(
          onPressed: _isLocating ? null : _detectLocation,
          icon: _isLocating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded),
          label: Text(_isLocating ? 'Detecting...' : 'Auto-detect my location'),
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryRed,
              side: BorderSide(color: AppTheme.primaryRed.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd))),
        )),

        // Detected address
        if (_addressController.text.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20), const SizedBox(width: 10),
              Expanded(child: Text(_addressController.text, style: const TextStyle(fontSize: 13))),
            ])),
        ],

        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Divider(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('OR SELECT MANUALLY', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary, letterSpacing: 1))),
          Expanded(child: Divider(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
        ]),
        const SizedBox(height: 20),

        // Location Picker Widget — searchable bottom sheet pickers
        LocationPickerWidget(
          initialCountry: _selectedCountry,
          initialState: _selectedState,
          initialCity: _selectedCity,
          onCountryChanged: (v) => setState(() { _selectedCountry = v; _selectedState = null; _selectedCity = null; }),
          onStateChanged: (v) => setState(() => _selectedState = v),
          onCityChanged: (v) => setState(() => _selectedCity = v),
        ),

        const SizedBox(height: 20),
        Center(child: TextButton(onPressed: _nextStep,
            child: Text('I\'ll add later →', style: TextStyle(color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary, fontSize: 13)))),
      ]),
    );
  }

  // ══ STEP 3: Blood & Health ════════════════════════════════════════════
  Widget _buildStep3BloodHealth(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(key: _step3Key, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader(Icons.bloodtype_rounded, 'Blood & Health', 'Helps us match you with the right recipients'),
        const SizedBox(height: 28),
        Text('Blood Group', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.5,
          children: _bloodGroups.map((g) {
            final sel = _selectedBloodGroup == g;
            return GestureDetector(onTap: () => setState(() => _selectedBloodGroup = g),
              child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primaryRed : (isDark ? AppTheme.darkCard : AppTheme.lightCard),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: sel ? AppTheme.primaryRed : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder), width: sel ? 2 : 1),
                  boxShadow: sel ? [BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.25), blurRadius: 8)] : null),
                child: Center(child: Text(g, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.black87))))));
          }).toList()),
        const SizedBox(height: 24),
        Text('Gender', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: _genders.map((g) {
          final sel = _selectedGender == g;
          return Expanded(child: Padding(padding: EdgeInsets.only(right: g != 'Other' ? 10 : 0),
            child: GestureDetector(onTap: () => setState(() => _selectedGender = g),
              child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primaryRed.withValues(alpha: 0.12) : (isDark ? AppTheme.darkCard : AppTheme.lightCard),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: sel ? AppTheme.primaryRed : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder))),
                child: Center(child: Text(g, style: TextStyle(fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? AppTheme.primaryRed : null)))))));
        }).toList()),
        const SizedBox(height: 24),
        TextFormField(controller: _ageController, keyboardType: TextInputType.number, validator: Validators.validateAge,
            decoration: const InputDecoration(labelText: 'Age', hintText: 'e.g. 25', prefixIcon: Icon(Icons.cake_outlined), suffixText: 'years')),
      ])),
    );
  }

  // ══ STEP 4: Eligibility (skippable) ══════════════════════════════════
  Widget _buildStep4Eligibility(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(key: _step4Key, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader(Icons.monitor_heart_outlined, 'Eligibility Check', 'Optional — check if you\'re eligible to donate'),
        const SizedBox(height: 28),
        TextFormField(controller: _weightController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: Validators.validateWeight, onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Weight', hintText: 'e.g. 70', prefixIcon: Icon(Icons.monitor_weight_outlined), suffixText: 'kg')),
        const SizedBox(height: 16),
        TextFormField(controller: _heightController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: Validators.validateHeight, onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Height', hintText: 'e.g. 170', prefixIcon: Icon(Icons.height_rounded), suffixText: 'cm')),
        const SizedBox(height: 16),
        TextFormField(controller: _hemoglobinController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: Validators.validateHemoglobin,
            decoration: const InputDecoration(labelText: 'Hemoglobin Level', hintText: 'e.g. 14.5', prefixIcon: Icon(Icons.science_outlined), suffixText: 'g/dL')),
        const SizedBox(height: 24),

        if (_weightController.text.isNotEmpty && _heightController.text.isNotEmpty)
          Builder(builder: (_) {
            final bmi = _calculateBMI();
            if (bmi == null) return const SizedBox.shrink();
            return Container(width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.info.withValues(alpha: 0.3))),
              child: Row(children: [
                const Icon(Icons.calculate_outlined, color: AppTheme.info, size: 20), const SizedBox(width: 10),
                Text('BMI: ${bmi.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.info)),
                const Spacer(),
                Text(bmi < 18.5 ? 'Underweight' : bmi < 25 ? 'Normal' : bmi < 30 ? 'Overweight' : 'Obese',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: bmi >= 18.5 && bmi < 25 ? AppTheme.success : AppTheme.warning)),
              ]));
          }),
        const SizedBox(height: 20),
        Center(child: TextButton(
            onPressed: () { setState(() => _eligibilitySkipped = true); _nextStep(); },
            child: Text('I\'ll complete later →', style: TextStyle(color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary, fontSize: 13)))),
      ])),
    );
  }

  // ══ STEP 5: Review ════════════════════════════════════════════════════
  Widget _buildStep5Review(bool isDark) {
    final score = _getProfileScore(); final bmi = _calculateBMI();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _stepHeader(Icons.fact_check_outlined, 'Review Your Profile', 'Everything correct before saving?'),
        const SizedBox(height: 20),
        Center(child: SizedBox(width: 100, height: 100, child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: 100, height: 100, child: CircularProgressIndicator(value: score / 100, strokeWidth: 6,
              backgroundColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              color: score >= 80 ? AppTheme.success : score >= 50 ? AppTheme.warning : AppTheme.primaryRed)),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$score%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            Text('Complete', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
          ]),
        ]))),
        const SizedBox(height: 24),
        _reviewRow('Name', _nameController.text, Icons.badge_outlined),
        _reviewRow('Phone', _phoneController.text, Icons.phone_outlined),
        _reviewRow('Blood', _selectedBloodGroup ?? '-', Icons.bloodtype_rounded),
        _reviewRow('Gender', _selectedGender ?? '-', Icons.wc_outlined),
        _reviewRow('Age', '${_ageController.text} yrs', Icons.cake_outlined),
        if (_selectedCity != null && _selectedCity!.isNotEmpty)
          _reviewRow('Location', [_selectedCity, _selectedState, _selectedCountry].where((e) => e != null && e.isNotEmpty).join(', '), Icons.location_on_outlined),
        if (bmi != null) _reviewRow('BMI', bmi.toStringAsFixed(1), Icons.calculate_outlined),
        if (_hemoglobinController.text.isNotEmpty)
          _reviewRow('Hb', '${_hemoglobinController.text} g/dL', Icons.science_outlined),

        if (!_eligibilitySkipped) ...[
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _checkEligibility() ? AppTheme.success.withValues(alpha: 0.08) : AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: _checkEligibility() ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.warning.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(_checkEligibility() ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: _checkEligibility() ? AppTheme.success : AppTheme.warning, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(_checkEligibility() ? 'You are eligible to donate! 🎉' : 'You may not be eligible right now.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _checkEligibility() ? AppTheme.success : AppTheme.warning))),
            ])),
        ],
        if (score < 100) ...[
          const SizedBox(height: 12),
          Text('Complete your profile later from Settings.', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
        ],
      ]),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  Widget _reviewRow(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
      Icon(icon, size: 18, color: AppTheme.primaryRed.withValues(alpha: 0.7)), const SizedBox(width: 10),
      SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
      Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
    ]));
  }

  Widget _stepHeader(IconData icon, String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppTheme.primaryRed, size: 24)),
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
}
