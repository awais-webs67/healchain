import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _particleController;

  // Logo animations
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoRotation;

  // Ring animations
  late Animation<double> _ring1Scale;
  late Animation<double> _ring1Opacity;
  late Animation<double> _ring2Scale;
  late Animation<double> _ring2Opacity;

  // Text animations
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;

  // Bottom bar animation
  late Animation<double> _bottomOpacity;
  late Animation<double> _progressValue;

  // Pulse
  late Animation<double> _pulseScale;

  // Particles
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();

    // Generate floating particles
    final random = Random();
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 4 + 1,
        speed: random.nextDouble() * 0.3 + 0.1,
        opacity: random.nextDouble() * 0.3 + 0.05,
      ));
    }

    // Main animation controller (3 seconds)
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Pulse controller (loops)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Particle controller (loops)
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    );

    // -- Logo Animations --
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
      ),
    );

    _logoRotation = Tween<double>(begin: -0.05, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    // -- Ring Animations --
    _ring1Scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
      ),
    );
    _ring1Opacity = Tween<double>(begin: 0.0, end: 0.15).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
      ),
    );
    _ring2Scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
      ),
    );
    _ring2Opacity = Tween<double>(begin: 0.0, end: 0.08).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
      ),
    );

    // -- Title Animations --
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.55, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    // -- Tagline --
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.50, 0.70, curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.50, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    // -- Bottom --
    _bottomOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.65, 0.85, curve: Curves.easeOut),
      ),
    );
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.60, 1.0, curve: Curves.easeInOut),
      ),
    );

    // -- Pulse --
    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations
    _mainController.forward();
    _pulseController.repeat(reverse: true);
    _particleController.repeat();

    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone =
        prefs.getBool(AppConstants.prefOnboardingDone) ?? false;

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    if (!onboardingDone) {
      context.go(AppRoutes.onboarding);
    } else if (authProvider.isLoggedIn && authProvider.hasProfile) {
      if (authProvider.userModel?.role == 'admin') {
        context.go(AppRoutes.adminDashboard);
      } else {
        context.go(AppRoutes.home);
      }
    } else if (authProvider.isLoggedIn && !authProvider.hasProfile) {
      // Firebase Auth cached but no Firestore profile (user deleted from DB)
      // Sign out the orphaned session and redirect to login
      await authProvider.signOut();
      if (mounted) context.go(AppRoutes.login);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _mainController,
          _pulseController,
          _particleController,
        ]),
        builder: (context, _) {
          return Stack(
            children: [
              // -- Background Gradient --
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A0E14),
                      Color(0xFF0D1117),
                      Color(0xFF121820),
                      Color(0xFF0D1117),
                    ],
                    stops: [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),

              // -- Floating Particles --
              ...List.generate(_particles.length, (i) {
                final p = _particles[i];
                final progress = (_particleController.value + p.speed) % 1.0;
                final yPos = (p.y - progress).abs();
                return Positioned(
                  left: p.x * size.width,
                  top: yPos * size.height,
                  child: Container(
                    width: p.size,
                    height: p.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryRed
                          .withValues(alpha: p.opacity),
                    ),
                  ),
                );
              }),

              // -- Subtle radial glow behind logo --
              Center(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primaryRed
                            .withValues(alpha: 0.08 * _logoOpacity.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // -- Main Content --
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Expanding rings
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ring
                          Transform.scale(
                            scale: _ring2Scale.value * 1.6,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryRed
                                      .withValues(alpha: _ring2Opacity.value),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),

                          // Inner ring
                          Transform.scale(
                            scale: _ring1Scale.value * 1.3,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryRed
                                      .withValues(alpha: _ring1Opacity.value),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                          // Logo with pulse
                          Transform.scale(
                            scale: _logoScale.value * _pulseScale.value,
                            child: Transform.rotate(
                              angle: _logoRotation.value,
                              child: Opacity(
                                opacity: _logoOpacity.value,
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    gradient: AppTheme.heroGradient,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryRed
                                            .withValues(alpha: 0.5),
                                        blurRadius: 30,
                                        spreadRadius: 4,
                                      ),
                                      BoxShadow(
                                        color: AppTheme.accentPink
                                            .withValues(alpha: 0.2),
                                        blurRadius: 60,
                                        spreadRadius: 12,
                                      ),
                                      BoxShadow(
                                        color: AppTheme.accentOrange
                                            .withValues(alpha: 0.15),
                                        blurRadius: 80,
                                        spreadRadius: 15,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Icon(
                                        Icons.water_drop_rounded,
                                        size: 56,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // App Name
                    SlideTransition(
                      position: _titleSlide,
                      child: Opacity(
                        opacity: _titleOpacity.value,
                        child: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Heal',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w300,
                                  color: AppTheme.accentOrange,  // Cyan — logo "HEAL"
                                  letterSpacing: 3,
                                ),
                              ),
                              TextSpan(
                                text: ' Chain',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accentPink,    // Magenta — logo "CHAIN"
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Tagline
                    SlideTransition(
                      position: _taglineSlide,
                      child: Opacity(
                        opacity: _taglineOpacity.value,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            AppConstants.appTagline.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.5),
                              letterSpacing: 1.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // -- Bottom progress bar --
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _bottomOpacity.value,
                  child: Column(
                    children: [
                      // Progress bar
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 80),
                        height: 2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _progressValue.value,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1),
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.accentPink,
                                    AppTheme.primaryRed,
                                    AppTheme.accentOrange,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connecting lives, one drop at a time',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.3),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}
