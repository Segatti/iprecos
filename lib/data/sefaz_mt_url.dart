/// Validação de URL da consulta NFC-e nos portais SEFAZ estaduais.
abstract final class SefazMtUrl {
  /// `sefaz.<UF>.gov.br` ou `www.sefaz.<UF>.gov.br` (UF = sigla do estado, 2 letras).
  static final _allowedHost = RegExp(
    r'^(www\.)?sefaz\.[a-z]{2}\.gov\.br$',
    caseSensitive: false,
  );

  /// Aceita HTTP e HTTPS e host no formato oficial da SEFAZ estadual.
  static bool isAllowedNfceConsulta(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    return _allowedHost.hasMatch(uri.host.toLowerCase());
  }

  static Uri? tryParseScanned(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return null;
    if (!t.contains('://')) {
      if (t.startsWith('//')) {
        t = 'https:$t';
      } else if (t.startsWith('www.')) {
        t = 'https://$t';
      } else if (_looksLikeSefazHost(t)) {
        t = 'https://$t';
      }
    }
    return Uri.tryParse(t);
  }

  static bool _looksLikeSefazHost(String t) {
    final slash = t.indexOf('/');
    final hostPart = slash == -1 ? t : t.substring(0, slash);
    return _allowedHost.hasMatch(hostPart.toLowerCase());
  }
}
