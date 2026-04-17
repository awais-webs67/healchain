/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
/// RequestListScreen â€” Premium My Requests with Active / Ongoing / Completed
/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../services/firestore_service.dart';
import '../../models/blood_request_model.dart';
import '../../providers/auth_provider.dart';

class RequestListScreen extends StatefulWidget {
  const RequestListScreen({super.key});
  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final Set<String> _selected = {};
  bool _selectMode = false;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (_selectMode) setState(() { _selected.clear(); _selectMode = false; });
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

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

  void _selectAll(List<BloodRequestModel> requests) {
    setState(() {
      if (_selected.length == requests.length) {
        _selected.clear();
        _selectMode = false;
      } else {
        _selected.clear();
        _selected.addAll(requests.map((r) => r.id));
      }
    });
  }

  /// CASCADE DELETE â€” deletes request + associated chats + notifications
  Future<void> _cascadeDeleteRequest(String requestId) async {
    final batch = _db.batch();

    // Delete the request itself
    batch.delete(_db.collection('blood_requests').doc(requestId));

    // Find and delete associated chats
    final chatSnap = await _db.collection('chats')
        .where('requestId', isEqualTo: requestId).get();
    for (final chatDoc in chatSnap.docs) {
      // Delete all messages in that chat
      final messagesSnap = await _db.collection('chats').doc(chatDoc.id)
          .collection('messages').get();
      for (final msg in messagesSnap.docs) {
        batch.delete(msg.reference);
      }
      batch.delete(chatDoc.reference);
    }

    // Delete related notifications
    final notifSnap = await _db.collection('notifications')
        .where('requestId', isEqualTo: requestId).get();
    for (final notif in notifSnap.docs) {
      batch.delete(notif.reference);
    }

    await batch.commit();
  }

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $count request${count != 1 ? 's' : ''}?'),
        content: const Text('This will also delete all associated chats and notifications. This action cannot be undone.'),
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
      await _cascadeDeleteRequest(id);
    }
    if (mounted) {
      setState(() { _selected.clear(); _selectMode = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$count request${count != 1 ? 's' : ''} deleted'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().userModel;
    final fs = FirestoreService();

    return Scaffold(
      body: Column(children: [
        // â”€â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A0033), Color(0xFF4A0072), Color(0xFF7B1FA2)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
                    ),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('My Requests', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                    Text('Track & manage blood requests',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                  ])),
                  if (_selectMode) GestureDetector(
                    onTap: () => setState(() { _selected.clear(); _selectMode = false; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // â”€â”€â”€ Tab bar with counts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              StreamBuilder<List<BloodRequestModel>>(
                stream: user?.isDonor == true
                    ? fs.getActiveRequests()
                    : fs.getRequestsByRecipient(user?.uid ?? ''),
                builder: (ctx, snap) {
                  final allRequests = snap.data ?? [];
                  final activeCount = allRequests.where((r) =>
                    r.status == 'active'
                  ).length;
                  final ongoingCount = allRequests.where((r) =>
                    r.status == 'in_progress'
                  ).length;
                  final completedCount = allRequests.where((r) =>
                    r.status == 'fulfilled' || r.status == 'completed'
                  ).length;

                  return TabBar(
                    controller: _tabCtrl,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    tabs: [
                      Tab(child: _tabLabel('Active', activeCount, AppTheme.success)),
                      Tab(child: _tabLabel('Ongoing', ongoingCount, AppTheme.warning)),
                      Tab(child: _tabLabel('Done', completedCount, AppTheme.info)),
                    ],
                  );
                },
              ),
            ]),
          ),
        ),

        // â”€â”€â”€ Tab Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Expanded(
          child: StreamBuilder<List<BloodRequestModel>>(
            stream: user?.isDonor == true
                ? fs.getActiveRequests()
                : fs.getRequestsByRecipient(user?.uid ?? ''),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final allRequests = snap.data ?? [];

              final active = allRequests.where((r) =>
                r.status == 'active'
              ).toList();
              final ongoing = allRequests.where((r) =>
                r.status == 'in_progress'
              ).toList();
              final completed = allRequests.where((r) =>
                r.status == 'fulfilled' || r.status == 'completed'
              ).toList();

              return TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildRequestList(isDark, active, canSelect: true),
                  _buildRequestList(isDark, ongoing, canSelect: false, isOngoing: true),
                  _buildCompletedList(isDark, completed),
                ],
              );
            },
          ),
        ),
      ]),

      // FAB (recipient only)
      floatingActionButton: (user?.isDonor != true) ? FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createRequest),
        backgroundColor: const Color(0xFF7B1FA2),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Request', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
      ) : null,
    );
  }

  Widget _tabLabel(String text, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ],
    );
  }

  Widget _buildRequestList(bool isDark, List<BloodRequestModel> requests, {required bool canSelect, bool isOngoing = false}) {
    if (requests.isEmpty) return _emptyState(isDark, canSelect, isOngoing);

    return Column(children: [
      if (_selectMode && canSelect) _selectBar(isDark, requests),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          physics: const BouncingScrollPhysics(),
          itemCount: requests.length,
          itemBuilder: (_, i) => _requestCard(isDark, requests[i], canSelect, isOngoing),
        ),
      ),
    ]);
  }

  Widget _selectBar(bool isDark, List<BloodRequestModel> requests) {
    final allSelected = _selected.length == requests.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF7B1FA2).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7B1FA2).withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => _selectAll(requests),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(allSelected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20, color: const Color(0xFF7B1FA2)),
            const SizedBox(width: 6),
            Text(allSelected ? 'Deselect All' : 'Select All',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7B1FA2))),
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
                  ? const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)])
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

  Widget _requestCard(bool isDark, BloodRequestModel req, bool canSelect, bool isOngoing) {
    final urgencyColor = req.isCritical ? AppTheme.error : req.isUrgent ? AppTheme.warning : AppTheme.info;
    final statusColor = _statusColor(req.status);
    final isSelected = _selected.contains(req.id);

    return GestureDetector(
      onTap: () {
        if (_selectMode && canSelect) {
          _toggleSelect(req.id);
        } else {
          context.push('${AppRoutes.requestDetail}?id=${req.id}');
        }
      },
      onLongPress: canSelect ? () {
        if (!_selectMode) setState(() => _selectMode = true);
        _toggleSelect(req.id);
      } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [const Color(0xFF7B1FA2).withValues(alpha: 0.08), const Color(0xFF7B1FA2).withValues(alpha: 0.03)])
              : LinearGradient(colors: isDark ? [AppTheme.darkCard, AppTheme.darkCard] : [Colors.white, urgencyColor.withValues(alpha: 0.02)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7B1FA2).withValues(alpha: 0.4)
                : isOngoing
                    ? AppTheme.warning.withValues(alpha: 0.3)
                    : req.isCritical
                        ? AppTheme.error.withValues(alpha: 0.3)
                        : (isDark ? AppTheme.darkBorder : urgencyColor.withValues(alpha: 0.12)),
            width: isSelected ? 1.5 : 1.2,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0 : 0.05), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Selection checkbox
            if (_selectMode && canSelect) ...[
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? const Color(0xFF7B1FA2) : (isDark ? AppTheme.textTertiary : AppTheme.lightBorder),
                size: 24,
              ),
              const SizedBox(width: 10),
            ],
            // Blood group badge â€” rounded square
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: req.isCritical ? [AppTheme.error, AppTheme.accentPink] : [const Color(0xFF7B1FA2), const Color(0xFFAB47BC)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: (req.isCritical ? AppTheme.error : const Color(0xFF7B1FA2)).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Center(child: Text(req.bloodGroup, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(req.recipientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.access_time_rounded, size: 11, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
                const SizedBox(width: 4),
                Text(DateFormat('MMM dd, yyyy â€¢ hh:mm a').format(req.createdAt),
                  style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
              ]),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              child: Text(req.status == 'in_progress' ? 'Ongoing' : req.status[0].toUpperCase() + req.status.substring(1),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
          if (req.hospitalName != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.local_hospital_rounded, size: 14, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(req.hospitalName!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            _infoChip(req.urgency, urgencyColor),
            const SizedBox(width: 8),
            _infoChip('${req.unitsNeeded} unit${req.unitsNeeded > 1 ? 's' : ''}', const Color(0xFF7B1FA2)),
            if (req.city != null) ...[
              const SizedBox(width: 8),
              _infoChip('ðŸ“ ${req.city}', const Color(0xFF00897B)),
            ],
          ]),

          // â”€â”€ Chat button for ongoing requests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (isOngoing) ...[
            const SizedBox(height: 12),
            FutureBuilder<QuerySnapshot>(
              future: _db.collection('chats').where('requestId', isEqualTo: req.id).limit(1).get(),
              builder: (_, chatSnap) {
                if (!chatSnap.hasData || chatSnap.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }
                final chatId = chatSnap.data!.docs.first.id;
                return GestureDetector(
                  onTap: () => context.push('${AppRoutes.conversation}?id=$chatId'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('Open Chat', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ]),
      ),
    );
  }

  Widget _infoChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return AppTheme.success;
      case 'in_progress': return AppTheme.warning;
      case 'fulfilled': case 'completed': return AppTheme.info;
      case 'expired': case 'cancelled': return AppTheme.textTertiary;
      default: return AppTheme.textSecondary;
    }
  }

  Widget _emptyState(bool isDark, bool isActive, bool isOngoing) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF7B1FA2).withValues(alpha: 0.06), shape: BoxShape.circle),
      child: Icon(
        isOngoing ? Icons.hourglass_empty_rounded : isActive ? Icons.inbox_rounded : Icons.check_circle_outline_rounded,
        size: 48,
        color: const Color(0xFF7B1FA2).withValues(alpha: 0.4),
      ),
    ),
    const SizedBox(height: 16),
    Text(
      isOngoing ? 'No Ongoing Requests' : isActive ? 'No Active Requests' : 'No Completed Requests',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    Text(
      isOngoing ? 'Requests accepted by donors will appear here'
        : isActive ? 'Create a new blood request to get started'
        : 'Completed requests will appear here',
      style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
  ]));

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  COMPACT COMPLETED LIST â€” lightweight, no per-card Firestore queries
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildCompletedList(bool isDark, List<BloodRequestModel> requests) {
    if (requests.isEmpty) return _emptyState(isDark, false, false);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      physics: const BouncingScrollPhysics(),
      addAutomaticKeepAlives: false,
      itemCount: requests.length,
      itemBuilder: (_, i) => _completedCard(isDark, requests[i]),
    );
  }

  Widget _completedCard(bool isDark, BloodRequestModel req) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.requestDetail}?id=${req.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.darkCard, const Color(0xFF1B5E20).withValues(alpha: 0.08)]
                : [Colors.white, const Color(0xFF1B5E20).withValues(alpha: 0.04)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.25), width: 1.2),
          boxShadow: [BoxShadow(color: AppTheme.success.withValues(alpha: isDark ? 0.04 : 0.06), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          // Blood group badge â€” green gradient
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF43A047)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: AppTheme.success.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.water_drop_rounded, color: Colors.white, size: 14),
              Text(req.bloodGroup, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(req.recipientName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : AppTheme.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.success),
              const SizedBox(width: 4),
              Text('Fulfilled', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.success)),
              const SizedBox(width: 8),
              Text('â€¢ ${DateFormat('MMM dd').format(req.createdAt)}',
                style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)),
            ]),
            if (req.hospitalName != null) ...[
              const SizedBox(height: 3),
              Text(req.hospitalName!, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.success),
          ),
        ]),
      ),
    );
  }
}
