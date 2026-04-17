/// ─────────────────────────────────────────────────────────────────────────────
/// UserModel — Unified data model for all user types in Heal Chain
/// ─────────────────────────────────────────────────────────────────────────────
/// Supports three roles: 'donor', 'recipient', 'admin'
/// Recipient can be 'individual', 'hospital', 'welfare_org', or 'other'
/// All data is stored in Firestore under the 'users' collection
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  // ── Core fields (required for all users) ──────────────────────────────────
  final String uid;                  // Firebase Auth UID
  final String email;                // Email address
  final String name;                 // Full name
  final String mobile;               // Phone number
  final String bloodGroup;           // Blood group (A+, B-, O+, etc.)
  final String role;                 // 'donor', 'recipient', 'admin'

  // ── Contact details ───────────────────────────────────────────────────────
  final String? whatsappNumber;      // WhatsApp number (can differ from mobile)

  // ── Location info ─────────────────────────────────────────────────────────
  final GeoPoint? location;          // GPS coordinates (lat/lng)
  final String? address;             // Full address text
  final String? city;                // City name
  final String? state;               // State/Province
  final String? country;             // Country name

  // ── Profile info ──────────────────────────────────────────────────────────
  final String? profileImageUrl;     // Profile photo URL from Firebase Storage
  final String? fcmToken;            // Push notification token
  final bool isActive;               // Account active status
  final bool notificationsEnabled;   // Push notifications toggle
  final bool darkMode;               // Theme preference
  final int profileCompletionScore;  // 0-100, how complete the profile is
  final DateTime createdAt;          // Account creation timestamp
  final DateTime updatedAt;          // Last update timestamp

  // ── Donor-specific fields ─────────────────────────────────────────────────
  final int? age;                    // Age in years
  final double? bmi;                 // Calculated BMI
  final double? hemoglobin;          // Hemoglobin level in g/dL
  final double? weight;              // Weight in kg
  final double? height;              // Height in cm
  final String? gender;              // Male, Female, Other
  final bool? isEligible;            // Whether eligible to donate
  final DateTime? lastDonationDate;  // Last blood donation date
  final bool isAvailable;            // Availability toggle for donors
  final int donationCount;           // Total verified donations
  final int points;                  // Reward points (25 per donation)
  final DateTime? cooldownUntil;     // Cooldown end date (56 days after donation)

  // ── Recipient-specific fields ─────────────────────────────────────────────
  /// Type of recipient: 'individual', 'hospital', 'welfare_org', 'other'
  final String? recipientType;
  /// Organization name (for hospitals, welfare orgs, etc.)
  final String? organizationName;

  // ─── Constructor ──────────────────────────────────────────────────────────
  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.mobile,
    required this.bloodGroup,
    required this.role,
    this.whatsappNumber,
    this.profileImageUrl,
    this.location,
    this.address,
    this.city,
    this.state,
    this.country,
    this.fcmToken,
    this.isActive = true,
    this.notificationsEnabled = true,
    this.darkMode = true,
    this.profileCompletionScore = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.age,
    this.bmi,
    this.hemoglobin,
    this.weight,
    this.height,
    this.gender,
    this.isEligible,
    this.lastDonationDate,
    this.isAvailable = false,
    this.donationCount = 0,
    this.points = 0,
    this.cooldownUntil,
    this.recipientType,
    this.organizationName,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // ─── Factory: create UserModel from Firestore document ────────────────────
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      mobile: map['mobile'] ?? '',
      bloodGroup: map['bloodGroup'] ?? '',
      role: map['role'] ?? 'recipient',
      whatsappNumber: map['whatsappNumber'],
      profileImageUrl: map['profileImageUrl'],
      location: map['location'],
      address: map['address'],
      city: map['city'],
      state: map['state'],
      country: map['country'],
      fcmToken: map['fcmToken'],
      isActive: map['isActive'] ?? true,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      darkMode: map['darkMode'] ?? true,
      profileCompletionScore: map['profileCompletionScore'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      age: map['age'],
      bmi: (map['bmi'] as num?)?.toDouble(),
      hemoglobin: (map['hemoglobin'] as num?)?.toDouble(),
      weight: (map['weight'] as num?)?.toDouble(),
      height: (map['height'] as num?)?.toDouble(),
      gender: map['gender'],
      isEligible: map['isEligible'],
      lastDonationDate: (map['lastDonationDate'] as Timestamp?)?.toDate(),
      isAvailable: map['isAvailable'] ?? false,
      donationCount: map['donationCount'] ?? 0,
      points: map['points'] ?? 0,
      cooldownUntil: (map['cooldownUntil'] as Timestamp?)?.toDate(),
      recipientType: map['recipientType'],
      organizationName: map['organizationName'],
    );
  }

  // ─── Convert to Firestore-compatible map ──────────────────────────────────
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'email': email,
      'name': name,
      'mobile': mobile,
      'bloodGroup': bloodGroup,
      'role': role,
      'whatsappNumber': whatsappNumber,
      'profileImageUrl': profileImageUrl,
      'location': location,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'fcmToken': fcmToken,
      'isActive': isActive,
      'notificationsEnabled': notificationsEnabled,
      'darkMode': darkMode,
      'profileCompletionScore': profileCompletionScore,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    // Donor-specific fields — only saved for donors to keep data clean
    if (role == 'donor') {
      map['age'] = age;
      map['bmi'] = bmi;
      map['hemoglobin'] = hemoglobin;
      map['weight'] = weight;
      map['height'] = height;
      map['gender'] = gender;
      map['isEligible'] = isEligible;
      map['isAvailable'] = isAvailable;
      map['donationCount'] = donationCount;
      map['points'] = points;
      if (lastDonationDate != null) {
        map['lastDonationDate'] = Timestamp.fromDate(lastDonationDate!);
      }
      if (cooldownUntil != null) {
        map['cooldownUntil'] = Timestamp.fromDate(cooldownUntil!);
      }
    }

    // Recipient-specific fields
    if (role == 'recipient') {
      map['recipientType'] = recipientType;
      map['organizationName'] = organizationName;
    }

    return map;
  }

  // ─── Create a copy with updated fields ────────────────────────────────────
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? mobile,
    String? bloodGroup,
    String? role,
    String? whatsappNumber,
    String? profileImageUrl,
    GeoPoint? location,
    String? address,
    String? city,
    String? state,
    String? country,
    String? fcmToken,
    bool? isActive,
    bool? notificationsEnabled,
    bool? darkMode,
    int? profileCompletionScore,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? age,
    double? bmi,
    double? hemoglobin,
    double? weight,
    double? height,
    String? gender,
    bool? isEligible,
    DateTime? lastDonationDate,
    bool? isAvailable,
    int? donationCount,
    int? points,
    String? recipientType,
    String? organizationName,
    DateTime? cooldownUntil,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      role: role ?? this.role,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      location: location ?? this.location,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      fcmToken: fcmToken ?? this.fcmToken,
      isActive: isActive ?? this.isActive,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkMode: darkMode ?? this.darkMode,
      profileCompletionScore: profileCompletionScore ?? this.profileCompletionScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      age: age ?? this.age,
      bmi: bmi ?? this.bmi,
      hemoglobin: hemoglobin ?? this.hemoglobin,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      gender: gender ?? this.gender,
      isEligible: isEligible ?? this.isEligible,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
      isAvailable: isAvailable ?? this.isAvailable,
      donationCount: donationCount ?? this.donationCount,
      points: points ?? this.points,
      recipientType: recipientType ?? this.recipientType,
      organizationName: organizationName ?? this.organizationName,
      cooldownUntil: cooldownUntil ?? this.cooldownUntil,
    );
  }

  // ─── Convenience getters ──────────────────────────────────────────────────
  bool get isDonor => role == 'donor';
  bool get isRecipient => role == 'recipient';
  bool get isAdmin => role == 'admin';
  bool get isOrganization =>
      recipientType == 'hospital' || recipientType == 'welfare_org';

  /// Days until next eligible donation (based on cooldownUntil field)
  int get daysUntilNextDonation {
    if (cooldownUntil == null) return 0;
    final diff = cooldownUntil!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Next eligible donation date (based on cooldownUntil field)
  DateTime? get nextDonationDate {
    if (cooldownUntil == null) return null;
    if (cooldownUntil!.isAfter(DateTime.now())) return cooldownUntil;
    return null; // Cooldown passed
  }

  /// Whether cooldown period has passed
  bool get canDonateNow => daysUntilNextDonation == 0;


  /// Donor level based on points
  String get donorLevel {
    if (points >= 200) return 'Legend';
    if (points >= 100) return 'Platinum';
    if (points >= 50) return 'Gold';
    if (points >= 25) return 'Silver';
    return 'Bronze';
  }

  /// Donor level emoji
  String get donorLevelEmoji {
    if (points >= 200) return '👑';
    if (points >= 100) return '💎';
    if (points >= 50) return '🥇';
    if (points >= 25) return '🥈';
    return '🥉';
  }

  /// Calculate profile completion score based on filled fields
  /// Returns a value between 0 and 100
  static int calculateProfileScore({
    required String role,
    required String name,
    required String mobile,
    required String bloodGroup,
    String? whatsappNumber,
    String? city,
    String? country,
    String? address,
    // Donor fields
    int? age,
    String? gender,
    double? weight,
    double? height,
    double? hemoglobin,
    // Recipient fields
    String? recipientType,
    String? organizationName,
  }) {
    int score = 0;
    int totalFields = 0;

    // Common fields for all roles
    totalFields += 4; // name, mobile, city, country
    if (name.isNotEmpty) score++;
    if (mobile.isNotEmpty) score++;
    if (city != null && city.isNotEmpty) score++;
    if (country != null && country.isNotEmpty) score++;

    // Optional common
    totalFields += 2; // whatsapp, address
    if (whatsappNumber != null && whatsappNumber.isNotEmpty) score++;
    if (address != null && address.isNotEmpty) score++;

    if (role == 'donor') {
      // Blood group is required for donors
      totalFields += 1;
      if (bloodGroup.isNotEmpty) score++;
      // Donor-specific required fields
      totalFields += 5; // age, gender, weight, height, hemoglobin
      if (age != null) score++;
      if (gender != null && gender.isNotEmpty) score++;
      if (weight != null) score++;
      if (height != null) score++;
      if (hemoglobin != null) score++;
    } else if (role == 'recipient') {
      // Blood group is optional for recipients (nice to have)
      if (bloodGroup.isNotEmpty) {
        totalFields += 1;
        score++;
      }
      // Recipient-specific
      totalFields += 1; // recipientType
      if (recipientType != null && recipientType.isNotEmpty) score++;
      if (recipientType == 'hospital' || recipientType == 'welfare_org') {
        totalFields += 1;
        if (organizationName != null && organizationName.isNotEmpty) score++;
      }
    }

    return totalFields > 0 ? ((score / totalFields) * 100).round() : 0;
  }
}
