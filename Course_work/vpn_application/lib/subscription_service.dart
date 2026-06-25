import 'dart:convert';
import 'dart:io';

class SubscriptionService {
  static const _linkSchemes = [
    'vless://',
    'vmess://',
    'trojan://',
    'ss://',
    'hy2://',
    'hy://',
    'tuic://',
    'wg://',
    'ssh://',
  ];

  static Future<List<String>> fetchConfigLinks(String input) async {
    final url = resolveSubscriptionUrl(input);
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'v2rayN/6.52');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }
      final body = await response.transform(utf8.decoder).join();
      return parseSubscriptionBody(body);
    } finally {
      client.close();
    }
  }

  static String resolveSubscriptionUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('sub://')) {
      final payload = trimmed.substring(6);
      final decoded = _tryBase64Decode(payload);
      if (decoded != null && decoded.startsWith('http')) {
        return decoded;
      }
    }
    throw FormatException('Unsupported subscription format: $trimmed');
  }

  static List<String> parseSubscriptionBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return [];

    String content = trimmed;
    final decoded = _tryBase64Decode(trimmed.replaceAll('\n', ''));
    if (decoded != null && _containsProxyLink(decoded)) {
      content = decoded;
    }

    return content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && isProxyLink(line))
        .toList();
  }

  static bool isProxyLink(String link) {
    final lower = link.toLowerCase();
    return _linkSchemes.any(lower.startsWith);
  }

  static bool _containsProxyLink(String text) {
    return text.split('\n').any((line) => isProxyLink(line.trim()));
  }

  static String? _tryBase64Decode(String input) {
    for (final normalized in [
      input,
      input.replaceAll('-', '+').replaceAll('_', '/'),
    ]) {
      try {
        final padded = normalized.padRight(
          normalized.length + (4 - normalized.length % 4) % 4,
          '=',
        );
        return utf8.decode(base64.decode(padded));
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
