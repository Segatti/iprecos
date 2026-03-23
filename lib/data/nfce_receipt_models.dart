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
  });

  final String id;
  final String sourceUrl;
  final String emissionRaw;
  final int createdAtMs;
  final int itemCount;

  /// Valor total da nota no HTML (`purchaseTotal` no payload), ex.: `849,13`.
  final String? purchaseTotalRaw;

  static NfceReceiptSummary fromDbRow(Map<String, Object?> row) {
    final payload =
        jsonDecode(row['payload_json']! as String) as Map<String, dynamic>;
    final items = payload['items'] as List<dynamic>? ?? [];
    return NfceReceiptSummary(
      id: row['id']! as String,
      sourceUrl: row['source_url']! as String,
      emissionRaw: row['emission_raw']! as String,
      createdAtMs: row['created_at_ms']! as int,
      itemCount: items.length,
      purchaseTotalRaw: payload['purchaseTotal'] as String?,
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

  static NfceReceiptDetail? fromDbRow(Map<String, Object?> row) {
    try {
      final payload =
          jsonDecode(row['payload_json']! as String) as Map<String, dynamic>;
      final rawItems = payload['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return NfceReceiptDetail(
        id: row['id']! as String,
        sourceUrl: row['source_url']! as String,
        emissionRaw: row['emission_raw']! as String,
        createdAtMs: row['created_at_ms']! as int,
        items: items,
        purchaseTotalRaw: payload['purchaseTotal'] as String?,
        taxesTotalRaw: payload['taxesTotal'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
