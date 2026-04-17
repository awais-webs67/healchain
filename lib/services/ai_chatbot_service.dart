/// ─────────────────────────────────────────────────────────────────────────────
/// AiChatbotService — Gemini + OpenRouter AI with Firestore-backed keys
/// ─────────────────────────────────────────────────────────────────────────────
/// • Reads API keys from Firestore (admin_settings/api_keys)
/// • Tries providers in configured order (Gemini first, then OpenRouter)
/// • Auto-fallback on quota / rate-limit errors
/// • Designed for future admin panel control
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message_model.dart';

class AiChatbotService {
  AiChatbotService._();
  static final AiChatbotService instance = AiChatbotService._();

  // ── Firestore references ────────────────────────────────────────────────
  static const _collection = 'admin_settings';
  static const _doc = 'api_keys';

  // ── Cached config ──────────────────────────────────────────────────────
  Map<String, dynamic>? _config;
  DateTime? _configFetchedAt;
  static const _cacheDuration = Duration(minutes: 10);

  // ── System prompt ──────────────────────────────────────────────────────
  static const _systemPrompt = '''
You are HealChain AI — a friendly, knowledgeable assistant for the HealChain blood donation app.

Your capabilities:
• Answer health questions about blood donation (eligibility, preparation, recovery)
• Explain blood group compatibility (who can donate to whom)
• Guide users through the app (how to search donors, create requests, etc.)
• Provide motivational support for donors
• General health advice related to blood donation

Rules:
• Always be warm, empathetic, and encouraging
• Use emojis sparingly for friendliness (👋 🩸 ✅ etc.)
• For medical emergencies, always advise calling local emergency services
• Keep responses concise but informative (under 200 words when possible)
• Format key information using bullet points or numbered lists
• If asked about topics unrelated to health/blood donation, politely redirect
• Never provide specific medical diagnoses — recommend consulting a doctor
''';

  // ═══════════════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════

  /// Send a message and get AI response. Tries providers in configured order.
  Future<String> sendMessage(
    String userMessage,
    List<ChatMessageModel> history,
  ) async {
    final config = await _getConfig();
    if (config == null) {
      return _fallbackResponse(userMessage);
    }

    final order = List<String>.from(config['provider_order'] ?? ['gemini', 'openrouter']);
    String? lastError;

    for (final provider in order) {
      try {
        if (provider == 'gemini' && (config['gemini_enabled'] ?? true)) {
          final key = config['gemini_key'] as String?;
          if (key != null && key.isNotEmpty) {
            // Try configured model, then fallback models
            final models = [
              config['gemini_model'] ?? 'gemini-2.5-flash',
              'gemini-2.5-flash',
              'gemini-2.0-flash',
            ];
            for (final m in models) {
              try {
                return await _callGemini(key, m, userMessage, history);
              } catch (e) {
                if (m == models.last) rethrow;
                continue;
              }
            }
          }
        } else if (provider == 'openrouter' && (config['openrouter_enabled'] ?? true)) {
          final key = config['openrouter_key'] as String?;
          if (key != null && key.isNotEmpty) {
            // Try configured model, then fallback models
            final models = [
              config['openrouter_model'] ?? 'openrouter/auto',
              'openrouter/auto',
              'google/gemma-3-27b-it:free',
            ];
            for (final m in models) {
              try {
                return await _callOpenRouter(key, m, userMessage, history);
              } catch (e) {
                if (m == models.last) rethrow;
                continue;
              }
            }
          }
        }
      } catch (e) {
        lastError = e.toString();
        // Continue to next provider
        continue;
      }
    }

    // All providers failed
    if (lastError != null) {
      return 'I\'m having trouble connecting right now. Please try again in a moment. 🔄\n\n_(Error: $lastError)_';
    }
    return _fallbackResponse(userMessage);
  }

  /// Test a specific provider — returns {ok: bool, ms: int, error: String?}
  Future<Map<String, dynamic>> testProvider(String provider) async {
    final config = await _getConfig();
    if (config == null) return {'ok': false, 'ms': 0, 'error': 'No config found in Firestore'};

    final sw = Stopwatch()..start();
    try {
      if (provider == 'gemini') {
        final key = config['gemini_key'] as String?;
        if (key == null || key.isEmpty) return {'ok': false, 'ms': 0, 'error': 'Key is empty'};
        await _callGemini(key, config['gemini_model'] ?? 'gemini-2.5-flash', 'Hello, respond with just "OK"', []);
      } else if (provider == 'openrouter') {
        final key = config['openrouter_key'] as String?;
        if (key == null || key.isEmpty) return {'ok': false, 'ms': 0, 'error': 'Key is empty'};
        await _callOpenRouter(key, config['openrouter_model'] ?? 'openrouter/auto', 'Hello, respond with just "OK"', []);
      }
      sw.stop();
      return {'ok': true, 'ms': sw.elapsedMilliseconds, 'error': null};
    } catch (e) {
      sw.stop();
      return {'ok': false, 'ms': sw.elapsedMilliseconds, 'error': e.toString()};
    }
  }

