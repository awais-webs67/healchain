/// ─────────────────────────────────────────────────────────────────────────────
/// ChatService — Full chat + donation flow management
/// ─────────────────────────────────────────────────────────────────────────────
/// Handles: creating chats, sending messages, updating donation status,
///   recording donations with points, marking messages read
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  //  CREATE / GET CHAT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a new chat room when donor taps "I'll Donate" or return existing
  Future<String> createOrGetChat({
    required String requestId,
    required String donorId,
    required String donorName,
    required String recipientId,
    required String recipientName,
    required String bloodGroup,
    String? hospitalName,
  }) async {
    // Check if chat already exists for this request + donor
    final existing = await _db.collection('chats')
        .where('requestId', isEqualTo: requestId)
        .where('donorId', isEqualTo: donorId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return existing.docs.first.id;

    // Create new chat
    final chat = ChatModel(
      id: '',
      requestId: requestId,
      donorId: donorId,
      recipientId: recipientId,
      donorName: donorName,
      recipientName: recipientName,
      bloodGroup: bloodGroup,
      hospitalName: hospitalName,
      donationStatus: 'confirmed',
      lastMessage: '$donorName offered to donate $bloodGroup',
    );

    final doc = await _db.collection('chats').add(chat.toMap());

    // Send system message
    await sendMessage(
      chatId: doc.id,
      senderId: 'system',
      senderName: 'System',
      text: '🩸 $donorName has confirmed to donate $bloodGroup blood!',
      type: 'system',
    );

    // Notify recipient
    await _notify(
      userId: recipientId,
      title: '🩸 Donor Found!',
      body: '$donorName has offered to donate $bloodGroup blood for your request',
      type: 'donation',
    );

    return doc.id;
  }

  /// Create a notification in Firestore
  Future<void> _notify({
    required String userId,
    required String title,
    required String body,
    required String type,
  }) async {
    await _db.collection('notifications').add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MESSAGES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send a message in a chat
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    String type = 'text',
  }) async {
    final msg = ChatMessage(
      id: '',
      senderId: senderId,
      senderName: senderName,
      text: text,
      type: type,
    );

    await _db.collection('chats').doc(chatId).collection('messages').add(msg.toMap());

    // Update chat metadata
    final updateData = <String, dynamic>{
      'lastMessage': text,
      'lastMessageAt': Timestamp.now(),
    };

    // Increment unread for the other user
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    if (chatDoc.exists) {
      final data = chatDoc.data()!;
      if (senderId == data['donorId']) {
        updateData['unreadRecipient'] = FieldValue.increment(1);
      } else if (senderId == data['recipientId']) {
        updateData['unreadDonor'] = FieldValue.increment(1);
      }
    }

    await _db.collection('chats').doc(chatId).update(updateData);
  }

  /// Get messages stream for a chat
  Stream<List<ChatMessage>> getMessages(String chatId) {
    return _db.collection('chats').doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatMessage.fromMap(d.data(), d.id)).toList());
  }

  /// Mark messages as read for a user
  Future<void> markAsRead(String chatId, String myUid) async {
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return;
    final data = chatDoc.data()!;
    if (myUid == data['donorId']) {
      await _db.collection('chats').doc(chatId).update({'unreadDonor': 0});
    } else {
      await _db.collection('chats').doc(chatId).update({'unreadRecipient': 0});
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DONATION STATUS FLOW
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update donation status: confirmed → coming → arrived → donated
  Future<void> updateDonationStatus({
    required String chatId,
    required String newStatus,
    required String userName,
    String? estimatedTime,
  }) async {
    final updates = <String, dynamic>{'donationStatus': newStatus};
    if (estimatedTime != null) updates['estimatedTime'] = estimatedTime;

    await _db.collection('chats').doc(chatId).update(updates);

    // Send status message
    String statusMsg;
    switch (newStatus) {
      case 'confirmed':
        statusMsg = '✅ $userName confirmed the donation';
        break;
      case 'coming':
        statusMsg = '🚗 $userName is on the way${estimatedTime != null ? ' (ETA: $estimatedTime)' : ''}';
        break;
      case 'arrived':
        statusMsg = '📍 $userName has arrived at the hospital';
        break;
      case 'donated':
        statusMsg = '🩸 Donation completed! $userName donated blood successfully';
        break;
      default:
        statusMsg = 'Status updated to $newStatus';
    }

    await sendMessage(
      chatId: chatId,
      senderId: 'system',
      senderName: 'System',
      text: statusMsg,
      type: 'status_update',
    );

    // Notify recipient about status change
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    if (chatDoc.exists) {
      final data = chatDoc.data()!;
      final recipientId = data['recipientId'] ?? '';
      if (recipientId.isNotEmpty) {
        await _notify(userId: recipientId, title: 'Donation Update', body: statusMsg, type: 'status');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  POST-DONATION FORM
  // ═══════════════════════════════════════════════════════════════════════════

  /// Record a completed donation after the form is filled
  Future<void> recordDonation({
    required String chatId,
    required String donorId,
    required String donorName,
    required String recipientId,
    required String bloodGroup,
    required String hospital,
    required DateTime donationDate,
    required int units,
    String? notes,
  }) async {
    // Save donation record
    await _db.collection('donations').add({
      'chatId': chatId,
      'donorId': donorId,
      'donorName': donorName,
      'recipientId': recipientId,
      'bloodGroup': bloodGroup,
      'hospital': hospital,
      'donationDate': Timestamp.fromDate(donationDate),
      'units': units,
      'notes': notes,
      'status': 'completed',
      'verifiedByRecipient': false,
      'createdAt': Timestamp.now(),
    });

    // Update donor stats: +25 points, +1 donationCount, start cooldown
    final adminConfig = await _db.collection('admin_settings').doc('config').get();
    final cooldownDays = adminConfig.data()?['cooldownDays'] ?? 56;
    final cooldownEnd = donationDate.add(Duration(days: cooldownDays));
    await _db.collection('users').doc(donorId).update({
      'donationCount': FieldValue.increment(1),
      'points': FieldValue.increment(25),
      'lastDonationDate': Timestamp.fromDate(donationDate),
      'isAvailable': false,
      'cooldownUntil': Timestamp.fromDate(cooldownEnd),
    });

    // Mark chat form as completed
    await _db.collection('chats').doc(chatId).update({'formCompleted': true});

    // Send system message
    await sendMessage(
      chatId: chatId,
      senderId: 'system',
      senderName: 'System',
      text: '📋 Donation record submitted! +25 points awarded to $donorName 🏆',
      type: 'system',
    );

    // Notify donor of points earned
    await _notify(userId: donorId, title: '🏆 Points Earned!', body: 'You earned +25 points for donating $bloodGroup blood. Keep saving lives!', type: 'points');

    // Notify recipient
    await _notify(userId: recipientId, title: '📋 Donation Recorded', body: '$donorName has submitted the donation record for $bloodGroup blood.', type: 'donation');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CHAT STREAMS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all chats for a user (no orderBy to avoid composite index crash)
  Stream<List<ChatModel>> getUserChats(String uid) {
    return _db.collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => ChatModel.fromMap(d.data(), d.id)).toList();
          list.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
          return list;
        });
  }

  /// Get a single chat by ID (stream)
  Stream<ChatModel?> getChatStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ChatModel.fromMap(snap.data()!, snap.id);
    });
  }

  /// Delete a chat and all its messages
  Future<void> deleteChat(String chatId) async {
    // Delete all messages first
    final msgs = await _db.collection('chats').doc(chatId).collection('messages').get();
    final batch = _db.batch();
    for (var doc in msgs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    // Delete chat document
    await _db.collection('chats').doc(chatId).delete();
  }
}
