import 'dart:math' as math;

/// Uma linha de produto vinda de uma NFC-e salva (payload do QR).
class PurchasedItemLine {
  const PurchasedItemLine({
    required this.receiptId,
    required this.receiptSavedAtMs,
    required this.receiptEmissionRaw,
    required this.description,
    this.code,
    required this.quantityText,
    this.unit,
    this.unitPrice,
    required this.lineTotal,
    this.brand,
    this.measureLabelOverride,
    this.storeCode,
    this.productPhotoRelativePath,
  });

  final String receiptId;
  final int receiptSavedAtMs;
  final String receiptEmissionRaw;
  final String description;
  final String? code;
  final String quantityText;
  final String? unit;
  final String? unitPrice;
  final String lineTotal;

  /// Preenchido em produtos cadastrados manualmente (fora da NFC-e).
  final String? brand;

  /// Quando não nulo, substitui [describeMeasure] no detalhe do produto.
  final String? measureLabelOverride;

  /// Código interno da loja (ex.: cadastro manual com EAN + código da gôndola).
  final String? storeCode;

  /// Foto do produto manual (`product_photos/…` relativo ao diretório de documentos).
  final String? productPhotoRelativePath;
}

/// Sugestão na lista de compras: última linha do produto nas NFC-e (QR).
class QrProductSuggestion {
  const QrProductSuggestion({
    required this.label,
    this.unitPriceRaw,
    required this.recordedAtMs,
  });

  final String label;
  final String? unitPriceRaw;

  /// `created_at_ms` da nota ao salvar no app; `0` = entrada só do rascunho (sem QR).
  final int recordedAtMs;
}

/// Linha na lista de busca (produto deduplicado).
class ProductSearchRow {
  const ProductSearchRow({
    required this.productKey,
    required this.displayName,
    this.storeCode,
    required this.purchaseCount,
    this.lastUnitPrice,
  });

  /// Chave estável para agrupar ocorrências (`c:…` ou `d:…`).
  final String productKey;
  final String displayName;
  final String? storeCode;
  final int purchaseCount;
  final String? lastUnitPrice;
}

/// Um ponto no histórico de preço (por compra registrada).
class ProductPriceHistoryEntry {
  const ProductPriceHistoryEntry({
    required this.receiptSavedAtMs,
    required this.receiptEmissionRaw,
    required this.unitPrice,
    required this.quantityText,
    this.unit,
    this.lineTotal,
  });

  final int receiptSavedAtMs;
  final String receiptEmissionRaw;
  final String unitPrice;
  final String quantityText;
  final String? unit;
  final String? lineTotal;
}

/// Detalhe agregado para a tela do produto.
class ProductDetailSnapshot {
  const ProductDetailSnapshot({
    required this.displayName,
    this.storeProductCode,
    this.eanOrBarcodeHint,
    this.brand,
    required this.latestUnitPrice,
    required this.measureLabel,
    required this.history,
    this.productPhotoRelativePath,
  });

  final String displayName;

  /// Código interno da loja na nota (não é necessariamente EAN).
  final String? storeProductCode;

  /// Quando o app não tem EAN, fica nulo.
  final String? eanOrBarcodeHint;

  /// Marca: a consulta QR da SEFAZ-MT não envia marca; pode ser inferida no futuro.
  final String? brand;
  final String latestUnitPrice;
  final String measureLabel;
  final List<ProductPriceHistoryEntry> history;

  final String? productPhotoRelativePath;
}

