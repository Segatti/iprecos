import 'package:flutter/foundation.dart';

import '../../data/nfce_html_fetch.dart';
import '../../data/nfce_mt_html_parser.dart';
import '../../data/nfce_receipt_repository.dart';
import '../../data/sefaz_mt_url.dart';

/// Resultado do processamento do QR da nota.
@immutable
class NfceScanResult {
  const NfceScanResult._({
    required this.success,
    this.message,
    this.itemCount,
    this.silent = false,
    this.purchaseTotalRaw,
    this.taxesTotalRaw,
  });

  const NfceScanResult.invalidUrl()
      : this._(
          success: false,
          message:
              'Código inválido. Use um link http(s) da consulta NFC-e (sefaz.UF.gov.br).',
        );

  const NfceScanResult.parseError()
      : this._(
          success: false,
          message: 'Não foi possível ler os itens desta nota.',
        );

  const NfceScanResult.networkError(String msg)
      : this._(success: false, message: msg);

  const NfceScanResult.saved(
    int count, {
    String? purchaseTotalRaw,
    String? taxesTotalRaw,
  }) : this._(
          success: true,
          itemCount: count,
          purchaseTotalRaw: purchaseTotalRaw,
          taxesTotalRaw: taxesTotalRaw,
        );

  /// Leitor enviou o mesmo código em sequência; não exibir diálogo.
  const NfceScanResult.duplicateSkip()
      : this._(success: false, silent: true);

  final bool success;
  final String? message;
  final int? itemCount;
  final bool silent;

  /// Preenchido quando [saved] com totais extraídos do HTML.
  final String? purchaseTotalRaw;
  final String? taxesTotalRaw;
}

/// ViewModel: validar URL SEFAZ-MT, baixar HTML, parsear e gravar SQLite.
class QrMarketScannerViewModel extends ChangeNotifier {
  QrMarketScannerViewModel(
    this._nfceRepo, {
    void Function()? onReceiptSaved,
  }) : _onReceiptSaved = onReceiptSaved;

  final NfceReceiptRepository _nfceRepo;
  final void Function()? _onReceiptSaved;

  bool _busy = false;
  bool get busy => _busy;

  String? _lastProcessedKey;
  DateTime? _lastProcessedAt;

  /// Evita reprocessar o mesmo QR em sequência (leitor dispara várias vezes).
  bool _shouldSkipDuplicate(String raw) {
    final now = DateTime.now();
    if (_lastProcessedKey == raw &&
        _lastProcessedAt != null &&
        now.difference(_lastProcessedAt!) < const Duration(seconds: 4)) {
      return true;
    }
    return false;
  }

  void _markProcessed(String raw) {
    _lastProcessedKey = raw;
    _lastProcessedAt = DateTime.now();
  }

  Future<NfceScanResult> processScannedValue(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const NfceScanResult.parseError();
    }
    if (_busy) {
      return const NfceScanResult.duplicateSkip();
    }
    if (_shouldSkipDuplicate(trimmed)) {
      return const NfceScanResult.duplicateSkip();
    }

    final uri = SefazMtUrl.tryParseScanned(trimmed);
    if (uri == null || !SefazMtUrl.isAllowedNfceConsulta(uri)) {
      return const NfceScanResult.invalidUrl();
    }

    _busy = true;
    notifyListeners();

    try {
      final html = await NfceHtmlFetch.getHtml(uri);
      final parsed = NfceMtHtmlParser.parse(html);
      if (parsed == null) {
        return const NfceScanResult.parseError();
      }

      final payload = parsed.toJson(uri.toString());
      await _nfceRepo.savePayload(
        sourceUrl: uri.toString(),
        emissionRaw:
            parsed.emissionRaw.isEmpty ? '—' : parsed.emissionRaw,
        payload: payload,
      );

      _onReceiptSaved?.call();
      _markProcessed(trimmed);
      return NfceScanResult.saved(
        parsed.items.length,
        purchaseTotalRaw: parsed.purchaseTotalRaw,
        taxesTotalRaw: parsed.taxesTotalRaw,
      );
    } on NfceFetchException catch (e) {
      return NfceScanResult.networkError('Falha ao baixar a página: $e');
    } catch (e) {
      return NfceScanResult.networkError('Erro: $e');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
