/// ─────────────────────────────────────────────────────────────────────────────
/// ConversationScreen — Real-time chat with donation status stepper
/// ─────────────────────────────────────────────────────────────────────────────
/// Top: Donation status stepper (Confirmed → Coming → Arrived → Donated)
/// Middle: Real-time messages
/// Bottom: Message input OR donation form (when status = 'donated')
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationScreen extends StatefulWidget {
  final String chatId;
  const ConversationScreen({super.key, required this.chatId});
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final ChatService _cs = ChatService();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  int _lastMsgCount = 0;

  // Donation form fields
  final _hospitalCtrl = TextEditingController();
  DateTime _donationDate = DateTime.now();
  int _units = 1;
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  // Cached chat data — prevents full-widget-tree rebuilds that kill the keyboard
  ChatModel? _chat;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().userModel?.uid;
    if (uid != null) _cs.markAsRead(widget.chatId, uid);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _hospitalCtrl.dispose();
    _notesCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(0); // reverse list: 0 = bottom
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myUid = context.watch<AuthProvider>().userModel?.uid ?? '';

    return Scaffold(
      body: StreamBuilder<ChatModel?>(
        stream: _cs.getChatStream(widget.chatId),
        builder: (ctx, chatSnap) {
          // On first load, show spinner until we have data
          if (_initialLoading && chatSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Update cached chat only when the stream emits new data
          if (chatSnap.hasData) {
            _chat = chatSnap.data;
            _initialLoading = false;
          }

          final chat = _chat;
          if (chat == null) {
            return const Center(child: Text('Chat not found'));
          }

          final isDonor = myUid == chat.donorId;
          final otherName = isDonor ? chat.recipientName : chat.donorName;

          return Column(children: [
            // App bar
            _appBar(isDark, otherName, chat),
            // Status stepper
            _statusStepper(isDark, chat, isDonor),
            // Messages
            Expanded(child: _messageList(isDark, chat, myUid)),
            // Input / donation form / confirm / closed
            // Wrapped in a builder keyed on the bottom-bar mode so the
            // TextField is NOT destroyed/recreated by stream updates.
            _bottomSection(isDark, chat, isDonor, myUid),
          ]);
        },
      ),
    );
  }

  /// Returns the correct bottom widget (input bar, form, confirm, or closed)
  /// using a stable key so Flutter reuses the same TextField widget across
  /// StreamBuilder rebuilds, preventing the keyboard from closing.
  Widget _bottomSection(bool isDark, ChatModel chat, bool isDonor, String myUid) {
    if (chat.isClosed) return _closedBanner(isDark);
    if (chat.donationStatus == 'donated' && !isDonor && !chat.recipientConfirmed) {
      return _recipientConfirmBar(isDark, chat);
    }
    if (chat.canFillForm && isDonor) return _donationFormSection(isDark, chat);
    // Stable key keeps the TextField widget alive across rebuilds
    return KeyedSubtree(
      key: const ValueKey('chat_input_bar'),
      child: _inputBar(isDark, chat, myUid),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  APP BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _appBar(bool isDark, String otherName, ChatModel chat) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradientFor(isDark),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
            ),
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              child: Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(otherName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _statusColor(chat.donationStatus),
                  ),
                ),
                const SizedBox(width: 5),
                Text(_statusLabel(chat.donationStatus),
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
              ]),
            ])),
            _bloodBadge(chat.bloodGroup),
          ]),
        ),
      ),
    );
  }

  Widget _bloodBadge(String bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
    ),
    child: Text(bg, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  //  STATUS STEPPER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _statusStepper(bool isDark, ChatModel chat, bool isDonor) {
    final steps = ['Confirmed', 'Coming', 'Arrived', 'Donated', 'Completed'];
    final icons = [Icons.check_circle_rounded, Icons.directions_car_rounded, Icons.location_on_rounded, Icons.water_drop_rounded, Icons.verified_rounded];
    final currentStep = chat.statusStep.clamp(0, 4);
    final nextStatus = ['coming', 'arrived', 'donated'];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Step indicators
        Row(children: List.generate(steps.length, (i) {
          final isComplete = i <= currentStep;
          final isCurrent = i == currentStep;
          final c = isComplete ? _stepColor(i) : (isDark ? AppTheme.textTertiary : AppTheme.lightBorder);

          return Expanded(child: Column(children: [
            Row(children: [
              if (i > 0) Expanded(child: Container(height: 2, color: isComplete ? _stepColor(i) : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder))),
              Container(
                width: isCurrent ? 36 : 28, height: isCurrent ? 36 : 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isComplete ? c : Colors.transparent,
                  border: Border.all(color: c, width: isCurrent ? 2.5 : 1.5),
                  boxShadow: isCurrent ? [BoxShadow(color: c.withValues(alpha: 0.3), blurRadius: 8)] : [],
                ),
                child: Icon(icons[i], size: isCurrent ? 18 : 14, color: isComplete ? Colors.white : c),
              ),
              if (i < steps.length - 1) Expanded(child: Container(height: 2, color: i < currentStep ? _stepColor(i + 1) : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder))),
            ]),
            const SizedBox(height: 4),
            Text(steps[i], style: TextStyle(
              fontSize: 9, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isComplete ? c : (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
            )),
          ]));
        })),

        // Next step button (only donor can advance)
        if (isDonor && currentStep < 3) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              if (currentStep < 3) {
                if (currentStep == 0) {
                  // Show ETA dialog for "Coming"
                  _showEtaDialog(chat);
                } else {
                  _cs.updateDonationStatus(
                    chatId: widget.chatId,
                    newStatus: nextStatus[currentStep],
                    userName: chat.donorName,
                  );
                }
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_stepColor(currentStep + 1), _stepColor(currentStep + 1).withValues(alpha: 0.8)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: _stepColor(currentStep + 1).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icons[currentStep + 1], color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Mark as ${steps[currentStep + 1]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          ),
        ],

        // Show ETA if coming
        if (chat.donationStatus == 'coming' && chat.estimatedTime != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.warning),
              const SizedBox(width: 6),
              Text('ETA: ${chat.estimatedTime}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.warning)),
            ]),
          ),
        ],
      ]),
    );
  }

  void _showEtaDialog(ChatModel chat) {
    final etaCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('🚗 On My Way', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Enter estimated arrival time:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: etaCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. 30 minutes',
                filled: true,
                fillColor: isDark ? AppTheme.darkSurface : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _cs.updateDonationStatus(
                  chatId: widget.chatId,
                  newStatus: 'coming',
                  userName: chat.donorName,
                  estimatedTime: etaCtrl.text.trim().isEmpty ? null : etaCtrl.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: Colors.white),
              child: const Text("I'm Coming"),
            ),
          ],
        );
      },
    );
  }

  Color _stepColor(int step) {
    switch (step) {
      case 0: return AppTheme.info;
      case 1: return AppTheme.warning;
      case 2: return const Color(0xFF8B5CF6);
      case 3: return AppTheme.success;
      case 4: return const Color(0xFF00897B);
      default: return AppTheme.info;
    }
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

  String _statusLabel(String s) {
    switch (s) {
      case 'confirmed': return 'Donation Confirmed';
      case 'coming': return 'On the way...';
      case 'arrived': return 'Arrived at hospital';
      case 'donated': return 'Donation completed ✓';
      case 'completed': return 'Verified & Closed ✓✓';
      default: return s;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MESSAGE LIST
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _messageList(bool isDark, ChatModel chat, String myUid) {
    return StreamBuilder<List<ChatMessage>>(
      stream: _cs.getMessages(widget.chatId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final msgs = snap.data ?? [];
        if (msgs.isEmpty) {
          return Center(child: Text('Send a message to start the conversation',
              style: TextStyle(color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary)));
        }

        // Only scroll when new messages arrive, not on every rebuild
        if (msgs.length != _lastMsgCount) {
          _lastMsgCount = msgs.length;
          _scrollToBottom();
        }

        return ListView.builder(
          controller: _scrollCtrl,
          reverse: true, // newest messages at bottom — natural chat behavior
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: msgs.length,
          addAutomaticKeepAlives: false,
          itemBuilder: (_, i) => _messageBubble(isDark, msgs[msgs.length - 1 - i], myUid),
        );
      },
    );
  }

  Widget _messageBubble(bool isDark, ChatMessage msg, String myUid) {
    final isMe = msg.senderId == myUid;
    final isSystem = msg.type == 'system' || msg.type == 'status_update';

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: msg.type == 'status_update'
                  ? AppTheme.info.withValues(alpha: 0.08)
                  : (isDark ? AppTheme.darkCard : const Color(0xFFF5F5F5)),
              borderRadius: BorderRadius.circular(20),
              border: msg.type == 'status_update'
                  ? Border.all(color: AppTheme.info.withValues(alpha: 0.15))
                  : null,
            ),
            child: Text(msg.text, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppTheme.textSecondary : AppTheme.textDarkSecondary)),
          )),
        ]),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppTheme.primaryRed
              : (isDark ? AppTheme.darkCard : const Color(0xFFF0F0F0)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Text(msg.text, style: TextStyle(fontSize: 14, color: isMe ? Colors.white : null)),
          const SizedBox(height: 4),
          Text(DateFormat('h:mm a').format(msg.sentAt),
              style: TextStyle(fontSize: 9, color: isMe ? Colors.white.withValues(alpha: 0.6) : (isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary))),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  INPUT BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _inputBar(bool isDark, ChatModel chat, String myUid) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(child: TextField(
              controller: _msgCtrl,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                final text = _msgCtrl.text.trim();
                if (text.isEmpty) return;
                final user = context.read<AuthProvider>().userModel;
                if (user == null) return;
                _cs.sendMessage(
                  chatId: widget.chatId,
                  senderId: user.uid,
                  senderName: user.name,
                  text: text,
                );
                _msgCtrl.clear();
                _focusNode.requestFocus(); // Keep keyboard open after send
              },
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: isDark ? AppTheme.textTertiary : AppTheme.textDarkSecondary),
                filled: true,
                fillColor: isDark ? AppTheme.darkCard : const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final text = _msgCtrl.text.trim();
              if (text.isEmpty) return;
              final user = context.read<AuthProvider>().userModel;
              if (user == null) return;
              _cs.sendMessage(
                chatId: widget.chatId,
                senderId: user.uid,
                senderName: user.name,
                text: text,
              );
              _msgCtrl.clear();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: AppTheme.buttonGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DONATION FORM (appears after status = 'donated')
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _donationFormSection(bool isDark, ChatModel chat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: AppTheme.success.withValues(alpha: 0.3), width: 2)),
        boxShadow: [BoxShadow(color: AppTheme.success.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.fact_check_rounded, color: AppTheme.success, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Record Donation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.success)),
              Text('Fill this form to earn +25 points', style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
            ])),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _hospitalCtrl,
            decoration: InputDecoration(
              hintText: chat.hospitalName ?? 'Hospital name',
              labelText: 'Hospital',
              filled: true,
              fillColor: isDark ? AppTheme.darkCard : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _donationDate, firstDate: DateTime(2024), lastDate: DateTime.now());
                if (picked != null) setState(() => _donationDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryRed),
                  const SizedBox(width: 8),
                  Text(DateFormat('MMM dd, yyyy').format(_donationDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            )),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: isDark ? AppTheme.darkCard : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.remove_rounded, size: 18), onPressed: () { if (_units > 1) setState(() => _units--); }, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30)),
                Text('$_units', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(Icons.add_rounded, size: 18), onPressed: () => setState(() => _units++), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30)),
                const Text(' units', style: TextStyle(fontSize: 11)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : () => _submitDonation(chat),
              icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_rounded),
              label: Text(_submitting ? 'Submitting...' : 'Submit Record (+25 pts)', style: const TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _submitDonation(ChatModel chat) async {
    setState(() => _submitting = true);
    try {
      await _cs.recordDonation(
        chatId: widget.chatId,
        donorId: chat.donorId,
        donorName: chat.donorName,
        recipientId: chat.recipientId,
        bloodGroup: chat.bloodGroup,
        hospital: _hospitalCtrl.text.isEmpty ? (chat.hospitalName ?? '') : _hospitalCtrl.text,
        donationDate: _donationDate,
        units: _units,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      );
      // Refresh user data to update points/donationCount
      if (mounted) await context.read<AuthProvider>().refreshUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('🏆 Donation recorded! +25 points awarded'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RECIPIENT CONFIRMATION BAR (after donor marks "donated")
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _recipientConfirmBar(bool isDark, ChatModel chat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: AppTheme.success.withValues(alpha: 0.4), width: 2)),
        boxShadow: [BoxShadow(color: AppTheme.success.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.verified_rounded, color: AppTheme.success, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Donor has donated!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.success)),
              Text('Please confirm you received the blood', style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
            ])),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : () => _confirmReceived(chat),
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded),
              label: Text(_submitting ? 'Confirming...' : 'Confirm Blood Received'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _confirmReceived(ChatModel chat) async {
    setState(() => _submitting = true);
    try {
      final db = FirebaseFirestore.instance;

      // Update chat: recipientConfirmed + completed
      await db.collection('chats').doc(widget.chatId).update({
        'recipientConfirmed': true,
        'donationStatus': 'completed',
      });

      // Update request status to fulfilled
      if (chat.requestId.isNotEmpty) {
        await db.collection('blood_requests').doc(chat.requestId).update({
          'status': 'fulfilled',
          'fulfilledBy': chat.donorId,
        });
      }

      // Disable donor availability + set cooldown (dynamic from admin settings)
      final adminConfig = await db.collection('admin_settings').doc('config').get();
      final cooldownDays = adminConfig.data()?['cooldownDays'] ?? 56;
      final cooldownEnd = DateTime.now().add(Duration(days: cooldownDays));
      await db.collection('users').doc(chat.donorId).update({
        'isAvailable': false,
        'cooldownUntil': Timestamp.fromDate(cooldownEnd),
      });

      // Send system messages
      await _cs.sendMessage(
        chatId: widget.chatId,
        senderId: 'system',
        senderName: 'System',
        text: '✅ ${chat.recipientName} confirmed blood received! Donation verified. Chat closed.',
        type: 'system',
      );

      // Notify donor
      await db.collection('notifications').add({
        'userId': chat.donorId,
        'title': '✅ Donation Confirmed!',
        'body': '${chat.recipientName} confirmed receiving your ${chat.bloodGroup} blood. You are now on a $cooldownDays-day cooldown.',
        'type': 'confirmation',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ Blood received confirmed! Thank you.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CLOSED BANNER (after donation fully completed)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _closedBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFF00897B).withValues(alpha: 0.3), width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.verified_rounded, color: const Color(0xFF00897B), size: 22),
          const SizedBox(width: 10),
          Text('Donation Complete — Chat Closed',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF00897B))),
        ]),
      ),
    );
  }
}