/// Agrupa linhas do SQLite em produtos únicos e monta o detalhe.
abstract final class ProductCatalog {
  static String _normDescription(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Chave usada na lista e no detalhe.
  static String canonicalKey(String? code, String description) {
    final c = code?.trim();
    if (c != null && c.isNotEmpty) {
      return 'c:$c';
    }
    return 'd:${_normDescription(description)}';
  }

  /// Uma sugestão por produto (chave canônica), com preço/data da ocorrência mais recente.
  static List<QrProductSuggestion> buildQrSuggestionsForAutocomplete(
    List<PurchasedItemLine> lines,
  ) {
    if (lines.isEmpty) return [];

    final byKey = <String, PurchasedItemLine>{};
    for (final line in lines) {
      final desc = line.description.trim();
      if (desc.isEmpty) continue;
      final key = canonicalKey(line.code, desc);
      final prev = byKey[key];
      if (prev == null || line.receiptSavedAtMs > prev.receiptSavedAtMs) {
        byKey[key] = line;
      }
    }

    final out = <QrProductSuggestion>[];
    for (final line in byKey.values) {
      final price = line.unitPrice?.trim();
      out.add(
        QrProductSuggestion(
          label: line.description.trim(),
          unitPriceRaw: price != null &&
                  price.isNotEmpty &&
                  price != '—'
              ? price
              : null,
          recordedAtMs: line.receiptSavedAtMs,
        ),
      );
    }
    out.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return out;
  }

  /// Heurística simples para tipo de medida a partir do código UN da nota.
  static String describeMeasure(String? unitRaw, String quantityText) {
    final u = unitRaw?.trim().toUpperCase() ?? '';
    if (u.isEmpty && quantityText.trim().isEmpty) {
      return '—';
    }
    if (u.startsWith('UND') || u == 'UN' || u == 'UNID') {
      return 'Unidade';
    }
    if (u.contains('KG') || u == 'G') {
      return 'Peso (quilograma / grama)';
    }
    if (u.contains('LT') || u == 'L' || u.contains('ML')) {
      return 'Volume (litro / ml)';
    }
    if (u.startsWith('BDJ') || u.startsWith('PCT') || u.startsWith('CX')) {
      return 'Embalagem (${unitRaw ?? '—'})';
    }
    if (unitRaw != null && unitRaw.isNotEmpty) {
      return 'Medida na nota: $unitRaw';
    }
    return 'Qtd: ${quantityText.trim().isEmpty ? '—' : quantityText}';
  }

  static List<ProductSearchRow> buildSearchRows(List<PurchasedItemLine> lines) {
    if (lines.isEmpty) return [];

    final byKey = <String, List<PurchasedItemLine>>{};
    for (final line in lines) {
      final desc = line.description.trim();
      if (desc.isEmpty) continue;
      final key = canonicalKey(line.code, desc);
      byKey.putIfAbsent(key, () => []).add(line);
    }

    final rows = <ProductSearchRow>[];
    for (final e in byKey.entries) {
      final group = e.value;
      group.sort((a, b) => b.receiptSavedAtMs.compareTo(a.receiptSavedAtMs));
      final latest = group.first;
      final code = latest.code?.trim();
      final sc = latest.storeCode?.trim();
      final displayCode = sc != null && sc.isNotEmpty ? sc : code;
      rows.add(
        ProductSearchRow(
          productKey: e.key,
          displayName: latest.description.trim(),
          storeCode:
              displayCode != null && displayCode.isNotEmpty ? displayCode : null,
          purchaseCount: group.length,
          lastUnitPrice: latest.unitPrice?.trim().isNotEmpty == true
              ? latest.unitPrice!.trim()
              : null,
        ),
      );
    }
    rows.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return rows;
  }

  static List<ProductSearchRow> filterRows(
    List<ProductSearchRow> rows,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return rows;
    final qDigits = q.replaceAll(RegExp(r'\D'), '');
    return rows
        .where((r) {
          if (r.displayName.toLowerCase().contains(q)) return true;
          final c = r.storeCode?.toLowerCase();
          if (c != null && c.contains(q)) return true;
          if (qDigits.isNotEmpty && c != null) {
            final cDigits = c.replaceAll(RegExp(r'\D'), '');
            if (cDigits.isNotEmpty && cDigits == qDigits) return true;
          }
          return false;
        })
        .toList();
  }

  /// Localiza a linha da busca cujo código (EAN / interno) bate com o valor lido.
  static ProductSearchRow? rowMatchingBarcode(
    List<ProductSearchRow> rows,
    List<PurchasedItemLine> lines,
    String raw,
  ) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final norm = trimmed.replaceAll(RegExp(r'\D'), '');

    String? keyFound;
    for (final line in lines) {
      final candidates = <String?>[line.code, line.storeCode];
      for (final rawCode in candidates) {
        final c = rawCode?.trim();
        if (c == null || c.isEmpty) continue;
        final cNorm = c.replaceAll(RegExp(r'\D'), '');
        final match = (norm.isNotEmpty && cNorm.isNotEmpty && cNorm == norm) ||
            (norm.isEmpty && c == trimmed);
        if (!match) continue;
        final desc = line.description.trim();
        if (desc.isEmpty) continue;
        keyFound = canonicalKey(line.code, desc);
        break;
      }
      if (keyFound != null) break;
    }

    if (keyFound == null) return null;
    for (final r in rows) {
      if (r.productKey == keyFound) return r;
    }
    return null;
  }

