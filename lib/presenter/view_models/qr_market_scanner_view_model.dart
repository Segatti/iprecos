import 'package:flutter/foundation.dart';

import '../../data/nfce_html_fetch.dart';
import '../../data/nfce_mt_html_parser.dart';
import '../../data/nfce_receipt_repository.dart';
import '../../data/sefaz_mt_url.dart';

/// Dados prontos para o diálogo de mercado (antes de gravar no SQLite).
@immutable
class NfceScanPrepared {
  const NfceScanPrepared({
    required this.trimmedScanned,
    required this.uri,
    required this.parseResult,
    required this.payload,
  });

  final String trimmedScanned;
  final Uri uri;
  final NfceParseResult parseResult;
  final Map<String, dynamic> payload;
}

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
    this.prepared,
  });

  const NfceScanResult.invalidUrl()
      : this._(
          success: false,
          message:
              'Código inválido. Use um link http(s) da consulta NFC-e (sefaz.UF.gov.br).',
          prepared: null,
        );

  const NfceScanResult.parseError()
      : this._(
          success: false,
          message: 'Não foi possível ler os itens desta nota.',
          prepared: null,
        );

  const NfceScanResult.networkError(String msg)
      : this._(success: false, message: msg, prepared: null);

  const NfceScanResult.saved(
    int count, {
    String? purchaseTotalRaw,
    String? taxesTotalRaw,
  }) : this._(
          success: true,
          itemCount: count,
          purchaseTotalRaw: purchaseTotalRaw,
          taxesTotalRaw: taxesTotalRaw,
          prepared: null,
        );

  /// HTML parseado; falta o usuário escolher/confirmar o mercado antes de salvar.
  const NfceScanResult.needsMarket(NfceScanPrepared prepared)
      : this._(
          success: false,
          silent: false,
          prepared: prepared,
        );

  /// Leitor enviou o mesmo código em sequência; não exibir diálogo.
  const NfceScanResult.duplicateSkip()
      : this._(success: false, silent: true, prepared: null);

  final bool success;
  final String? message;
  final int? itemCount;
  final bool silent;

  /// Preenchido quando [saved] com totais extraídos do HTML.
  final String? purchaseTotalRaw;
  final String? taxesTotalRaw;

  /// Preenchido quando [needsMarket].
  final NfceScanPrepared? prepared;

  bool get needsMarketSelection => prepared != null;
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

  /// Evita reprocessar o mesmo QR em sequência após salvar (leitor dispara várias vezes).
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

  /// Baixa e interpreta a nota; **não grava** até [commitPrepared].
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
      return NfceScanResult.needsMarket(
        NfceScanPrepared(
          trimmedScanned: trimmed,
          uri: uri,
          parseResult: parsed,
          payload: payload,
        ),
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

  /// Grava a NFC-e após o usuário informar o mercado.
  ///
  /// [preferredStoreId]: quando o usuário selecionou um mercado da lista e o
  /// nome ainda coincide com esse cadastro, reutiliza o id. Caso contrário,
  /// busca por nome (ignorando maiúsculas) ou cria um novo com CNPJ/endereço
  /// extraídos da nota.
  Future<NfceScanResult> commitPrepared(
    NfceScanPrepared prep, {
    required String marketName,
    String? preferredStoreId,
  }) async {
    final trimmed = marketName.trim();
    if (trimmed.isEmpty) {
      return const NfceScanResult.parseError();
    }
    if (_busy) {
      return const NfceScanResult.duplicateSkip();
    }

    _busy = true;
    notifyListeners();
    try {
      final storeId = await _resolveStoreId(
        trimmed,
        prep.parseResult,
        preferredStoreId: preferredStoreId,
      );

      final payloadCopy = Map<String, dynamic>.from(prep.payload);
      await _nfceRepo.savePayload(
        sourceUrl: prep.uri.toString(),
        emissionRaw: prep.parseResult.emissionRaw.isEmpty
            ? '—'
            : prep.parseResult.emissionRaw,
        payload: payloadCopy,
        storeId: storeId,
      );

      _onReceiptSaved?.call();
      _markProcessed(prep.trimmedScanned);
      return NfceScanResult.saved(
        prep.parseResult.items.length,
        purchaseTotalRaw: prep.parseResult.purchaseTotalRaw,
        taxesTotalRaw: prep.parseResult.taxesTotalRaw,
      );
    } catch (e) {
      return NfceScanResult.networkError('Erro ao salvar: $e');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<List<StoreRecord>> listStores() => _nfceRepo.listStores();

  Future<String> _resolveStoreId(
    String displayName,
    NfceParseResult parsed, {
    String? preferredStoreId,
  }) async {
    if (preferredStoreId != null) {
      final s = await _nfceRepo.getStore(preferredStoreId);
      if (s != null &&
          s.name.trim().toLowerCase() == displayName.toLowerCase()) {
        return s.id;
      }
    }

    final existing = await _nfceRepo.findStoreByNameInsensitive(displayName);
    if (existing != null) return existing.id;

    return _nfceRepo.insertStore(
      name: displayName,
      cnpj: parsed.emitterCnpj,
      addressLine: parsed.emitterAddressLine,
    );
  }
}
