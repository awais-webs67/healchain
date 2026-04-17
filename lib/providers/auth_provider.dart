/// ─────────────────────────────────────────────────────────────────────────────
/// AuthProvider — Central auth state management for the entire app
/// ─────────────────────────────────────────────────────────────────────────────
/// Manages: Firebase Auth state, user profile data, loading states, errors
/// Used by: Login, Signup, Home, Profile, and all screens that need auth
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // ── State variables ─────────────────────────────────────────────────────
  User? _firebaseUser;            // Firebase Auth user object
  UserModel? _userModel;          // Full user profile from Firestore
  bool _isLoading = false;        // Loading state for async operations
  String? _error;                 // Last error message

  // ── Getters ─────────────────────────────────────────────────────────────
  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Whether user is authenticated with Firebase Auth
  bool get isLoggedIn => _firebaseUser != null;

  /// Whether user has completed their profile setup in Firestore
  bool get hasProfile => _userModel != null;

  /// Current user's role (donor/recipient/admin), empty if no profile
  String get userRole => _userModel?.role ?? '';

  // ── Constructor: listen to auth state changes ───────────────────────────
  AuthProvider() {
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  /// Called automatically when Firebase Auth state changes
  /// (login, logout, app restart)
  void _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    if (user != null) {
      // User is logged in → try to load their Firestore profile
      await _loadUserData(user.uid);
      // Save FCM token for push notifications
      if (_userModel != null) {
        NotificationService().saveFcmToken(user.uid);
        NotificationService().startListening(user.uid);
      }
    } else {
      // User logged out → clear profile + stop notifications
      _userModel = null;
      NotificationService().stopListening();
    }
    notifyListeners();
  }

  /// Load user profile data from Firestore by UID
  Future<void> _loadUserData(String uid) async {
    try {
      _userModel = await _authService.getUserData(uid);
    } catch (e) {
      _error = e.toString();
    }
  }

  /// Manually refresh user data (used after profile updates)
  Future<void> refreshUserData() async {
    if (_firebaseUser != null) {
      await _loadUserData(_firebaseUser!.uid);
      notifyListeners();
    }
  }

  // ─── EMAIL SIGN UP (account only, no profile) ─────────────────────────
  /// Creates a Firebase Auth account with email/password only.
  /// Does NOT save a Firestore profile — user will complete that in the
  /// multi-step signup flow after role selection.
  Future<bool> signUpWithEmailOnly({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    // Check internet first
    if (!await _hasInternet()) {
      _setError('No internet connection. Please check your network and try again.');
      _setLoading(false);
      return false;
    }

    try {
      final credential = await _authService.signUpWithEmail(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        _firebaseUser = credential.user;
        // Don't save profile yet — user needs to select role and fill details
        _setLoading(false);
        notifyListeners();
        return true;
      }

      _setLoading(false);
      return false;
    } on FirebaseAuthException catch (e) {
      // If email already in use, check if it's a Google account
      if (e.code == 'email-already-in-use') {
        final existing = await _authService.getUserByEmail(email);
        if (existing != null) {
          // Check if this user originally signed in with Google by checking
          // if they exist in Firestore — if yes, they likely used Google
          final methods = await _authService.fetchSignInMethods(email);
          if (methods.contains('google.com')) {
            _setError('This email is registered with Google Sign-In. Please use "Continue with Google" to sign in.');
          } else {
            _setError('This email is already registered. Please sign in instead.');
          }
        } else {
          _setError('This email is already registered. Please sign in instead.');
        }
      } else {
        _setError(_getAuthErrorMessage(e.code));
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(_getAuthErrorMessage(e.toString()));
      _setLoading(false);
      return false;
    }
  }

  // ─── EMAIL SIGN UP (with full profile — legacy) ───────────────────────
  /// Creates Firebase Auth account AND saves full profile to Firestore
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required UserModel userData,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final credential = await _authService.signUpWithEmail(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final user = userData.copyWith(uid: credential.user!.uid);
        await _authService.saveUserData(user);
        _userModel = user;
        _setLoading(false);
        return true;
      }

      _setLoading(false);
      return false;
    } on FirebaseAuthException catch (e) {
      _setError(_getAuthErrorMessage(e.code));
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ─── EMAIL SIGN IN ────────────────────────────────────────────────────
  /// Signs in with email/password, then loads profile from Firestore
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    // Check internet first
    if (!await _hasInternet()) {
      _setError('No internet connection. Please check your network and try again.');
      _setLoading(false);
      return false;
    }

    try {
      final credential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      // ✅ Explicitly load user data BEFORE returning success
      if (credential.user != null) {
        _firebaseUser = credential.user;
        await _loadUserData(credential.user!.uid);
        if (_userModel != null) {
          NotificationService().saveFcmToken(credential.user!.uid);
          NotificationService().startListening(credential.user!.uid);
        }
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getAuthErrorMessage(e.code));
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(_getAuthErrorMessage(e.toString()));
      _setLoading(false);
      return false;
    }
  }

  // ─── GOOGLE SIGN IN ───────────────────────────────────────────────────
  /// Signs in with Google, checks if user already has a Firestore profile.
  /// If not, they'll need to go through role selection → signup flow.
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    // Check internet first
    if (!await _hasInternet()) {
      _setError('No internet connection. Please check your network and try again.');
      _setLoading(false);
      return false;
    }

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        _setLoading(false);
        return false; // User cancelled the Google sign-in
      }

      // Check if this Google user already has a profile in Firestore
      _firebaseUser = credential.user;
      final existingUser =
          await _authService.getUserData(credential.user!.uid);
      if (existingUser != null) {
        _userModel = existingUser;
        NotificationService().saveFcmToken(credential.user!.uid);
        NotificationService().startListening(credential.user!.uid);
      }
      // If no profile → user will be redirected to role selection

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Google sign-in failed. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  // ─── COMPLETE PROFILE (final step of signup) ──────────────────────────
  /// Saves the full user profile to Firestore after signup flow completes
  Future<bool> completeProfile(UserModel userData) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.saveUserData(userData);
      _userModel = userData;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ─── UPDATE PROFILE ───────────────────────────────────────────────────
  /// Partially update user profile fields (used from settings/profile screen)
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _setLoading(true);
    _clearError();

    try {
      if (_firebaseUser != null) {
        await _authService.updateUserData(_firebaseUser!.uid, data);
        await refreshUserData();
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ─── SIGN OUT ─────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _authService.signOut();
    NotificationService().stopListening();
    _userModel = null;
    _firebaseUser = null;
    notifyListeners();
  }

  // ─── PASSWORD RESET ───────────────────────────────────────────────────
  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _clearError();

    // Check internet first
    if (!await _hasInternet()) {
      _setError('No internet connection.');
      _setLoading(false);
      return false;
    }

    try {
      // Check Firestore first — does this email exist in our database?
      final existingUser = await _authService.getUserByEmail(email);

      // If user exists in Firestore and signed up via Google only, warn them
      if (existingUser != null) {
        final methods = await _authService.fetchSignInMethods(email);
        if (methods.isNotEmpty && methods.length == 1 && methods.contains('google.com')) {
          _setError('google-only');
          _setLoading(false);
          return false;
        }
      }

      // Always send the reset email — Firebase silently handles non-existent
      // emails due to email enumeration protection. This prevents attackers
      // from discovering which emails are registered, and also prevents
      // false "account not found" errors when the account actually exists.
      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  /// Check internet connectivity
  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Convert Firebase error codes to user-friendly messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Email or password is incorrect. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        if (code.contains('invalid-credential') || code.contains('INVALID_LOGIN_CREDENTIALS')) {
          return 'Email or password is incorrect. Please try again.';
        }
        return 'An error occurred. Please try again.';
    }
  }
}
