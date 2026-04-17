import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import '../models/blood_request_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════
  //  USERS
  // ═══════════════════════════════════════════════════════

  // Get user by ID
  Future<UserModel?> getUser(String uid) async {
    final doc =
        await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, uid);
    }
    return null;
  }

  // Get all donors
  Stream<List<UserModel>> getDonors() {
    return _db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: AppConstants.roleDonor)
        .where('isActive', isEqualTo: true)
        .where('isEligible', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get donors by blood group
  Stream<List<UserModel>> getDonorsByBloodGroup(String bloodGroup) {
    return _db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: AppConstants.roleDonor)
        .where('isActive', isEqualTo: true)
        .where('isEligible', isEqualTo: true)
        .where('bloodGroup', isEqualTo: bloodGroup)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get donors by city
  Future<List<UserModel>> getDonorsByCity(String city) async {
    final snap = await _db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: AppConstants.roleDonor)
        .where('isActive', isEqualTo: true)
        .where('isEligible', isEqualTo: true)
        .where('city', isEqualTo: city)
        .get();
    return snap.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Get donors by country
  Future<List<UserModel>> getDonorsByCountry(String country) async {
    final snap = await _db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: AppConstants.roleDonor)
        .where('isActive', isEqualTo: true)
        .where('isEligible', isEqualTo: true)
        .where('country', isEqualTo: country)
        .get();
    return snap.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Search donors with multiple filters
  Future<List<UserModel>> searchDonors({
    String? bloodGroup,
    String? city,
    String? country,
  }) async {
    Query query = _db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: AppConstants.roleDonor)
        .where('isActive', isEqualTo: true)
        .where('isEligible', isEqualTo: true);

    if (bloodGroup != null && bloodGroup.isNotEmpty) {
      query = query.where('bloodGroup', isEqualTo: bloodGroup);
    }
    if (city != null && city.isNotEmpty) {
      query = query.where('city', isEqualTo: city);
    }
    if (country != null && country.isNotEmpty) {
      query = query.where('country', isEqualTo: country);
    }

    final snap = await query.get();
    return snap.docs
        .map((doc) =>
            UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  // Update user's FCM token
  Future<void> updateFcmToken(String uid, String token) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({'fcmToken': token});
  }

  // Get all users (admin)
  Stream<List<UserModel>> getAllUsers() {
    return _db
        .collection(AppConstants.usersCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Update a user's role (admin)
  Future<void> updateUserRole(String uid, String role) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'role': role,
      'isDonor': role == 'donor',
    });
  }

  // Reset user's cooldown timer (admin)
  Future<void> resetUserCooldown(String uid) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'isAvailable': true,
      'cooldownUntil': FieldValue.delete(),
    });
  }

  // Delete a user record (admin)
  Future<void> deleteUserRecord(String uid) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).delete();
  }

  // Update a user's cooldown (admin recalculation)
  Future<void> updateCooldownForUser(String uid, DateTime cooldownUntil, bool isAvailable) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'cooldownUntil': Timestamp.fromDate(cooldownUntil),
      'isAvailable': isAvailable,
    });
  }

  // ═══════════════════════════════════════════════════════
  //  BLOOD REQUESTS
  // ═══════════════════════════════════════════════════════

  // Create blood request
  Future<String> createBloodRequest(BloodRequestModel request) async {
    final docRef = await _db
        .collection(AppConstants.bloodRequestsCollection)
        .add(request.toMap());
    return docRef.id;
  }

  // Get active blood requests
  Stream<List<BloodRequestModel>> getActiveRequests() {
    return _db
        .collection(AppConstants.bloodRequestsCollection)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => BloodRequestModel.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Get requests by recipient
  Stream<List<BloodRequestModel>> getRequestsByRecipient(
      String recipientId) {
    return _db
        .collection(AppConstants.bloodRequestsCollection)
        .where('recipientId', isEqualTo: recipientId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => BloodRequestModel.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<BloodRequestModel>> getRequestsByBloodGroup(
      String bloodGroup) {
    return _db
        .collection(AppConstants.bloodRequestsCollection)
        .where('status', isEqualTo: 'active')
        .where('bloodGroup', isEqualTo: bloodGroup)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => BloodRequestModel.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Get a single request by ID
  Future<BloodRequestModel?> getRequestById(String id) async {
    final doc = await _db.collection(AppConstants.bloodRequestsCollection).doc(id).get();
    if (doc.exists && doc.data() != null) {
      return BloodRequestModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Update request status
  Future<void> updateRequestStatus(
      String requestId, String status, {String? fulfilledBy}) async {
    final data = <String, dynamic>{'status': status};
    if (fulfilledBy != null) data['fulfilledBy'] = fulfilledBy;
    await _db
        .collection(AppConstants.bloodRequestsCollection)
        .doc(requestId)
        .update(data);
  }

  // Delete request (admin)
  Future<void> deleteRequest(String requestId) async {
    await _db.collection(AppConstants.bloodRequestsCollection).doc(requestId).delete();
  }

  // ═══════════════════════════════════════════════════════
  //  MOTIVATIONAL MESSAGES
  // ═══════════════════════════════════════════════════════

  // Save weekly batch of motivational messages
  Future<void> saveMotivationalMessages(
      String weekId, List<String> messages) async {
    await _db
        .collection(AppConstants.motivationalCollection)
        .doc(weekId)
        .set({
      'messages': messages,
      'generatedAt': Timestamp.now(),
      'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7))),
    });
  }

  // Get current week's motivational messages
  Future<List<String>> getMotivationalMessages(String weekId) async {
    final doc = await _db
        .collection(AppConstants.motivationalCollection)
        .doc(weekId)
        .get();
    if (doc.exists && doc.data() != null) {
      return List<String>.from(doc.data()!['messages'] ?? []);
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════
  //  ADMIN SETTINGS
  // ═══════════════════════════════════════════════════════

  // Get admin settings
  Future<Map<String, dynamic>> getAdminSettings() async {
    final doc = await _db
        .collection(AppConstants.adminSettingsCollection)
        .doc(AppConstants.adminConfigDoc)
        .get();
    return doc.data() ?? {};
  }

  // Save admin settings
  Future<void> saveAdminSettings(Map<String, dynamic> settings) async {
    await _db
        .collection(AppConstants.adminSettingsCollection)
        .doc(AppConstants.adminConfigDoc)
        .set(settings, SetOptions(merge: true));
  }

  // Get API keys
  Future<Map<String, dynamic>> getApiKeys() async {
    final doc = await _db
        .collection(AppConstants.adminSettingsCollection)
        .doc(AppConstants.apiKeysDoc)
        .get();
    return doc.data() ?? {};
  }

  // Save API keys
  Future<void> saveApiKeys(Map<String, dynamic> keys) async {
    await _db
        .collection(AppConstants.adminSettingsCollection)
        .doc(AppConstants.apiKeysDoc)
        .set(keys, SetOptions(merge: true));
  }

  // ═══════════════════════════════════════════════════════
  //  STATS (Admin)
  // ═══════════════════════════════════════════════════════

  Future<Map<String, int>> getAppStats() async {
    final users = await _db.collection(AppConstants.usersCollection).get();
    final requests =
        await _db.collection(AppConstants.bloodRequestsCollection).get();
    final donations = await _db.collection('donations').get();
    final chats = await _db.collection('chats').get();

    int donors = 0, recipients = 0, admins = 0, activeRequests = 0, fulfilled = 0;

    for (var doc in users.docs) {
      if (doc.data()['role'] == 'donor') donors++;
      if (doc.data()['role'] == 'recipient') recipients++;
      if (doc.data()['role'] == 'admin') admins++;
    }

    for (var doc in requests.docs) {
      if (doc.data()['status'] == 'active') activeRequests++;
      if (doc.data()['status'] == 'fulfilled') fulfilled++;
    }

    int activeChats = 0;
    for (var doc in chats.docs) {
      final status = doc.data()['donationStatus'] ?? '';
      if (status != 'donated') activeChats++;
    }

    return {
      'totalUsers': users.size,
      'donors': donors,
      'recipients': recipients,
      'admins': admins,
      'totalRequests': requests.size,
      'activeRequests': activeRequests,
      'fulfilledRequests': fulfilled,
      'totalDonations': donations.size,
      'activeChats': activeChats,
      'totalChats': chats.size,
    };
  }
}
