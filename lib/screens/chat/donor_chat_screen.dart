/// ─────────────────────────────────────────────────────────────────────────────
/// DonorChatScreen — Premium chat list with multi-select delete
/// ─────────────────────────────────────────────────────────────────────────────
/// Features: multi-select (long-press / select all), bulk delete, status chips,
/// unread badges, premium glassmorphism design.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../providers/auth_provider.dart';

class DonorChatScreen extends StatefulWidget {
  const DonorChatScreen({super.key});
  @override
  State<DonorChatScreen> createState() => _DonorChatScreenState();
}

class _DonorChatScreenState extends State<DonorChatScreen> {
  final ChatService _cs = ChatService();
  final Set<String> _selected = {};
  bool _selectMode = false;

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        if (_selected.isEmpty) _selectMode = false;
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAll(List<ChatModel> chats) {
    setState(() {
      if (_selected.length == chats.length) {
        _selected.clear();
        _selectMode = false;
      } else {
        _selected.clear();
        _selected.addAll(chats.map((c) => c.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $count chat${count != 1 ? 's' : ''}?'),
        content: const Text('This will permanently delete the selected chats and all their messages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    for (final id in _selected.toList()) {
      await _cs.deleteChat(id);
    }
    if (mounted) {
      setState(() { _selected.clear(); _selectMode = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$count chat${count != 1 ? 's' : ''} deleted'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Column(children: [
        // ─── Premium Header ─────────────────────────────────────────
        _header(isDark, user.role),
        const SizedBox(height: 4),

        // ─── Chat List ──────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<ChatModel>>(
            stream: _cs.getUserChats(user.uid),
            builder: (ctx, snap) {
              if (snap.hasError) return _emptyState(isDark);
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final chats = snap.data ?? [];
              if (chats.isEmpty) return _emptyState(isDark);

              return Column(children: [
                // Select bar
                if (_selectMode) _selectBar(isDark, chats),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: chats.length,
                    itemBuilder: (_, i) => _chatCard(isDark, chats[i], user.uid),
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _header(bool isDark, String role) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5C0000), Color(0xFF8B0000), AppTheme.primaryRedDark],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.chat_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Messages', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              Text(
                role == 'donor' ? 'Your donation conversations' : 'Your request conversations',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
              ),
            ])),
            if (_selectMode) GestureDetector(
              onTap: () => setState(() { _selected.clear(); _selectMode = false; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SELECT BAR (select all, delete)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _selectBar(bool isDark, List<ChatModel> chats) {
    final allSelected = _selected.length == chats.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => _selectAll(chats),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(allSelected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20, color: AppTheme.error),
            const SizedBox(width: 6),
            Text(allSelected ? 'Deselect All' : 'Select All',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.error)),
          ]),
        ),
        const Spacer(),
        Text('${_selected.length} selected',
          style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _selected.isNotEmpty ? _deleteSelected : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: _selected.isNotEmpty
                  ? AppTheme.buttonGradient
                  : null,
              color: _selected.isEmpty ? Colors.grey.withValues(alpha: 0.2) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.delete_rounded, size: 16,
                color: _selected.isNotEmpty ? Colors.white : Colors.grey),
              const SizedBox(width: 4),
              Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: _selected.isNotEmpty ? Colors.white : Colors.grey)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CHAT CARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _chatCard(bool isDark, ChatModel chat, String myUid) {
    final isDonor = myUid == chat.donorId;
    final otherName = isDonor ? chat.recipientName : chat.donorName;
    final unread = isDonor ? chat.unreadDonor : chat.unreadRecipient;
    final timeStr = _timeAgo(chat.lastMessageAt);
    final isSelected = _selected.contains(chat.id);

    return GestureDetector(
      onTap: () {
        if (_selectMode) {
          _toggleSelect(chat.id);
        } else {
          context.push('${AppRoutes.conversation}?id=${chat.id}');
        }
      },
      onLongPress: () {
        if (!_selectMode) {
          setState(() => _selectMode = true);
        }
        _toggleSelect(chat.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [AppTheme.error.withValues(alpha: 0.08), AppTheme.error.withValues(alpha: 0.03)])
              : null,
          color: isSelected ? null : (isDark ? AppTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppTheme.error.withValues(alpha: 0.4)
                : unread > 0
                    ? AppTheme.primaryRed.withValues(alpha: 0.3)
                    : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0 : 0.04), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          // Selection checkbox (in select mode)
          if (_selectMode) ...[
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppTheme.error : (isDark ? AppTheme.textTertiary : AppTheme.lightBorder),
              size: 24,
            ),
            const SizedBox(width: 10),
          ],
          // Avatar with blood badge
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [
                  _statusColor(chat.donationStatus).withValues(alpha: 0.7),
                  _statusColor(chat.donationStatus),
                ]),
                boxShadow: [BoxShadow(color: _statusColor(chat.donationStatus).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Center(child: Icon(
                isDonor ? Icons.person_rounded : Icons.volunteer_activism_rounded,
                color: Colors.white, size: 24,
              )),
            ),
            Positioned(bottom: -3, right: -3, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                gradient: AppTheme.buttonGradient,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? AppTheme.darkCard : Colors.white, width: 1.5),
              ),
              child: Text(chat.bloodGroup, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
            )),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(otherName,
                  style: TextStyle(fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(timeStr, style: TextStyle(fontSize: 10, color: unread > 0 ? AppTheme.primaryRed : (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text(chat.lastMessage,
                  style: TextStyle(fontSize: 12, fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                      color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              _statusChip(chat.donationStatus),
            ]),
          ])),
          if (unread > 0 && !_selectMode) ...[
            const SizedBox(width: 8),
            Container(
              width: 24, height: 24,
              decoration: const BoxDecoration(
                gradient: AppTheme.buttonGradient,
                shape: BoxShape.circle,
              ),
              child: Center(child: Text('$unread', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _statusChip(String status) {
    final c = _statusColor(status);
    final labels = {'confirmed': 'Confirmed', 'coming': 'Coming', 'arrived': 'Arrived', 'donated': 'Done', 'completed': 'Closed'};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withValues(alpha: 0.2))),
      child: Text(labels[status] ?? status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed': return AppTheme.info;
      case 'coming': return AppTheme.warning;
      case 'arrived': return const Color(0xFF8B5CF6);
      case 'donated': return AppTheme.success;
      case 'completed': return const Color(0xFF00897B);
      default: return AppTheme.textTertiary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM dd').format(dt);
  }

  Widget _emptyState(bool isDark) {
    final role = context.read<AuthProvider>().userModel?.role ?? 'donor';
    final isDonor = role == 'donor';
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.primaryRed.withValues(alpha: 0.08),
              AppTheme.primaryRed.withValues(alpha: 0.04),
            ]),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.chat_bubble_outline_rounded, size: 52, color: AppTheme.primaryRed.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 24),
        Text('No conversations yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(isDonor
            ? "When you offer to donate blood,\nyou'll chat with the recipient here"
            : "When a donor responds to your request,\nyou'll chat with them here",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary, height: 1.5)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => isDonor ? context.go(AppRoutes.bloodRequests) : context.push(AppRoutes.createRequest),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppTheme.buttonGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Text(isDonor ? 'Browse Requests' : 'Create Request', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ),
      ]),
    ));
  }
}
