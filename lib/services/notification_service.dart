/// ─────────────────────────────────────────────────────────────────────────────
/// NotificationService — Push notifications + emergency alerts
/// ─────────────────────────────────────────────────────────────────────────────
/// Handles: FCM token management, local notification display,
///   permission requests, emergency alert channel (max priority + alarm sound),
///   regular notification channel, and Firestore notification creation
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _initialized = false;
  String? _listeningUid;
  StreamSubscription? _notifSub;

  // ─── Notification Channels ──────────────────────────────────────────────
  static const _emergencyChannel = AndroidNotificationChannel(
    'emergency_channel',
    'Emergency Alerts',
    description: 'Urgent blood donation requests with alarm sound',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFFE53935),
    showBadge: true,
  );

  static const _generalChannel = AndroidNotificationChannel(
    'general_channel',
    'General Notifications',
    description: 'Donation updates, points, and messages',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  // ─── Initialize ─────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotifTap,
    );

    // Create notification channels
    final androidPlugin = _localNotif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_emergencyChannel);
      await androidPlugin.createNotificationChannel(_generalChannel);
    }

    // Request permissions
    await requestPermissions();

    // Handle FCM messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check for initial message (app opened from terminated state via notification)
    final initialMsg = await _fcm.getInitialMessage();
    if (initialMsg != null) {
      _handleMessageOpenedApp(initialMsg);
    }

    _initialized = true;
    debugPrint('🔔 NotificationService initialized');
  }

  // ─── Request Permissions ────────────────────────────────────────────────
  Future<bool> requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
      announcement: false,
      carPlay: false,
      provisional: false,
    );

    final granted = settings.authorizationStatus == AuthorizationStatus.authorized;
    debugPrint('🔔 Notification permission: ${settings.authorizationStatus}');

    // Android 13+ notification permission
    if (Platform.isAndroid) {
      final androidPlugin = _localNotif.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    }

    return granted;
  }

  // ─── Save FCM Token ────────────────────────────────────────────────────
  Future<void> saveFcmToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).update({'fcmToken': token});
        debugPrint('🔔 FCM token saved for $uid');
      }

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        _db.collection('users').doc(uid).update({'fcmToken': newToken});
      });
    } catch (e) {
      debugPrint('🔔 FCM token save error: $e');
    }
  }

  // ─── Handle Foreground Messages ─────────────────────────────────────────
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    final isEmergency = message.data['type'] == 'emergency';

    showLocalNotification(
      title: notification.title ?? 'Heal Chain',
      body: notification.body ?? '',
      isEmergency: isEmergency,
      payload: message.data['route'] ?? '',
    );
  }

  // ─── Global navigator key for notification click targeting ─────────────
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // ─── Handle Message Tap (app in background) ────────────────────────────
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 Message opened app: ${message.data}');
    final route = message.data['route'] as String?;
    if (route != null && route.isNotEmpty) {
      _navigateToRoute(route);
    }
  }

  // ─── Notification Tap Handler ───────────────────────────────────────────
  void _onNotifTap(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _navigateToRoute(payload);
    }
  }

  /// Navigate to a route from notification payload
  void _navigateToRoute(String route) {
    try {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        GoRouter.of(ctx).push(route);
      }
    } catch (e) {
      debugPrint('🔔 Navigation error: $e');
    }
  }

  // ─── Show Local Notification ────────────────────────────────────────────
  Future<void> showLocalNotification({
    required String title,
    required String body,
    bool isEmergency = false,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      isEmergency ? _emergencyChannel.id : _generalChannel.id,
      isEmergency ? _emergencyChannel.name : _generalChannel.name,
      channelDescription: isEmergency ? _emergencyChannel.description : _generalChannel.description,
      importance: isEmergency ? Importance.max : Importance.high,
      priority: isEmergency ? Priority.max : Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: isEmergency
          ? Int64List.fromList([0, 500, 200, 500, 200, 500, 200, 500])
          : null,
      fullScreenIntent: isEmergency,
      category: isEmergency ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      ticker: isEmergency ? '🚨 EMERGENCY: $title' : title,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: isEmergency ? '🚨 Emergency Blood Request' : 'Heal Chain',
      ),
      color: const Color(0xFFE53935),
      ledColor: const Color(0xFFE53935),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final details = NotificationDetails(android: androidDetails);

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      isEmergency ? '🚨 $title' : title,
      body,
      details,
      payload: payload,
    );
  }

  // ─── Show Emergency Alert ───────────────────────────────────────────────
  /// Sends emergency notification to a specific donor
  Future<void> sendEmergencyAlert({
    required String donorId,
    required String bloodGroup,
    required String recipientName,
    required String hospital,
    required String requestId,
  }) async {
    // Save notification to Firestore
    await _db.collection('notifications').add({
      'userId': donorId,
      'title': '🚨 Emergency: $bloodGroup Blood Needed!',
      'body': '$recipientName urgently needs $bloodGroup blood at $hospital',
      'type': 'emergency',
      'isRead': false,
      'requestId': requestId,
      'createdAt': Timestamp.now(),
    });

    // Show local notification (for current user if they happen to be the donor)
    await showLocalNotification(
      title: 'Emergency: $bloodGroup Blood Needed!',
      body: '$recipientName urgently needs $bloodGroup blood at $hospital',
      isEmergency: true,
      payload: '/request-detail?id=$requestId',
    );
  }

  // ─── Blood Compatibility Map ──────────────────────────────────────────
  /// Maps recipient blood group → list of donor blood groups that CAN donate to them
  static const Map<String, List<String>> compatibleDonors = {
    'O-':  ['O-'],
    'O+':  ['O-', 'O+'],
    'A-':  ['O-', 'A-'],
    'A+':  ['O-', 'O+', 'A-', 'A+'],
    'B-':  ['O-', 'B-'],
    'B+':  ['O-', 'O+', 'B-', 'B+'],
    'AB-': ['O-', 'A-', 'B-', 'AB-'],
    'AB+': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'],
  };

  /// Returns compatible donor blood groups for a recipient
  static List<String> getCompatibleGroups(String recipientBloodGroup) {
    return compatibleDonors[recipientBloodGroup] ?? [recipientBloodGroup];
  }

  // ─── Notify Matching Donors ─────────────────────────────────────────────
  /// When a blood request is created, notify all COMPATIBLE available donors
  /// in the SAME CITY. Uses blood compatibility table.
  /// `recipientId` is excluded so the request creator doesn't get notified.
  Future<void> notifyMatchingDonors({
    required String bloodGroup,
    required String recipientName,
    required String hospital,
    required String requestId,
    required String urgency,
    required String recipientId,
    String? city,
  }) async {
    try {
      final compatGroups = getCompatibleGroups(bloodGroup);
      final isCritical = urgency.toLowerCase() == 'critical';

      // Firestore 'whereIn' supports up to 10 values (we never exceed 8)
      Query query = _db.collection('users')
          .where('role', isEqualTo: 'donor')
          .where('isAvailable', isEqualTo: true)
          .where('bloodGroup', whereIn: compatGroups);

      final snap = await query.get();
      final now = Timestamp.now();

      // Filter by city, cooldown, and exclude the request creator
      final matchingDocs = snap.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;

        // Exclude the request creator
        if (doc.id == recipientId) return false;

        // Filter by city
        if (city != null) {
          final donorCity = data['city'] as String?;
          if (donorCity == null || donorCity.toLowerCase() != city.toLowerCase()) return false;
        }

        // Filter out donors on cooldown
        final cooldown = data['cooldownUntil'] as Timestamp?;
        if (cooldown != null && cooldown.compareTo(now) > 0) return false;

        return true;
      }).toList();

      final batch = _db.batch();
      for (var doc in matchingDocs) {
        final notifRef = _db.collection('notifications').doc();

        batch.set(notifRef, {
          'userId': doc.id,
          'title': isCritical
              ? '🚨 CRITICAL: $bloodGroup Blood Needed NOW!'
              : '🩸 $bloodGroup Blood Request',
          'body': '$recipientName needs $bloodGroup blood at ${hospital.isEmpty ? "a nearby hospital" : hospital}${city != null ? " in $city" : ""}',
          'type': isCritical ? 'emergency' : 'request',
          'isRead': false,
          'requestId': requestId,
          'createdAt': Timestamp.now(),
        });
      }
      await batch.commit();
      debugPrint('🔔 Notified ${matchingDocs.length} compatible donors ($compatGroups) in ${city ?? "all cities"}');
      // NOTE: Local notification is now handled by startListening() real-time listener
    } catch (e) {
      debugPrint('🔔 Error notifying donors: $e');
    }
  }

  // ─── Real-Time Notification Listener ─────────────────────────────────────
  /// Listens to Firestore 'notifications' for the current user.
  /// Whenever a NEW unread notification appears, fires a local bell/popup.
  /// Call this after login with the user's UID.
  void startListening(String uid) {
    if (_listeningUid == uid) return; // Already listening for this user
    stopListening();
    _listeningUid = uid;

    _notifSub = _db.collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snap) {
          for (var change in snap.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data == null) continue;
              final title = data['title'] as String? ?? 'Heal Chain';
              final body = data['body'] as String? ?? '';
              final type = data['type'] as String? ?? 'general';
              final isEmergency = type == 'emergency';

              showLocalNotification(
                title: title,
                body: body,
                isEmergency: isEmergency,
                payload: data['requestId'] != null ? '/request-detail?id=${data['requestId']}' : '',
              );
            }
          }
        });
    debugPrint('🔔 Started real-time notification listener for $uid');
  }

  /// Stop listening for notifications (on logout)
  void stopListening() {
    _notifSub?.cancel();
    _notifSub = null;
    _listeningUid = null;
  }
}
