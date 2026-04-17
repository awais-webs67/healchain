import 'package:cloud_firestore/cloud_firestore.dart';

class BloodRequestModel {
  final String id;
  final String recipientId;
  final String recipientName;
  final String bloodGroup;
  final String urgency; // 'Critical', 'Urgent', 'Normal'
  final String? hospitalName;
  final String? hospitalAddress;
  final String? notes;
  final int unitsNeeded;
  final GeoPoint? location;
  final String? city;
  final String? country;
  final String status; // 'active', 'fulfilled', 'expired', 'cancelled'
  final String? fulfilledBy;
  final String? contactNumber;
  final DateTime createdAt;
  final DateTime? expiresAt;

  BloodRequestModel({
    required this.id,
    required this.recipientId,
    required this.recipientName,
    required this.bloodGroup,
    required this.urgency,
    this.hospitalName,
    this.hospitalAddress,
    this.notes,
    this.unitsNeeded = 1,
    this.location,
    this.city,
    this.country,
    this.status = 'active',
    this.fulfilledBy,
    this.contactNumber,
    DateTime? createdAt,
    this.expiresAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BloodRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return BloodRequestModel(
      id: id,
      recipientId: map['recipientId'] ?? '',
      recipientName: map['recipientName'] ?? '',
      bloodGroup: map['bloodGroup'] ?? '',
      urgency: map['urgency'] ?? 'Normal',
      hospitalName: map['hospitalName'],
      hospitalAddress: map['hospitalAddress'],
      notes: map['notes'],
      unitsNeeded: map['unitsNeeded'] ?? 1,
      location: map['location'],
      city: map['city'],
      country: map['country'],
      status: map['status'] ?? 'active',
      fulfilledBy: map['fulfilledBy'],
      contactNumber: map['contactNumber'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'recipientName': recipientName,
      'bloodGroup': bloodGroup,
      'urgency': urgency,
      'hospitalName': hospitalName,
      'hospitalAddress': hospitalAddress,
      'notes': notes,
      'unitsNeeded': unitsNeeded,
      'location': location,
      'city': city,
      'country': country,
      'status': status,
      'fulfilledBy': fulfilledBy,
      'contactNumber': contactNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    };
  }

  BloodRequestModel copyWith({
    String? id,
    String? recipientId,
    String? recipientName,
    String? bloodGroup,
    String? urgency,
    String? hospitalName,
    String? hospitalAddress,
    String? notes,
    int? unitsNeeded,
    GeoPoint? location,
    String? city,
    String? country,
    String? status,
    String? fulfilledBy,
    String? contactNumber,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return BloodRequestModel(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      urgency: urgency ?? this.urgency,
      hospitalName: hospitalName ?? this.hospitalName,
      hospitalAddress: hospitalAddress ?? this.hospitalAddress,
      notes: notes ?? this.notes,
      unitsNeeded: unitsNeeded ?? this.unitsNeeded,
      location: location ?? this.location,
      city: city ?? this.city,
      country: country ?? this.country,
      status: status ?? this.status,
      fulfilledBy: fulfilledBy ?? this.fulfilledBy,
      contactNumber: contactNumber ?? this.contactNumber,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  bool get isActive => status == 'active';
  bool get isCritical => urgency == 'Critical';
  bool get isUrgent => urgency == 'Urgent';
}
