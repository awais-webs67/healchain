/// ─────────────────────────────────────────────────────────────────────────────
/// NotificationCenterScreen — Real Firestore notifications
/// ─────────────────────────────────────────────────────────────────────────────
/// Reads from: notifications collection (filtered by userId)
/// Auto-generates notifications from: chat status changes, blood requests, etc.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.buttonGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Notifications', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text('Your alerts & updates', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
              ])),
              GestureDetector(
                onTap: () => _clearAll(context, user.uid),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Clear All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.error)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Notification list from Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: user.uid)
                  .limit(50)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  // Fallback: show empty state on errors (e.g., missing index)
                  return _emptyState(context, isDark);
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return _emptyState(context, isDark);

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _notifCard(context, isDark, docs[i]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _notifCard(BuildContext context, bool isDark, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'Notification';
    final body = data['body'] ?? '';
    final type = data['type'] ?? 'info';
    final isRead = data['isRead'] ?? false;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    final iconData = _iconForType(type);
    final color = _colorForType(type);

    return GestureDetector(
      onTap: () {
        // Mark as read
        if (!isRead) {
          doc.reference.update({'isRead': true});
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: !isRead
              ? color.withValues(alpha: isDark ? 0.08 : 0.04)
              : (isDark ? AppTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: !isRead ? color.withValues(alpha: 0.25) : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0 : 0.03), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(iconData, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: TextStyle(fontWeight: !isRead ? FontWeight.w700 : FontWeight.w600, fontSize: 14))),
              if (createdAt != null) Text(_timeAgo(createdAt), style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
            ]),
            const SizedBox(height: 4),
            Text(body, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary, height: 1.4)),
          ])),
          if (!isRead) Container(
            width: 8, height: 8, margin: const EdgeInsets.only(top: 6, left: 6),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ]),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'emergency': return Icons.emergency_rounded;
      case 'donation': return Icons.water_drop_rounded;
      case 'chat': return Icons.chat_rounded;
      case 'points': return Icons.stars_rounded;
      case 'status': return Icons.update_rounded;
      case 'request': return Icons.person_search_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'emergency': return AppTheme.error;
      case 'donation': return AppTheme.primaryRed;
      case 'chat': return AppTheme.info;
      case 'points': return const Color(0xFFF59E0B);
      case 'status': return const Color(0xFF8B5CF6);
      case 'request': return AppTheme.warning;
      default: return AppTheme.info;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd').format(dt);
  }

  Future<void> _clearAll(BuildContext context, String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    final snap = await FirebaseFirestore.instance.collection('notifications')
        .where('userId', isEqualTo: uid).get();
    for (var doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('All notifications cleared'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Widget _emptyState(BuildContext context, bool isDark) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.info.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.notifications_off_outlined, size: 52, color: AppTheme.info.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 24),
        Text('No notifications', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text("You're all caught up! 🎉\nNew alerts will appear here.", textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary, height: 1.5)),
      ]),
    ));
  }
}
