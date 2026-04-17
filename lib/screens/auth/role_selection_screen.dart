/// ─────────────────────────────────────────────────────────────────────────────
/// RoleSelectionScreen — Choose user role after initial signup
/// ─────────────────────────────────────────────────────────────────────────────
/// Appears after:
/// • Email signup (new account created, no profile yet)
/// • Google sign-in (first time, no Firestore profile)
library;
///
/// User picks their role:
/// • DONOR — someone who wants to donate blood
/// • RECIPIENT — someone/organization that needs blood
///   - Individual (personal need)
///   - Hospital
///   - Welfare Organization
///   - Other
///
/// After selection → navigates to the role-specific signup flow
/// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  // ── State ───────────────────────────────────────────────────────────────────
  String? _selectedRole;            // 'donor' or 'recipient'
  String? _recipientType;           // Sub-type for recipients

  // Admin-configurable recipient types
  bool _typeIndividual = true;
  bool _typeHospital = true;
  bool _typeWelfare = true;
  bool _typeOther = true;

  // ── Animation ────────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadRecipientTypes();
  }

  Future<void> _loadRecipientTypes() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('admin_settings').doc('config').get();
      if (snap.exists && mounted) {
        final data = snap.data() ?? {};
        setState(() {
          _typeIndividual = data['type_individual'] ?? true;
          _typeHospital = data['type_hospital'] ?? true;
          _typeWelfare = data['type_welfare'] ?? true;
          _typeOther = data['type_other'] ?? true;
        });
      }
    } catch (_) {
      // Fallback: show all types
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Navigate to the appropriate signup flow based on selected role
  void _proceed() {
    if (_selectedRole == 'donor') {
      context.go(AppRoutes.donorSignup);
    } else if (_selectedRole == 'recipient' && _recipientType != null) {
      // Pass recipient type as query parameter to the signup screen
      context.go('${AppRoutes.recipientSignup}?type=$_recipientType');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // ── Header ────────────────────────────────────────────
                Text(
                  'Join as',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose how you want to make a difference',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isDark
                            ? AppTheme.textSecondary
                            : AppTheme.textDarkSecondary,
                      ),
                ),
                const SizedBox(height: 36),

                // ── Role Cards ────────────────────────────────────────
                // DONOR card
                _RoleCard(
                  isSelected: _selectedRole == 'donor',
                  icon: Icons.volunteer_activism_rounded,
                  emoji: '🩸',
                  title: 'Blood Donor',
                  subtitle: 'I want to save lives by donating blood',
                  gradientColors: [AppTheme.primaryRed, AppTheme.primaryRedDark],
                  onTap: () {
                    setState(() {
                      _selectedRole = 'donor';
                      _recipientType = null;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // RECIPIENT card
                _RoleCard(
                  isSelected: _selectedRole == 'recipient',
                  icon: Icons.healing_rounded,
                  emoji: '💙',
                  title: 'Blood Recipient',
                  subtitle: 'I need blood for myself or my organization',
                  gradientColors: const [Color(0xFF1E88E5), Color(0xFF1565C0)],
                  onTap: () {
                    setState(() {
                      _selectedRole = 'recipient';
                      _recipientType = null; // Reset sub-type
                    });
                  },
                ),

                // ── Recipient sub-type selection ──────────────────────
                // Shows animated expansion when recipient is selected
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: _selectedRole == 'recipient'
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              'You are requesting blood as:',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            // Sub-type chips in a wrap layout
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (_typeIndividual) _TypeChip(
                                  label: '👤  Individual',
                                  value: 'individual',
                                  selected: _recipientType == 'individual',
                                  onTap: () => setState(
                                      () => _recipientType = 'individual'),
                                ),
                                if (_typeHospital) _TypeChip(
                                  label: '🏥  Hospital',
                                  value: 'hospital',
                                  selected: _recipientType == 'hospital',
                                  onTap: () => setState(
                                      () => _recipientType = 'hospital'),
                                ),
                                if (_typeWelfare) _TypeChip(
                                  label: '🤝  Welfare Org',
                                  value: 'welfare_org',
                                  selected: _recipientType == 'welfare_org',
                                  onTap: () => setState(
                                      () => _recipientType = 'welfare_org'),
                                ),
                                if (_typeOther) _TypeChip(
                                  label: '📋  Other',
                                  value: 'other',
                                  selected: _recipientType == 'other',
                                  onTap: () => setState(
                                      () => _recipientType = 'other'),
                                ),
                              ],
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),

                const Spacer(),

                // ── Continue button ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_selectedRole == 'donor' ||
                            (_selectedRole == 'recipient' &&
                                _recipientType != null))
                        ? _proceed
                        : null, // Disabled until selection is complete
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: (_selectedRole == 'donor' ||
                                    (_selectedRole == 'recipient' &&
                                        _recipientType != null))
                                ? Colors.white
                                : Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// _RoleCard — Large selectable card for Donor/Recipient choice
/// ─────────────────────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final bool isSelected;
  final IconData icon;
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _RoleCard({
    required this.isSelected,
    required this.icon,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // Selected state: gradient border, slight glow
          color: isSelected
              ? gradientColors.first.withValues(alpha: 0.08)
              : isDark
                  ? AppTheme.darkCard
                  : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: isSelected
                ? gradientColors.first
                : isDark
                    ? AppTheme.darkBorder
                    : AppTheme.lightBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon container with gradient
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected
                    ? null
                    : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 16),
            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected ? gradientColors.first : null,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppTheme.textTertiary
                              : AppTheme.textDarkSecondary,
                        ),
                  ),
                ],
              ),
            ),
            // Checkmark
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? gradientColors.first : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? gradientColors.first
                      : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// _TypeChip — Small selectable chip for recipient sub-type
/// ─────────────────────────────────────────────────────────────────────────────
class _TypeChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1E88E5).withValues(alpha: 0.12)
              : isDark
                  ? AppTheme.darkCard
                  : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: selected
                ? const Color(0xFF1E88E5)
                : isDark
                    ? AppTheme.darkBorder
                    : AppTheme.lightBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? const Color(0xFF1E88E5)
                : isDark
                    ? AppTheme.textSecondary
                    : AppTheme.textDarkSecondary,
          ),
        ),
      ),
    );
  }
}
