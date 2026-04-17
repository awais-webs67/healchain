import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../services/firestore_service.dart';
import '../../../models/user_model.dart';
import '../../../models/blood_request_model.dart';

class AdminStatsTab extends StatefulWidget {
  const AdminStatsTab({super.key});

  @override
  State<AdminStatsTab> createState() => _AdminStatsTabState();
}

class _AdminStatsTabState extends State<AdminStatsTab> {
  final _firestoreService = FirestoreService();
  Map<String, int> _stats = {};
  List<UserModel> _recentUsers = [];
  List<BloodRequestModel> _activeRequests = [];
  bool _isLoading = true;
  bool _usersExpanded = false;
  bool _requestsExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      // Run all three queries in parallel for speed
      final results = await Future.wait([
        _firestoreService.getAppStats(),
        _firestoreService.getAllUsers().first,
        _firestoreService.getActiveRequests().first,
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, int>;
          _recentUsers = (results[1] as List<UserModel>);
          _activeRequests = (results[2] as List<BloodRequestModel>);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Colors — explicit for perfect contrast ────────────────────────
  Color _txt(bool d) => d ? const Color(0xFFEDF0F7) : const Color(0xFF141727);
  Color _sub(bool d) => d ? const Color(0xFF8E96B5) : const Color(0xFF545B77);
  Color _card(bool d) => d ? const Color(0xFF111836) : Colors.white;
  Color _bg(bool d) => d ? const Color(0xFF090D22) : const Color(0xFFF2F3F8);
  Color _bdr(bool d) => d ? const Color(0xFF1C2548) : const Color(0xFFDFE1EE);

  static const _violet = Color(0xFF7C4DFF);
  static const _rose = Color(0xFFE8395B);
  static const _amber = Color(0xFFED8A2F);
  static const _teal = Color(0xFF0DBFAB);
  static const _blue = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bg(isDark),
        body: Center(child: CircularProgressIndicator(color: _violet, strokeWidth: 2.5)),
      );
    }