  static ProductDetailSnapshot? buildDetail(
    String productKey,
    List<PurchasedItemLine> allLines,
  ) {
    final matches = allLines
        .where((line) {
          final desc = line.description.trim();
          if (desc.isEmpty) return false;
          return canonicalKey(line.code, desc) == productKey;
        })
        .toList();
    if (matches.isEmpty) return null;

    matches.sort((a, b) => b.receiptSavedAtMs.compareTo(a.receiptSavedAtMs));
    final latest = matches.first;

    final history = matches
        .map(
          (line) => ProductPriceHistoryEntry(
            receiptSavedAtMs: line.receiptSavedAtMs,
            receiptEmissionRaw: line.receiptEmissionRaw,
            unitPrice: line.unitPrice?.trim().isNotEmpty == true
                ? line.unitPrice!.trim()
                : '—',
            quantityText: line.quantityText,
            unit: line.unit,
            lineTotal: line.lineTotal.trim().isNotEmpty ? line.lineTotal : null,
          ),
        )
        .toList();

    final price = latest.unitPrice?.trim().isNotEmpty == true
        ? latest.unitPrice!.trim()
        : '—';

    final code = latest.code?.trim();
    final explicitStore = latest.storeCode?.trim();
    final ean = _looksLikeEan(code) ? code : null;
    final storeProductCode = explicitStore != null && explicitStore.isNotEmpty
        ? explicitStore
        : (code != null && code.isNotEmpty ? code : null);
    final measureLabel = latest.measureLabelOverride?.trim().isNotEmpty == true
        ? latest.measureLabelOverride!.trim()
        : describeMeasure(latest.unit, latest.quantityText);

    return ProductDetailSnapshot(
      displayName: latest.description.trim(),
      storeProductCode: storeProductCode,
      eanOrBarcodeHint: ean,
      brand: latest.brand,
      latestUnitPrice: price,
      measureLabel: measureLabel,
      history: history,
      productPhotoRelativePath: latest.productPhotoRelativePath,
    );
  }

  static bool _looksLikeEan(String? code) {
    if (code == null) return false;
    final digits = code.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 8 && digits == code.replaceAll(RegExp(r'\s'), '');
  }

  static String formatSavedDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static double? _parsePriceToDouble(String raw) {
    final s = raw.trim().replaceAll(' ', '').replaceAll('R\$', '');
    if (s.isEmpty || s == '—') return null;
    final normalized = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  static double? minPriceInHistory(List<ProductPriceHistoryEntry> history) {
    double? minV;
    for (final h in history) {
      final v = _parsePriceToDouble(h.unitPrice);
      if (v == null) continue;
      minV = minV == null ? v : math.min(minV, v);
    }
    return minV;
  }

  static double? maxPriceInHistory(List<ProductPriceHistoryEntry> history) {
    double? maxV;
    for (final h in history) {
      final v = _parsePriceToDouble(h.unitPrice);
      if (v == null) continue;
      maxV = maxV == null ? v : math.max(maxV, v);
    }
    return maxV;
  }
}
