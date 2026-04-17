/// ─────────────────────────────────────────────────────────────────────────────
/// DonationFormScreen — Post-donation recording form
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class DonationFormScreen extends StatefulWidget {
  const DonationFormScreen({super.key});
  @override
  State<DonationFormScreen> createState() => _DonationFormScreenState();
}

class _DonationFormScreenState extends State<DonationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _donationDate = DateTime.now();
  int _units = 1;
  bool _submitting = false;

  @override
  void dispose() {
    _hospitalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      // Save donation record
      await FirebaseFirestore.instance.collection('donations').add({
        'donorId': user.uid,
        'donorName': user.name,
        'bloodGroup': user.bloodGroup,
        'hospital': _hospitalCtrl.text.trim(),
        'donatedAt': Timestamp.fromDate(_donationDate),
        'units': _units,
        'notes': _notesCtrl.text.trim(),
        'status': 'pending_verification',
        'verifiedByRecipient': false,
        'verifiedByAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update donor stats
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'donationCount': FieldValue.increment(1),
        'points': FieldValue.increment(25),
        'lastDonationDate': Timestamp.fromDate(_donationDate),
        'isEligible': true,
      });

      // Refresh user data
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Donation recorded! +25 points 🎉'),
          ]),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().userModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Donation', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Success header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF66BB6A)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Thank You, Hero! 🎉', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Record your donation to earn points', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                ])),
              ]),
            ),
            const SizedBox(height: 24),

            // Blood group (auto-filled)
            _label('Blood Group'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primaryRedDark, AppTheme.primaryRedLight]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(user?.bloodGroup ?? '?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white))),
                ),
                const SizedBox(width: 12),
                Text('Blood Type ${user?.bloodGroup ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ]),
            ),
            const SizedBox(height: 18),

            // Hospital
            _label('Hospital / Blood Bank'),
            TextFormField(
              controller: _hospitalCtrl,
              decoration: _inputDec('Enter hospital name', Icons.local_hospital_rounded, isDark),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 18),

            // Date
            _label('Donation Date'),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _donationDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _donationDate = picked);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 20, color: AppTheme.primaryRed),
                  const SizedBox(width: 12),
                  Text(DateFormat('MMMM dd, yyyy').format(_donationDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down_rounded, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
                ]),
              ),
            ),
            const SizedBox(height: 18),

            // Units
            _label('Units Donated'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
              child: Row(children: [
                IconButton(
                  onPressed: _units > 1 ? () => setState(() => _units--) : null,
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.remove_rounded, size: 20, color: AppTheme.primaryRed),
                  ),
                ),
                Expanded(child: Center(child: Text('$_units unit${_units > 1 ? 's' : ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))),
                IconButton(
                  onPressed: () => setState(() => _units++),
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppTheme.primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.add_rounded, size: 20, color: AppTheme.primaryRed),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 18),

            // Notes
            _label('Notes (Optional)'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: _inputDec('Any additional notes...', Icons.notes_rounded, isDark),
            ),
            const SizedBox(height: 30),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  disabledBackgroundColor: AppTheme.primaryRed.withValues(alpha: 0.5),
                ),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_circle_rounded, size: 22),
                        SizedBox(width: 10),
                        Text('Submit Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ]),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text('You\'ll earn 25 points for this donation ⭐', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
          ]),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
  );

  InputDecoration _inputDec(String hint, IconData ic, bool isDark) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(ic, size: 20),
    filled: true,
    fillColor: isDark ? AppTheme.darkCard : AppTheme.lightCard,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryRed, width: 1.5)),
  );
}