    return Scaffold(
      backgroundColor: _bg(isDark),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isLoading = true);
          await _loadAll();
        },
        color: _violet,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _header(isDark),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _metricGrid(isDark),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _chartsRow(isDark),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _collapsibleSection(
                isDark: isDark,
                title: 'Recent Registrations',
                subtitle: '${_recentUsers.length} users',
                icon: Icons.person_add_alt_1_rounded,
                iconColor: _violet,
                expanded: _usersExpanded,
                onToggle: () => setState(() => _usersExpanded = !_usersExpanded),
                items: _recentUsers,
                itemBuilder: (u) => _userTile(u as UserModel, isDark),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _collapsibleSection(
                isDark: isDark,
                title: 'Active Requests',
                subtitle: '${_activeRequests.length} open',
                icon: Icons.bloodtype_rounded,
                iconColor: _rose,
                expanded: _requestsExpanded,
                onToggle: () => setState(() => _requestsExpanded = !_requestsExpanded),
                items: _activeRequests,
                itemBuilder: (r) => _requestTile(r as BloodRequestModel, isDark),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  HEADER — clean, minimal
  // ═══════════════════════════════════════════════════════════════════
  Widget _header(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 20),
      decoration: BoxDecoration(
        color: _card(isDark),
        border: Border(bottom: BorderSide(color: _bdr(isDark))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _violet.withValues(alpha: 0.12),
            child: const Icon(Icons.shield_rounded, color: _violet, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _txt(isDark), letterSpacing: -0.4)),
                Text(DateFormat('EEE, MMM d · h:mm a').format(DateTime.now()), style: TextStyle(fontSize: 12, color: _sub(isDark))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _teal.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('Live', style: TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  METRIC GRID — 2 rows of 3, compact
  // ═══════════════════════════════════════════════════════════════════
  Widget _metricGrid(bool isDark) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _metricTile(isDark, _stats['totalUsers'] ?? 0, 'Users', Icons.groups_2_rounded, _violet)),
          const SizedBox(width: 10),
          Expanded(child: _metricTile(isDark, _stats['donors'] ?? 0, 'Donors', Icons.favorite_rounded, _rose)),
          const SizedBox(width: 10),
          Expanded(child: _metricTile(isDark, _stats['recipients'] ?? 0, 'Recipients', Icons.person_outline_rounded, _blue)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _metricTile(isDark, _stats['activeRequests'] ?? 0, 'Requests', Icons.local_hospital_rounded, _amber)),
          const SizedBox(width: 10),
          Expanded(child: _metricTile(isDark, _stats['totalDonations'] ?? 0, 'Donations', Icons.water_drop_rounded, _teal)),
          const SizedBox(width: 10),
          Expanded(child: _metricTile(isDark, _stats['activeChats'] ?? 0, 'Chats', Icons.forum_rounded, const Color(0xFF8B5CF6))),
        ]),
      ],
    );
  }

  Widget _metricTile(bool isDark, int value, String label, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: _card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bdr(isDark)),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 8),
          Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _txt(isDark), height: 1)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _sub(isDark)), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CHARTS — Pie + Bar side-by-side, fixed height
  // ═══════════════════════════════════════════════════════════════════
  Widget _chartsRow(bool isDark) {
    return SizedBox(
      height: 180,
      child: Row(
        children: [
          Expanded(child: _pieChart(isDark)),
          const SizedBox(width: 10),
          Expanded(child: _barChart(isDark)),
        ],
      ),
    );
  }

  Widget _pieChart(bool isDark) {
    final d = (_stats['donors'] ?? 0).toDouble();
    final r = (_stats['recipients'] ?? 0).toDouble();
    final a = (_stats['admins'] ?? 0).toDouble();
    final noData = d + r + a == 0;

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
          Text('User Split', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _txt(isDark))),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 18,
                    startDegreeOffset: -90,
                    sections: noData
                        ? [PieChartSectionData(color: _bdr(isDark), value: 1, title: '', radius: 14)]
                        : [
                            PieChartSectionData(color: _rose, value: d, title: '', radius: 14),
                            PieChartSectionData(color: _violet, value: r, title: '', radius: 14),
                            if (a > 0) PieChartSectionData(color: _amber, value: a, title: '', radius: 14),
                          ],
                  )),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dotLabel(_rose, '${d.toInt()}', 'Donors', isDark),
                      const SizedBox(height: 6),
                      _dotLabel(_violet, '${r.toInt()}', 'Recip.', isDark),
                      if (a > 0) ...[
                        const SizedBox(height: 6),
                        _dotLabel(_amber, '${a.toInt()}', 'Admin', isDark),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dotLabel(Color c, String num, String lbl, bool isDark) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(num, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _txt(isDark), height: 1)),
            Text(lbl, style: TextStyle(fontSize: 9, color: _sub(isDark))),
          ],
        ),
      ],
    );
  }

  Widget _barChart(bool isDark) {
    final active = (_stats['activeRequests'] ?? 0).toDouble();
    final fulfilled = (_stats['fulfilledRequests'] ?? 0).toDouble();
    final chats = (_stats['activeChats'] ?? 0).toDouble();
    final maxY = [active, fulfilled, chats, 1.0].reduce((a, b) => a > b ? a : b) + 2;

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
          Text('Activity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _txt(isDark))),
          const SizedBox(height: 8),
          Expanded(
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 24,
                  getTitlesWidget: (v, _) {
                    const l = ['Open', 'Done', 'Chat'];
                    return v.toInt() < l.length
                        ? Padding(padding: const EdgeInsets.only(top: 4), child: Text(l[v.toInt()], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _sub(isDark))))
                        : const SizedBox();
                  },
                )),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                _barGroup(0, active, _amber),
                _barGroup(1, fulfilled, _teal),
                _barGroup(2, chats, _blue),
              ],
            )),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double val, Color c) {
    return BarChartGroupData(x: x, barRods: [
      BarChartRodData(
        toY: val, color: c, width: 16,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        backDrawRodData: BackgroundBarChartRodData(show: true, toY: val + 2, color: c.withValues(alpha: 0.06)),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  COLLAPSIBLE SECTION — tap to expand, scroll inside
  // ═══════════════════════════════════════════════════════════════════
  Widget _collapsibleSection({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool expanded,
    required VoidCallback onToggle,
    required List<dynamic> items,
    required Widget Function(dynamic) itemBuilder,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bdr(isDark)),
      ),
      child: Column(
        children: [
          // Header — tappable
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _txt(isDark))),
                        Text(subtitle, style: TextStyle(fontSize: 11, color: _sub(isDark))),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: _sub(isDark), size: 22),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text('No data available', style: TextStyle(color: _sub(isDark), fontSize: 13)),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, i) => Divider(height: 1, color: _bdr(isDark)),
                      itemBuilder: (_, i) => itemBuilder(items[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── User tile ─────────────────────────────────────────────────────
  Widget _userTile(UserModel u, bool isDark) {
    final roleColor = u.role == 'donor' ? _rose : u.role == 'admin' ? _violet : _amber;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: roleColor.withValues(alpha: 0.1),
            backgroundImage: u.profileImageUrl != null ? NetworkImage(u.profileImageUrl!) : null,
            child: u.profileImageUrl == null
                ? Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?', style: TextStyle(color: roleColor, fontWeight: FontWeight.w800, fontSize: 12))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _txt(isDark)), overflow: TextOverflow.ellipsis),
                Text(u.email, style: TextStyle(fontSize: 10, color: _sub(isDark)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
            child: Text(u.role.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: roleColor, letterSpacing: 0.3)),
          ),
        ],
      ),
    );
  }

  // ── Request tile ──────────────────────────────────────────────────
  Widget _requestTile(BloodRequestModel r, bool isDark) {
    final urgColor = r.isCritical ? _rose : r.isUrgent ? _amber : _blue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: urgColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(r.bloodGroup, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: urgColor))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.recipientName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _txt(isDark)), overflow: TextOverflow.ellipsis),
                if (r.city != null) Text(r.city!, style: TextStyle(fontSize: 10, color: _sub(isDark))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: urgColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
            child: Text(r.urgency, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: urgColor)),
          ),
        ],
      ),
    );
  }
}
