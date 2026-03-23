import 'dart:convert';

import 'package:http/http.dart' as http;

/// Download da página HTML da consulta NFC-e.
abstract final class NfceHtmlFetch {
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'pt-BR,pt;q=0.9',
  };

  static Future<String> getHtml(Uri url) async {
    final res = await http
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 45));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw NfceFetchException(
        'HTTP ${res.statusCode}',
      );
    }
    final ctype = res.headers['content-type']?.toLowerCase() ?? '';
    if (ctype.contains('iso-8859-1') ||
        ctype.contains('8859-1') ||
        ctype.contains('latin1')) {
      return latin1.decode(res.bodyBytes);
    }
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }
}

class NfceFetchException implements Exception {
  NfceFetchException(this.message);
  final String message;

  @override
  String toString() => message;
}
