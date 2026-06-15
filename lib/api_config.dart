import "dart:convert";

import "package:flutter/foundation.dart" show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

/// Compile-time override: `--dart-define=API_BASE_URL=http://192.168.1.5:8003/api/v1`
const String kApiBaseFromEnv = String.fromEnvironment("API_BASE_URL");

/// Production bootstrap — first request to read [mobile_api_base_url] from admin.
const String kBootstrapApiBaseUrl = "https://api.kharid.tj/api/v1";

const String _kApiBasePrefsKey = "kharid:api_base_url";
const int _kLocalApiPort = 8003;

String normalizeApiBaseUrl(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;
  while (s.endsWith("/")) {
    s = s.substring(0, s.length - 1);
  }
  final uri = Uri.tryParse(s);
  if (uri == null) return s;
  final path = uri.path;
  if (path.isEmpty || path == "/") {
    return "${uri.origin}/api/v1";
  }
  if (!path.endsWith("/api/v1")) {
    return "$s/api/v1";
  }
  return s;
}

String _defaultDevApiBaseUrl() {
  if (kIsWeb) return "http://localhost:$_kLocalApiPort/api/v1";
  if (defaultTargetPlatform == TargetPlatform.android) {
    return "http://10.0.2.2:$_kLocalApiPort/api/v1";
  }
  return "http://127.0.0.1:$_kLocalApiPort/api/v1";
}

Future<String?> _fetchMobileApiBaseUrl(String discoveryBase) async {
  final base = normalizeApiBaseUrl(discoveryBase);
  final uri = Uri.parse("$base/site-settings/");
  final res = await http
      .get(uri, headers: {"Accept": "application/json"})
      .timeout(const Duration(seconds: 12));
  if (res.statusCode < 200 || res.statusCode >= 300) return null;
  final body = jsonDecode(utf8.decode(res.bodyBytes));
  if (body is! Map) return null;
  final remote = body["mobile_api_base_url"]?.toString().trim();
  if (remote == null || remote.isEmpty) return null;
  return normalizeApiBaseUrl(remote);
}

/// Resolves API base URL: dart-define → admin site-settings → cache → dev/prod fallback.
Future<String> resolveApiBaseUrl() async {
  final fromEnv = kApiBaseFromEnv.trim();
  if (fromEnv.isNotEmpty) return normalizeApiBaseUrl(fromEnv);

  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(_kApiBasePrefsKey)?.trim();

  final discoveryCandidates = <String>[
    if (cached != null && cached.isNotEmpty) cached,
    kBootstrapApiBaseUrl,
  ];

  for (final candidate in discoveryCandidates) {
    try {
      final remote = await _fetchMobileApiBaseUrl(candidate);
      if (remote != null && remote.isNotEmpty) {
        await prefs.setString(_kApiBasePrefsKey, remote);
        return remote;
      }
    } catch (_) {
      // try next candidate
    }
  }

  if (cached != null && cached.isNotEmpty) {
    return normalizeApiBaseUrl(cached);
  }

  if (kDebugMode) return _defaultDevApiBaseUrl();
  return kBootstrapApiBaseUrl;
}

/// Media URLs from API — force HTTPS (required on iOS ATS).
String? normalizeMediaUrl(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.startsWith("http://")) {
    s = "https://${s.substring(7)}";
  }
  return s;
}

/// Хатогии техникӣ → паёми фаҳмо барои корбар.
String friendlyApiError(Object error) {
  final msg = error.toString();
  if (msg.contains("Failed host lookup") ||
      msg.contains("SocketException") ||
      msg.contains("Network is unreachable") ||
      msg.contains("Connection refused") ||
      msg.contains("Connection timed out")) {
    return "Пайвастшавӣ ба сервер муваффақ нашуд.\n"
        "Интернет ё VPN-ро санҷед.\n"
        "Дар браузер кушоед: https://api.kharid.tj";
  }
  return msg.replaceFirst("Exception: ", "");
}
