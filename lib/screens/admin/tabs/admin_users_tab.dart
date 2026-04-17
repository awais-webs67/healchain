import 'package:flutter/material.dart';
import '../../../services/firestore_service.dart';
import '../../../models/user_model.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _firestoreService = FirestoreService();
  String _searchQuery = '';
  String _roleFilter = 'all';

  // ── Colors ────────────────────────────────────────────────────────
  Color _txt(bool d) => d ? const Color(0xFFEDF0F7) : const Color(0xFF141727);
  Color _sub(bool d) => d ? const Color(0xFF8E96B5) : const Color(0xFF545B77);
  Color _card(bool d) => d ? const Color(0xFF111836) : Colors.white;
  Color _bg(bool d) => d ? const Color(0xFF090D22) : const Color(0xFFF2F3F8);
  Color _bdr(bool d) => d ? const Color(0xFF1C2548) : const Color(0xFFDFE1EE);

  static const _violet = Color(0xFF7C4DFF);
  static const _rose = Color(0xFFE8395B);
  static const _amber = Color(0xFFED8A2F);
  static const _teal = Color(0xFF0DBFAB);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _bg(isDark),
      body: Column(
        children: [
          // ── Header + Search ──────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 14),
            decoration: BoxDecoration(
              color: _card(isDark),
              border: Border(bottom: BorderSide(color: _bdr(isDark))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage Users', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _txt(isDark), letterSpacing: -0.4)),
                const SizedBox(height: 14),
                // Search bar
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: _bg(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _bdr(isDark)),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    style: TextStyle(fontSize: 14, color: _txt(isDark)),
                    decoration: InputDecoration(
                      hintText: 'Search name or email...',
                      hintStyle: TextStyle(color: _sub(isDark), fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: _sub(isDark)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Role filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'donor', 'recipient', 'admin'].map((r) {
                      final active = _roleFilter == r;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _roleFilter = r),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: active ? _violet : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: active ? _violet : _bdr(isDark)),
                            ),
                            child: Text(
                              r == 'all' ? 'All' : r[0].toUpperCase() + r.substring(1),
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

          // ── User list ───────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _firestoreService.getAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: _violet, strokeWidth: 2.5));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading users', style: TextStyle(color: _sub(isDark))));
                }

                var users = snapshot.data ?? [];

                // Apply filters
                if (_roleFilter != 'all') {
                  users = users.where((u) => u.role == _roleFilter).toList();
                }
                if (_searchQuery.isNotEmpty) {
                  users = users.where((u) =>
                    u.name.toLowerCase().contains(_searchQuery) ||
                    u.email.toLowerCase().contains(_searchQuery)
                  ).toList();
                }

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off_rounded, size: 40, color: _bdr(isDark)),
                        const SizedBox(height: 8),
                        Text('No users found', style: TextStyle(color: _sub(isDark), fontSize: 14)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _userCard(users[i], isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _userCard(UserModel user, bool isDark) {
    final roleColor = user.role == 'donor' ? _rose : user.role == 'admin' ? _violet : _amber;

    return GestureDetector(
      onTap: () => _openUserSheet(user, isDark),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _bdr(isDark)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: roleColor.withValues(alpha: 0.1),
              backgroundImage: user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null,
              child: user.profileImageUrl == null
                  ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: TextStyle(color: roleColor, fontWeight: FontWeight.w800, fontSize: 16))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _txt(isDark)), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(user.email, style: TextStyle(fontSize: 11, color: _sub(isDark)), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(user.role.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: roleColor, letterSpacing: 0.4)),
                ),
                if (user.isAvailable && user.role == 'donor') ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 5, height: 5, decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Available', style: TextStyle(fontSize: 9, color: _teal, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: _sub(isDark)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  USER DETAIL BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════════
  void _openUserSheet(UserModel user, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(user: user, firestoreService: _firestoreService),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  DETAIL SHEET — full control panel
// ═══════════════════════════════════════════════════════════════════════
class _UserDetailSheet extends StatefulWidget {
  final UserModel user;
  final FirestoreService firestoreService;
  const _UserDetailSheet({required this.user, required this.firestoreService});

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  late UserModel _u;

  @override
  void initState() {
    super.initState();
    _u = widget.user;
  }

  Color _txt(bool d) => d ? const Color(0xFFEDF0F7) : const Color(0xFF141727);
  Color _sub(bool d) => d ? const Color(0xFF8E96B5) : const Color(0xFF545B77);
  Color _card(bool d) => d ? const Color(0xFF111836) : Colors.white;
  Color _bdr(bool d) => d ? const Color(0xFF1C2548) : const Color(0xFFDFE1EE);

  static const _violet = Color(0xFF7C4DFF);
  static const _rose = Color(0xFFE8395B);
  static const _amber = Color(0xFFED8A2F);
  static const _teal = Color(0xFF0DBFAB);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0C1030) : const Color(0xFFF6F7FB);

    String cooldownStr = 'Ready to donate';
    Color cooldownColor = _teal;
    if (_u.cooldownUntil != null && _u.cooldownUntil!.isAfter(DateTime.now())) {
      final diff = _u.cooldownUntil!.difference(DateTime.now());
      cooldownStr = '${diff.inDays}d ${diff.inHours % 24}h remaining';
      cooldownColor = _amber;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: _bdr(isDark), borderRadius: BorderRadius.circular(2))),
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Profile header ────────────────────────────────
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: _violet.withValues(alpha: 0.1),
                      backgroundImage: _u.profileImageUrl != null ? NetworkImage(_u.profileImageUrl!) : null,
                      child: _u.profileImageUrl == null
                          ? Text(_u.name.isNotEmpty ? _u.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 22, color: _violet, fontWeight: FontWeight.w900))
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_u.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _txt(isDark))),
                          Text(_u.email, style: TextStyle(fontSize: 12, color: _sub(isDark))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Stats row ─────────────────────────────────────
                _sectionLabel('Activity', isDark),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _statBox('Donations', _u.donationCount.toString(), _rose, isDark)),
                    const SizedBox(width: 8),
                    Expanded(child: _statBox('Points', _u.points.toString(), _violet, isDark)),
                    const SizedBox(width: 8),
                    Expanded(child: _statBox('Blood', _u.bloodGroup.isNotEmpty ? _u.bloodGroup : '—', _amber, isDark)),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Cooldown ──────────────────────────────────────
                _sectionLabel('Cooldown Timer', isDark),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _card(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cooldownColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, color: cooldownColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(cooldownStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _txt(isDark)))),
                      if (cooldownColor == _amber)
                        GestureDetector(
                          onTap: _resetCooldown,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(color: _rose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _rose)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Role selector ─────────────────────────────────
                _sectionLabel('Role', isDark),
                const SizedBox(height: 10),
                Row(
                  children: ['admin', 'donor', 'recipient'].map((r) {
                    final active = _u.role == r;
                    final c = r == 'admin' ? _violet : r == 'donor' ? _rose : _amber;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _changeRole(r),
                        child: Container(
                          margin: EdgeInsets.only(right: r != 'recipient' ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: active ? c : _card(isDark),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: active ? c : _bdr(isDark)),
                          ),
                          child: Center(
                            child: Text(
                              r[0].toUpperCase() + r.substring(1),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? Colors.white : _sub(isDark)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── User details ──────────────────────────────────
                _sectionLabel('Details', isDark),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _card(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _bdr(isDark)),
                  ),
                  child: Column(
                    children: [
                      _detailRow('Phone', _u.mobile.isNotEmpty ? _u.mobile : '—', isDark),
                      Divider(height: 20, color: _bdr(isDark)),
                      _detailRow('City', _u.city ?? '—', isDark),
                      Divider(height: 20, color: _bdr(isDark)),
                      _detailRow('Country', _u.country ?? '—', isDark),
                      if (_u.role == 'donor') ...[
                        Divider(height: 20, color: _bdr(isDark)),
                        _detailRow('Gender', _u.gender ?? '—', isDark),
                        Divider(height: 20, color: _bdr(isDark)),
                        _detailRow('Hemoglobin', _u.hemoglobin != null ? '${_u.hemoglobin} g/dL' : '—', isDark),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Delete button ─────────────────────────────────
                GestureDetector(
                  onTap: _confirmDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _rose.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _rose.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_forever_rounded, color: _rose, size: 18),
                        SizedBox(width: 8),
                        Text('Delete Account', style: TextStyle(color: _rose, fontSize: 13, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _sub(isDark), letterSpacing: 0.5));
  }

  Widget _statBox(String label, String value, Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bdr(isDark)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: accent)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _sub(isDark))),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: _sub(isDark))),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _txt(isDark))),
      ],
    );
  }

  Future<void> _changeRole(String role) async {
    await widget.firestoreService.updateUserRole(_u.uid, role);
    if (!mounted) return;
    setState(() => _u = _u.copyWith(role: role));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role changed to $role'), backgroundColor: _violet));
  }

  Future<void> _resetCooldown() async {
    await widget.firestoreService.resetUserCooldown(_u.uid);
    if (!mounted) return;
    setState(() => _u = _u.copyWith(cooldownUntil: DateTime.now().subtract(const Duration(days: 1)), isAvailable: true));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cooldown reset'), backgroundColor: _teal));
  }

  void _confirmDelete() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${_u.name}?', style: TextStyle(color: _txt(isDark), fontWeight: FontWeight.w800)),
        content: Text('This will permanently remove the account and all associated data.', style: TextStyle(color: _sub(isDark), fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: _sub(isDark)))),
          TextButton(
            onPressed: () {
              widget.firestoreService.deleteUserRecord(_u.uid);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: _rose, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
