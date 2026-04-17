import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/firestore_service.dart';
import '../../../models/blood_request_model.dart';

class AdminRequestsTab extends StatefulWidget {
  const AdminRequestsTab({super.key});

  @override
  State<AdminRequestsTab> createState() => _AdminRequestsTabState();
}

class _AdminRequestsTabState extends State<AdminRequestsTab> {
  final _firestoreService = FirestoreService();
  String _urgencyFilter = 'all';

  Color _txt(bool d) => d ? const Color(0xFFEDF0F7) : const Color(0xFF141727);
  Color _sub(bool d) => d ? const Color(0xFF8E96B5) : const Color(0xFF545B77);
  Color _card(bool d) => d ? const Color(0xFF111836) : Colors.white;
  Color _bg(bool d) => d ? const Color(0xFF090D22) : const Color(0xFFF2F3F8);
  Color _bdr(bool d) => d ? const Color(0xFF1C2548) : const Color(0xFFDFE1EE);

  static const _violet = Color(0xFF7C4DFF);
  static const _rose = Color(0xFFE8395B);
  static const _amber = Color(0xFFED8A2F);
  static const _blue = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _bg(isDark),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 14),
            decoration: BoxDecoration(
              color: _card(isDark),
              border: Border(bottom: BorderSide(color: _bdr(isDark))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Blood Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _txt(isDark), letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Text('Moderate and manage all active requests', style: TextStyle(fontSize: 12, color: _sub(isDark))),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'Critical', 'Urgent', 'Normal'].map((f) {
                      final active = _urgencyFilter == f;
                      final c = f == 'Critical' ? _rose : f == 'Urgent' ? _amber : f == 'Normal' ? _blue : _violet;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _urgencyFilter = f),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: active ? c : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: active ? c : _bdr(isDark)),
                            ),
                            child: Text(
                              f == 'all' ? 'All' : f,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : _sub(isDark)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── Request list ────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<BloodRequestModel>>(
              stream: _firestoreService.getActiveRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: _violet, strokeWidth: 2.5));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading requests', style: TextStyle(color: _sub(isDark))));
                }

                var requests = snapshot.data ?? [];
                if (_urgencyFilter != 'all') {
                  requests = requests.where((r) => r.urgency == _urgencyFilter).toList();
                }

                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 40, color: _bdr(isDark)),
                        const SizedBox(height: 8),
                        Text('No open requests', style: TextStyle(color: _sub(isDark), fontSize: 14)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _requestCard(requests[i], isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(BloodRequestModel req, bool isDark) {
    final urgColor = req.isCritical ? _rose : req.isUrgent ? _amber : _blue;
    final time = DateFormat('MMM d, h:mm a').format(req.createdAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bdr(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: urgColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(req.bloodGroup, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: urgColor))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.recipientName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _txt(isDark))),
                    if (req.city != null)
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 12, color: _sub(isDark)),
                          const SizedBox(width: 3),
                          Text('${req.city}${req.country != null ? ', ${req.country}' : ''}', style: TextStyle(fontSize: 11, color: _sub(isDark))),
                        ],
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: urgColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(req.urgency, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: urgColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(time, style: TextStyle(fontSize: 10, color: _sub(isDark))),
              if (req.notes != null && req.notes!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(child: Text('"${req.notes}"', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: _sub(isDark)), overflow: TextOverflow.ellipsis)),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => _confirmDelete(req),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _rose.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 14, color: _rose),
                      const SizedBox(width: 4),
                      const Text('Remove', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _rose)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BloodRequestModel req) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Request?', style: TextStyle(color: _txt(isDark), fontWeight: FontWeight.w800)),
        content: Text('Delete ${req.bloodGroup} request by ${req.recipientName}?', style: TextStyle(color: _sub(isDark), fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: _sub(isDark)))),
          TextButton(
            onPressed: () {
              _firestoreService.deleteRequest(req.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: _rose, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