  /// Seeds/updates API keys in Firestore.
  /// Uses merge to update model names without overwriting admin-edited fields.
  static Future<void> seedApiKeysIfMissing({
    String? geminiKey,
    String? openRouterKey,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance.collection(_collection).doc(_doc);
      final snap = await docRef.get();
      if (!snap.exists) {
        // First time: create the full document
        await docRef.set({
          'gemini_key': geminiKey ?? '',
          'openrouter_key': openRouterKey ?? '',
          'gemini_enabled': true,
          'openrouter_enabled': true,
          'gemini_model': 'gemini-2.5-flash',
          'openrouter_model': 'openrouter/auto',
          'provider_order': ['gemini', 'openrouter'],
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        // Doc exists — fix model names if they were set wrong
        final data = snap.data() ?? {};
        final updates = <String, dynamic>{};
        if (data['gemini_model'] == 'gemini-2.0-flash') {
          updates['gemini_model'] = 'gemini-2.5-flash';
        }
        if (data['openrouter_model'] == 'google/gemini-2.0-flash-exp:free' || data['openrouter_model'] == 'google/gemini-2.5-flash-exp:free') {
          updates['openrouter_model'] = 'openrouter/auto';
        }
        // Also set keys if they're empty and we have values
        if ((data['gemini_key'] ?? '').isEmpty && geminiKey != null && geminiKey.isNotEmpty) {
          updates['gemini_key'] = geminiKey;
        }
        if ((data['openrouter_key'] ?? '').isEmpty && openRouterKey != null && openRouterKey.isNotEmpty) {
          updates['openrouter_key'] = openRouterKey;
        }
        if (updates.isNotEmpty) {
          updates['updated_at'] = FieldValue.serverTimestamp();
          await docRef.update(updates);
        }
      }
    } catch (_) {
      // Silently fail — keys can be added via admin panel later
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PRIVATE — Config loading
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> _getConfig() async {
    // Use cache if fresh
    if (_config != null &&
        _configFetchedAt != null &&
        DateTime.now().difference(_configFetchedAt!) < _cacheDuration) {
      return _config;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_doc)
          .get();
      if (snap.exists) {
        _config = snap.data();
        _configFetchedAt = DateTime.now();
        return _config;
      }
    } catch (_) {}
    return null;
  }

  /// Force refresh config (e.g. after admin updates keys)
  void clearConfigCache() {
    _config = null;
    _configFetchedAt = null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PRIVATE — Gemini
  // ═══════════════════════════════════════════════════════════════════════

  Future<String> _callGemini(
    String apiKey,
    String modelName,
    String userMessage,
    List<ChatMessageModel> history,
  ) async {
    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.text(_systemPrompt),
    );

    // Build conversation history for context
    final contents = <Content>[];
    // Include last 10 messages for context
    final recentHistory = history.length > 10 ? history.sublist(history.length - 10) : history;
    for (final msg in recentHistory) {
      if (msg.isUser) {
        contents.add(Content.text(msg.content));
      } else {
        contents.add(Content.model([TextPart(msg.content)]));
      }
    }
    contents.add(Content.text(userMessage));

    final response = await model.generateContent(contents);
    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('Empty response from Gemini');
    }
    return text.trim();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PRIVATE — OpenRouter
  // ═══════════════════════════════════════════════════════════════════════

  Future<String> _callOpenRouter(
    String apiKey,
    String modelName,
    String userMessage,
    List<ChatMessageModel> history,
  ) async {
    final messages = <Map<String, String>>[];
    messages.add({'role': 'system', 'content': _systemPrompt});

    // Include last 10 messages for context
    final recentHistory = history.length > 10 ? history.sublist(history.length - 10) : history;
    for (final msg in recentHistory) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.content,
      });
    }
    messages.add({'role': 'user', 'content': userMessage});

    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://healchain.app',
        'X-Title': 'HealChain',
      },
      body: jsonEncode({
        'model': modelName,
        'messages': messages,
        'max_tokens': 500,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['choices']?[0]?['message']?['content'] as String?;
      if (text == null || text.isEmpty) {
        throw Exception('Empty response from OpenRouter');
      }
      return text.trim();
    } else if (response.statusCode == 429) {
      throw Exception('Rate limited');
    } else {
      throw Exception('OpenRouter error ${response.statusCode}: ${response.body}');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PRIVATE — Fallback (offline / no keys configured)
  // ═══════════════════════════════════════════════════════════════════════

  String _fallbackResponse(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('donor') || lower.contains('find')) {
      return 'I can help you find donors! 🔍\n\n'
          'Use the **Search** tab to filter donors by:\n'
          '• Blood group\n'
          '• City or country\n'
          '• Radius (5-100 km)\n\n'
          'Would you like me to search for a specific blood type?';
    } else if (lower.contains('compatible') || lower.contains('match')) {
      return 'Here\'s the blood group compatibility chart:\n\n'
          '🩸 **O-** → Universal donor\n'
          '🩸 **AB+** → Universal recipient\n'
          '🩸 **A+** can receive from: A+, A-, O+, O-\n'
          '🩸 **B+** can receive from: B+, B-, O+, O-\n\n'
          'What\'s your blood type? I\'ll tell you compatible donors!';
    } else if (lower.contains('eligible') || lower.contains('donate')) {
      return 'To be eligible for blood donation:\n\n'
          '✅ Age: 17-65 years\n'
          '✅ BMI: 18.5-40\n'
          '✅ Hemoglobin: ≥13 g/dL (male), ≥12.5 g/dL (female)\n'
          '✅ No recent illness or infection\n'
          '✅ Weight: at least 50 kg\n\n'
          'Would you like to check your eligibility?';
    }

    return 'I\'m currently in offline mode. AI services will be available once API keys are configured.\n\n'
        'For now, try asking about:\n'
        '• Finding donors\n'
        '• Blood compatibility\n'
        '• Donation eligibility';
  }
}
