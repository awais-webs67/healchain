import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../services/firestore_service.dart';
import '../../../services/ai_chatbot_service.dart';
import '../../../providers/theme_provider.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  final _firestoreService = FirestoreService();
  bool _isLoading = true;

  final _geminiKeyCtrl = TextEditingController();
  final _openRouterKeyCtrl = TextEditingController();
  bool _geminiOn = true;
  bool _openRouterOn = true;
  int _cooldownDays = 56;
  bool _applyingCooldown = false;

  // Recipient type toggles
  bool _typeIndividual = true;
  bool _typeHospital = true;
  bool _typeWelfare = true;
  bool _typeOther = true;

  // Diagnostics
  bool _isTesting = false;
  final List<_LogEntry> _logs = [];
  final _logScroll = ScrollController();

  Color _txt(bool d) => d ? const Color(0xFFEDF0F7) : const Color(0xFF141727);
  Color _sub(bool d) => d ? const Color(0xFF8E96B5) : const Color(0xFF545B77);
  Color _card(bool d) => d ? const Color(0xFF111836) : Colors.white;
  Color _bg(bool d) => d ? const Color(0xFF090D22) : const Color(0xFFF2F3F8);
  Color _bdr(bool d) => d ? const Color(0xFF1C2548) : const Color(0xFFDFE1EE);

  static const _violet = Color(0xFF7C4DFF);
  static const _teal = Color(0xFF0DBFAB);


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _firestoreService.getApiKeys(),
        _firestoreService.getAdminSettings(),
      ]);
      final keys = results[0];
      final config = results[1];
      if (mounted) {
        setState(() {
          _geminiKeyCtrl.text = keys['gemini_key'] ?? '';
          _openRouterKeyCtrl.text = keys['openrouter_key'] ?? '';
          _geminiOn = keys['gemini_enabled'] ?? true;
          _openRouterOn = keys['openrouter_enabled'] ?? true;
          _cooldownDays = config['cooldownDays'] ?? 56;
          _typeIndividual = config['type_individual'] ?? true;
          _typeHospital = config['type_hospital'] ?? true;
          _typeWelfare = config['type_welfare'] ?? true;
          _typeOther = config['type_other'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    await Future.wait([
      _firestoreService.saveApiKeys({
        'gemini_key': _geminiKeyCtrl.text.trim(),
        'openrouter_key': _openRouterKeyCtrl.text.trim(),
        'gemini_enabled': _geminiOn,
        'openrouter_enabled': _openRouterOn,
      }),
      _firestoreService.saveAdminSettings({
        'cooldownDays': _cooldownDays,
        'type_individual': _typeIndividual,
        'type_hospital': _typeHospital,
        'type_welfare': _typeWelfare,
        'type_other': _typeOther,
      }),
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved'), backgroundColor: _teal));
  }

  Future<void> _saveCooldown(int days) async {
    await _firestoreService.saveAdminSettings({'cooldownDays': days});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cooldown set to $days days'), backgroundColor: _teal, duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _applyCooldownToAll(bool isDark) async {
    // Confirm first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Recalculate Cooldowns?', style: TextStyle(color: _txt(isDark), fontWeight: FontWeight.w800)),
        content: Text(
          'This will update every donor who has a lastDonationDate. Their cooldownUntil will be set to lastDonationDate + $_cooldownDays days.\n\nDonors without a donation history will not be affected.',
          style: TextStyle(color: _sub(isDark), fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: _sub(isDark)))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply', style: TextStyle(color: Color(0xFFED8A2F), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _applyingCooldown = true);

    try {
      final db = _firestoreService;
      final users = await db.getAllUsers().first;
      int updated = 0;

      for (final user in users) {
        if (user.lastDonationDate != null) {
          final newCooldown = user.lastDonationDate!.add(Duration(days: _cooldownDays));
          final isAvailable = newCooldown.isBefore(DateTime.now());
          await _firestoreService.updateCooldownForUser(user.uid, newCooldown, isAvailable);
          updated++;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated $updated donors'), backgroundColor: _teal),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFE8395B)),
      );
    }

    if (mounted) setState(() => _applyingCooldown = false);
  }

  void _addLog(String msg, {String status = 'info'}) {
    setState(() => _logs.add(_LogEntry(msg, status)));
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_logScroll.hasClients) {
        _logScroll.animateTo(_logScroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _runTests() async {
    setState(() { _isTesting = true; _logs.clear(); });

    _addLog('Initializing system diagnostics...');
    await Future.delayed(const Duration(milliseconds: 600));

    // Database test
    _addLog('Testing Firestore connection...');
    try {
      final t = DateTime.now();
      await _firestoreService.getAppStats();
      final ms = DateTime.now().difference(t).inMilliseconds;
      _addLog('Database OK — ${ms}ms latency', status: 'ok');
    } catch (e) {
      _addLog('Database FAILED: $e', status: 'error');
    }
    await Future.delayed(const Duration(milliseconds: 500));

    // API key checks + live testing
    _addLog('Validating API keys...');
    await Future.delayed(const Duration(milliseconds: 400));

    final aiService = AiChatbotService.instance;
    aiService.clearConfigCache();

    if (_geminiOn) {
      if (_geminiKeyCtrl.text.trim().isNotEmpty) {
        _addLog('Gemini key present — testing live...');
        final result = await aiService.testProvider('gemini');
        if (result['ok'] == true) {
          _addLog('Gemini API OK — ${result['ms']}ms response', status: 'ok');
        } else {
          _addLog('Gemini API FAILED: ${result['error']}', status: 'error');
        }
      } else {
        _addLog('Gemini enabled but key is empty', status: 'warn');
      }
    } else {
      _addLog('Gemini provider — disabled', status: 'info');
    }

    if (_openRouterOn) {
      if (_openRouterKeyCtrl.text.trim().isNotEmpty) {
        _addLog('OpenRouter key present — testing live...');
        final result = await aiService.testProvider('openrouter');
        if (result['ok'] == true) {
          _addLog('OpenRouter API OK — ${result['ms']}ms response', status: 'ok');
        } else {
          _addLog('OpenRouter API FAILED: ${result['error']}', status: 'error');
        }
      } else {
        _addLog('OpenRouter enabled but key is empty', status: 'warn');
      }
    } else {
      _addLog('OpenRouter provider — disabled', status: 'info');
    }

    await Future.delayed(const Duration(milliseconds: 500));
    _addLog('All checks completed.', status: 'ok');
    setState(() => _isTesting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(backgroundColor: _bg(isDark), body: Center(child: CircularProgressIndicator(color: _violet, strokeWidth: 2.5)));
    }

    return Scaffold(
      backgroundColor: _bg(isDark),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 14),
            decoration: BoxDecoration(color: _card(isDark), border: Border(bottom: BorderSide(color: _bdr(isDark)))),
            child: Row(
              children: [
                Expanded(child: Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _txt(isDark), letterSpacing: -0.4))),
                // Theme toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _bg(isDark), borderRadius: BorderRadius.circular(10), border: Border.all(color: _bdr(isDark))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 16, color: isDark ? const Color(0xFFFFD700) : const Color(0xFFFF9800)),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 24,
                      child: Switch.adaptive(
                        value: isDark,
                        onChanged: (_) => context.read<ThemeProvider>().toggleTheme(),
                        activeTrackColor: _violet.withValues(alpha: 0.5),
                        activeThumbColor: _violet,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── AI Providers ──────────────────────────────────
                _sectionLabel('AI Providers', isDark),
                const SizedBox(height: 10),
                _providerCard(
                  isDark: isDark,
                  name: 'Gemini',
                  subtitle: 'Primary AI — Google DeepMind',
                  enabled: _geminiOn,
                  onToggle: (v) => setState(() => _geminiOn = v),
                  controller: _geminiKeyCtrl,
                  icon: Icons.auto_awesome_rounded,
                  color: _violet,
                ),
                const SizedBox(height: 10),
                _providerCard(
                  isDark: isDark,
                  name: 'OpenRouter',
                  subtitle: 'Fallback AI provider',
                  enabled: _openRouterOn,
                  onToggle: (v) => setState(() => _openRouterOn = v),
                  controller: _openRouterKeyCtrl,
                  icon: Icons.route_rounded,
                  color: _teal,
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: _violet, borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('Save Configuration', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Donation Settings ─────────────────────────────
                _sectionLabel('Donation Settings', isDark),
                const SizedBox(height: 10),
                Container(
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
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: const Color(0xFFED8A2F).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.timer_rounded, color: Color(0xFFED8A2F), size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cooldown Period', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _txt(isDark))),
                                Text('Days between donations', style: TextStyle(fontSize: 10, color: _sub(isDark))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: _bg(isDark), borderRadius: BorderRadius.circular(8), border: Border.all(color: _bdr(isDark))),
                            child: Text('$_cooldownDays days', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _txt(isDark))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: const Color(0xFFED8A2F),
                          inactiveTrackColor: _bdr(isDark),
                          thumbColor: const Color(0xFFED8A2F),
                          overlayColor: const Color(0xFFED8A2F).withValues(alpha: 0.1),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _cooldownDays.toDouble(),
                          min: 0,
                          max: 90,
                          divisions: 90,
                          onChanged: (v) => setState(() => _cooldownDays = v.round()),
                          onChangeEnd: (v) => _saveCooldown(v.round()),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0 days', style: TextStyle(fontSize: 10, color: _sub(isDark))),
                          Text('90 days', style: TextStyle(fontSize: 10, color: _sub(isDark))),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _applyingCooldown ? null : () => _applyCooldownToAll(isDark),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFED8A2F).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFED8A2F).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_applyingCooldown)
                                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFED8A2F)))
                              else
                                const Icon(Icons.sync_rounded, size: 16, color: Color(0xFFED8A2F)),
                              const SizedBox(width: 6),
                              Text(
                                _applyingCooldown ? 'Updating...' : 'Apply to All Existing Users',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFED8A2F)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Recipient Type Settings ───────────────────────
                _sectionLabel('Recipient Signup Types', isDark),
                const SizedBox(height: 4),
                Text('Toggle which requester types appear during signup', style: TextStyle(fontSize: 11, color: _sub(isDark))),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _card(isDark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _bdr(isDark)),
                  ),
                  child: Column(children: [
                    _typeToggle(isDark, '👤  Individual', _typeIndividual, (v) {
                      if (!v && _activeTypeCount <= 1) { _showMinOneSnack(); return; }
                      setState(() => _typeIndividual = v);
                      _save();
                    }),
                    _typeToggle(isDark, '🏥  Hospital', _typeHospital, (v) {
                      if (!v && _activeTypeCount <= 1) { _showMinOneSnack(); return; }
                      setState(() => _typeHospital = v);
                      _save();
                    }),
                    _typeToggle(isDark, '🤝  Welfare Org', _typeWelfare, (v) {
                      if (!v && _activeTypeCount <= 1) { _showMinOneSnack(); return; }
                      setState(() => _typeWelfare = v);
                      _save();
                    }),
                    _typeToggle(isDark, '📋  Other', _typeOther, (v) {
                      if (!v && _activeTypeCount <= 1) { _showMinOneSnack(); return; }
                      setState(() => _typeOther = v);
                      _save();
                    }),
                  ]),
                ),

                const SizedBox(height: 28),

                // ── Diagnostics ───────────────────────────────────
                _sectionLabel('System Diagnostics', isDark),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF21262D)),
                  ),
                  child: Column(
                    children: [
                      // Terminal header bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF161B22),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                        ),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFFF5F57), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE0443E), width: 0.5))),
                            const SizedBox(width: 5),
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFFEBC2E), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFDDA022), width: 0.5))),
                            const SizedBox(width: 5),
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF28C840), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF1FA834), width: 0.5))),
                            const SizedBox(width: 12),
                            const Text('healchain-admin', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, fontFamily: 'monospace')),
                            const Spacer(),
                            if (_isTesting) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Color(0xFF58A6FF), strokeWidth: 1.5)),
                          ],
                        ),
                      ),
                      // Log output
                      SizedBox(
                        height: 180,
                        child: _logs.isEmpty
                            ? const Center(child: Text('Press Run to begin...', style: TextStyle(color: Color(0xFF484F58), fontFamily: 'monospace', fontSize: 12)))
                            : ListView.builder(
                                controller: _logScroll,
                                padding: const EdgeInsets.all(12),
                                itemCount: _logs.length,
                                itemBuilder: (_, i) {
                                  final log = _logs[i];
                                  Color c;
                                  String prefix;
                                  switch (log.status) {
                                    case 'ok': c = const Color(0xFF3FB950); prefix = '✓'; break;
                                    case 'warn': c = const Color(0xFFD29922); prefix = '⚠'; break;
                                    case 'error': c = const Color(0xFFF85149); prefix = '✗'; break;
                                    default: c = const Color(0xFF8B949E); prefix = '›'; break;
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text('$prefix ${log.msg}', style: TextStyle(color: c, fontFamily: 'monospace', fontSize: 11)),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _isTesting ? null : _runTests,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _card(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _bdr(isDark)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 18, color: _txt(isDark)),
                        const SizedBox(width: 6),
                        Text(_logs.isEmpty ? 'Run Diagnostics' : 'Run Again', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _txt(isDark))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Logout ────────────────────────────────────────
                GestureDetector(
                  onTap: () => _logout(isDark),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8395B).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8395B).withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, size: 18, color: Color(0xFFE8395B)),
                        SizedBox(width: 8),
                        Text('Sign Out', style: TextStyle(color: Color(0xFFE8395B), fontSize: 14, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 80),
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

  Widget _providerCard({
    required bool isDark,
    required String name,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bdr(isDark)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _txt(isDark))),
                    Text(subtitle, style: TextStyle(fontSize: 10, color: _sub(isDark))),
                  ],
                ),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: onToggle,
                activeTrackColor: color.withValues(alpha: 0.5),
                activeThumbColor: color,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 12),
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: _bg(isDark),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _bdr(isDark)),
              ),
              child: TextField(
                controller: controller,
                obscureText: true,
                style: TextStyle(fontSize: 13, color: _txt(isDark)),
                decoration: InputDecoration(
                  hintText: 'Paste API key...',
                  hintStyle: TextStyle(color: _sub(isDark), fontSize: 12),
                  prefixIcon: Icon(Icons.key_rounded, size: 16, color: _sub(isDark)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _logout(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out?', style: TextStyle(color: _txt(isDark), fontWeight: FontWeight.w800)),
        content: Text('You will be returned to the login screen.', style: TextStyle(color: _sub(isDark), fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: _sub(isDark)))),
          TextButton(
            onPressed: () async {
              final router = GoRouter.of(context);
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              router.go('/login');
            },
            child: const Text('Sign Out', style: TextStyle(color: Color(0xFFE8395B), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  int get _activeTypeCount =>
    (_typeIndividual ? 1 : 0) + (_typeHospital ? 1 : 0) + (_typeWelfare ? 1 : 0) + (_typeOther ? 1 : 0);

  void _showMinOneSnack() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('At least 1 type must remain enabled'),
      backgroundColor: Color(0xFFED8A2F),
      duration: Duration(seconds: 2),
    ));
  }

  Widget _typeToggle(bool isDark, String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _txt(isDark)))),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: _violet,
          ),
        ],
      ),
    );
  }
}

class _LogEntry {
  final String msg;
  final String status;
  _LogEntry(this.msg, this.status);
}
