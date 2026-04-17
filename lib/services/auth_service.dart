import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../config/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Email Sign Up ─────────────────────────────────────
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // ─── Email Sign In ─────────────────────────────────────
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // ─── Google Sign In ────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // ─── Check if user exists in Firestore ─────────────────
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, uid);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Save user data to Firestore ───────────────────────
  Future<void> saveUserData(UserModel user) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  // ─── Update user data ──────────────────────────────────
  Future<void> updateUserData(
      String uid, Map<String, dynamic> data) async {
    data['updatedAt'] = Timestamp.now();
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update(data);
  }

  // ─── Fetch Sign-In Methods (for provider detection) ─────
  Future<List<String>> fetchSignInMethods(String email) async {
    try {
      // ignore: deprecated_member_use
      return await _auth.fetchSignInMethodsForEmail(email);
    } catch (_) {
      return [];
    }
  }

  // ─── Check if user exists in Firestore by EMAIL ─────────
  /// Returns the UserModel if found, or null if not
  /// Tries original email first, then lowercase (Firestore is case-sensitive)
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final trimmed = email.trim();

      // Try original case first
      var query = await _firestore
          .collection(AppConstants.usersCollection)
          .where('email', isEqualTo: trimmed)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return UserModel.fromMap(doc.data(), doc.id);
      }

      // Try lowercase
      final lower = trimmed.toLowerCase();
      if (lower != trimmed) {
        query = await _firestore
            .collection(AppConstants.usersCollection)
            .where('email', isEqualTo: lower)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          return UserModel.fromMap(doc.data(), doc.id);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── Check sign-in providers via Firebase Auth ──────────
  /// Checks the providerData of a user if we have their UID
  List<String> getProviders(User user) {
    return user.providerData.map((p) => p.providerId).toList();
  }

  // ─── Password Reset ───────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ─── Sign Out ──────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ─── Delete Account ────────────────────────────────────
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .delete();
      await user.delete();
    }
  }
}
