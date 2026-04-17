/// ─────────────────────────────────────────────────────────────────────────────
/// ChatModel — Data model for a chat conversation between donor and recipient
/// ─────────────────────────────────────────────────────────────────────────────
/// Firestore collection: chats/{chatId}
/// Sub-collection: chats/{chatId}/messages/{messageId}
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final String requestId;       // Blood request this chat is about
  final String donorId;
  final String recipientId;
  final String donorName;
  final String recipientName;
  final String bloodGroup;
  final String? hospitalName;

  /// Donation status: 'confirmed' → 'coming' → 'arrived' → 'donated'
  final String donationStatus;

  /// Estimated time (only set when status = 'coming')
  final String? estimatedTime;

  final String lastMessage;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  /// Unread counts per user
  final int unreadDonor;
  final int unreadRecipient;

  /// Whether the post-donation form has been filled
  final bool formCompleted;

  /// Whether recipient has confirmed receiving the blood
  final bool recipientConfirmed;

  ChatModel({
    required this.id,
    required this.requestId,
    required this.donorId,
    required this.recipientId,
    required this.donorName,
    required this.recipientName,
    required this.bloodGroup,
    this.hospitalName,
    this.donationStatus = 'confirmed',
    this.estimatedTime,
    this.lastMessage = '',
    DateTime? lastMessageAt,
    DateTime? createdAt,
    this.unreadDonor = 0,
    this.unreadRecipient = 0,
    this.formCompleted = false,
    this.recipientConfirmed = false,
  })  : lastMessageAt = lastMessageAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatModel(
      id: id,
      requestId: map['requestId'] ?? '',
      donorId: map['donorId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      donorName: map['donorName'] ?? '',
      recipientName: map['recipientName'] ?? '',
      bloodGroup: map['bloodGroup'] ?? '',
      hospitalName: map['hospitalName'],
      donationStatus: map['donationStatus'] ?? 'confirmed',
      estimatedTime: map['estimatedTime'],
      lastMessage: map['lastMessage'] ?? '',
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadDonor: map['unreadDonor'] ?? 0,
      unreadRecipient: map['unreadRecipient'] ?? 0,
      formCompleted: map['formCompleted'] ?? false,
      recipientConfirmed: map['recipientConfirmed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'requestId': requestId,
    'donorId': donorId,
    'recipientId': recipientId,
    'donorName': donorName,
    'recipientName': recipientName,
    'bloodGroup': bloodGroup,
    'hospitalName': hospitalName,
    'donationStatus': donationStatus,
    'estimatedTime': estimatedTime,
    'lastMessage': lastMessage,
    'lastMessageAt': Timestamp.fromDate(lastMessageAt),
    'createdAt': Timestamp.fromDate(createdAt),
    'participants': [donorId, recipientId],
    'unreadDonor': unreadDonor,
    'unreadRecipient': unreadRecipient,
    'formCompleted': formCompleted,
    'recipientConfirmed': recipientConfirmed,
  };

  /// Whether the donor can fill the post-donation form
  bool get canFillForm => donationStatus == 'donated' && !formCompleted;

  /// Status step index (0=confirmed, 1=coming, 2=arrived, 3=donated)
  int get statusStep {
    switch (donationStatus) {
      case 'confirmed': return 0;
      case 'coming':    return 1;
      case 'arrived':   return 2;
      case 'donated':   return 3;
      case 'completed': return 4;
      default:          return 0;
    }
  }

  /// Whether the chat is closed (donation completed and confirmed)
  bool get isClosed => donationStatus == 'completed' || recipientConfirmed;
}

/// Individual chat message
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String type; // 'text', 'status_update', 'system'
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.type = 'text',
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      sentAt: (map['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'senderName': senderName,
    'text': text,
    'type': type,
    'sentAt': Timestamp.fromDate(sentAt),
  };
}
