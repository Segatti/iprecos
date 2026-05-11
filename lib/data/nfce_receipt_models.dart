import 'dart:convert';

/// Resumo de uma NFC-e salva (lista).
class NfceReceiptSummary {
  const NfceReceiptSummary({
    required this.id,
    required this.sourceUrl,
    required this.emissionRaw,
    required this.createdAtMs,
    required this.itemCount,
    this.purchaseTotalRaw,
    this.storeName,
  });

  final String id;
  final String sourceUrl;
  final String emissionRaw;
  final int createdAtMs;
  final int itemCount;

  /// Valor total da nota no HTML (`purchaseTotal` no payload), ex.: `849,13`.
  final String? purchaseTotalRaw;

  /// Nome do mercado (`stores`) vinculado à nota, quando houver.
  final String? storeName;

  static NfceReceiptSummary fromDbRow(Map<String, Object?> row) {
    final payload =
        jsonDecode(row['payload_json']! as String) as Map<String, dynamic>;
    final items = payload['items'] as List<dynamic>? ?? [];
    final joinName = (row['store_name'] as String?)?.trim();
    final payloadStore = payload['store'];
    String? nameFromPayload;
    if (payloadStore is Map) {
      final n = payloadStore['name']?.toString().trim();
      if (n != null && n.isNotEmpty) nameFromPayload = n;
    }
    return NfceReceiptSummary(
      id: row['id']! as String,
      sourceUrl: row['source_url']! as String,
      emissionRaw: row['emission_raw']! as String,
      createdAtMs: row['created_at_ms']! as int,
      itemCount: items.length,
      purchaseTotalRaw: payload['purchaseTotal'] as String?,
      storeName: joinName?.isNotEmpty == true
          ? joinName
          : nameFromPayload,
    );
  }
}

/// Detalhe completo para a tela de itens.
class NfceReceiptDetail {
  const NfceReceiptDetail({
    required this.id,
    required this.sourceUrl,
    required this.emissionRaw,
    required this.createdAtMs,
    required this.items,
    this.purchaseTotalRaw,
    this.taxesTotalRaw,
    this.storeName,
    this.storeCnpj,
    this.storeAddressLine,
  });

  final String id;
  final String sourceUrl;
  final String emissionRaw;
  final int createdAtMs;
  final List<Map<String, dynamic>> items;

  /// Texto "Valor total R$:" vindo do HTML (ex.: `849,13`).
  final String? purchaseTotalRaw;

  /// Texto dos tributos totais (Lei 12.741/2012).
  final String? taxesTotalRaw;

  final String? storeName;
  final String? storeCnpj;
  final String? storeAddressLine;

  static NfceReceiptDetail? fromDbRow(
    Map<String, Object?> row, {
    String? joinStoreName,
    String? joinStoreCnpj,
    String? joinStoreAddress,
  }) {
    try {
      final payload =
          jsonDecode(row['payload_json']! as String) as Map<String, dynamic>;
      final rawItems = payload['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      String? storeName;
      String? storeCnpj;
      String? storeAddressLine;
      final st = payload['store'];
      if (st is Map) {
        storeName = st['name']?.toString().trim();
        final emptyName = storeName == null || storeName.isEmpty;
        if (emptyName) storeName = null;
        storeCnpj = st['cnpj']?.toString().trim();
        if (storeCnpj != null && storeCnpj.isEmpty) storeCnpj = null;
        storeAddressLine = st['addressLine']?.toString().trim();
        if (storeAddressLine != null && storeAddressLine.isEmpty) {
          storeAddressLine = null;
        }
      }
      storeName ??= joinStoreName?.trim().isNotEmpty == true
          ? joinStoreName!.trim()
          : null;
      storeCnpj ??= joinStoreCnpj?.trim().isNotEmpty == true
          ? joinStoreCnpj!.trim()
          : null;
      storeAddressLine ??= joinStoreAddress?.trim().isNotEmpty == true
          ? joinStoreAddress!.trim()
          : null;

      return NfceReceiptDetail(
        id: row['id']! as String,
        sourceUrl: row['source_url']! as String,
        emissionRaw: row['emission_raw']! as String,
        createdAtMs: row['created_at_ms']! as int,
        items: items,
        purchaseTotalRaw: payload['purchaseTotal'] as String?,
        taxesTotalRaw: payload['taxesTotal'] as String?,
        storeName: storeName,
        storeCnpj: storeCnpj,
        storeAddressLine: storeAddressLine,
      );
    } catch (_) {
      return null;
    }
  }
}
