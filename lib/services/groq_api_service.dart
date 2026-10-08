import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/supabase_service.dart';

/// Groq API client for ultra-fast AI Executive Summaries.
///
/// Two transport paths:
///
///  * **Shared (default)** — when the user has not supplied their own key, the
///    request goes through the `groq-proxy` Supabase Edge Function with the
///    signed-in user's JWT. The shared Groq key is held server-side as a
///    function secret and never ships in the app binary, and the function
///    enforces the user's monthly tier quota.
///  * **User-supplied key** — if the user saves their own Groq key, it is used
///    directly against Groq's OpenAI-compatible endpoint (their key, their
///    bill) and the server quota is bypassed.
class GroqApiService {
  GroqApiService._();

  static final GroqApiService instance = GroqApiService._();

  static const String _keyPrefsKey = 'groq.apiKey.v1';
  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _proxyFunction = 'groq-proxy';

  /// Primary fast Groq model.
  ///
  /// `groq/compound` and `groq/compound-mini` were decommissioned by Groq on
  /// 2026-09-21; GPT-OSS 120B is the current production workhorse with built-in
  /// reasoning. See https://console.groq.com/docs/models.
  static const String defaultModel = 'openai/gpt-oss-120b';

  String? _customApiKey;
  bool _loaded = false;

  /// The user's own Groq key, or `''` when calls go through the server proxy.
  String get apiKey => _customApiKey?.trim() ?? '';

  /// True when a Groq call can be made: the user supplied their own key, or
  /// the server proxy is reachable (Supabase is configured).
  bool get isConfigured => apiKey.isNotEmpty || SupabaseService.isInitialized;

  /// Load custom key override from SharedPreferences.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _customApiKey = prefs.getString(_keyPrefsKey);
    } catch (_) {
      _customApiKey = null;
    }
  }

  /// Override with a user-supplied custom API key.
  Future<void> setCustomApiKey(String key) async {
    _customApiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrefsKey, _customApiKey!);
  }

  /// Clear the custom override (reverts to the server-side shared key).
  Future<void> clearCustomApiKey() async {
    _customApiKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPrefsKey);
  }

  /// Generates AI content via Groq.
  ///
  /// [feature] selects the server-side quota bucket when running on the shared
  /// key: `summary`, `budget_plan` (both metered) or `intent` (unmetered).
  /// [maxTokens] and [temperature] are optional so the AI Budget Planner can
  /// request a larger JSON response without touching the summary defaults.
  Future<String> generateSummary({
    required String systemPrompt,
    required String userPrompt,
    String model = defaultModel,
    int? maxTokens,
    double? temperature,
    String feature = 'summary',
  }) async {
    await load();

    final key = apiKey;
    if (key.isNotEmpty) {
      return _callGroqDirect(
        apiKey: key,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        model: model,
        maxTokens: maxTokens ?? 450,
        temperature: temperature ?? 0.3,
      );
    }

    return _callGroqProxy(
      feature: feature,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      model: model,
      maxTokens: maxTokens ?? 450,
      temperature: temperature ?? 0.3,
    );
  }

  /// Direct call to Groq using the user's own key.
  Future<String> _callGroqDirect({
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required String model,
    required int maxTokens,
    required double temperature,
  }) async {
    final uri = Uri.parse(_endpoint);
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
      // GPT-OSS models reason before answering and max_tokens covers both;
      // minimal effort keeps the full budget for the visible content.
      'reasoning_effort': 'low',
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        debugPrint(
            'Groq API error ${response.statusCode}: ${response.body}');
        throw GroqApiException(
          'Groq API error (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      return _extractText(response.body);
    } on FormatException catch (e) {
      throw GroqApiException('Failed to parse Groq API response: $e');
    }
  }

  /// Shared-key call through the `groq-proxy` Edge Function. The function
  /// verifies the caller's JWT, enforces the tier quota and forwards the prompt
  /// to Groq with the server-held key.
  Future<String> _callGroqProxy({
    required String feature,
    required String systemPrompt,
    required String userPrompt,
    required String model,
    required int maxTokens,
    required double temperature,
  }) async {
    final client = SupabaseService.clientOrNull;
    if (client == null) {
      throw const GroqApiException(
        'AI features need a connection — sign in and try again.',
      );
    }
    if (AuthService.instance.currentUserId == null) {
      throw const GroqApiException('Sign in to use AI features.');
    }

    try {
      final response = await client.functions
          .invoke(
            _proxyFunction,
            body: {
              'feature': feature,
              'model': model,
              'systemPrompt': systemPrompt,
              'userPrompt': userPrompt,
              'temperature': temperature,
              'maxTokens': maxTokens,
            },
          )
          .timeout(const Duration(seconds: 25));

      final data = response.data;
      if (data is Map && data['text'] is String) {
        return (data['text'] as String).trim();
      }
      return '';
    } on FunctionException catch (e) {
      debugPrint('Groq proxy error ${e.status}: ${e.details}');
      throw GroqApiException(
        _proxyErrorMessage(e),
        statusCode: e.status,
      );
    } on TimeoutException {
      throw const GroqApiException('AI request timed out. Please try again.');
    } on FormatException catch (e) {
      throw GroqApiException('Failed to parse Groq API response: $e');
    }
  }

  String _proxyErrorMessage(FunctionException e) {
    final details = e.details;
    final error = details is Map ? details['error'] : null;
    if (error == 'quota_exceeded') {
      return 'Monthly AI quota reached.';
    }
    if (e.status == 401) {
      return 'Sign in to use AI features.';
    }
    if (e.status == 502) {
      return 'AI service is temporarily unavailable.';
    }
    return 'AI request failed (${e.status}).';
  }

  /// Parses the OpenAI-compatible `choices[0].message.content` payload.
  String _extractText(String responseBody) {
    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) return '';

    final firstChoice = choices.first as Map<String, dynamic>;
    final message = firstChoice['message'] as Map<String, dynamic>?;
    if (message == null) return '';

    final text = message['content'] as String? ?? '';
    return text.trim();
  }
}

/// Custom Exception for Groq API errors.
class GroqApiException implements Exception {
  final String message;
  final int? statusCode;

  const GroqApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
