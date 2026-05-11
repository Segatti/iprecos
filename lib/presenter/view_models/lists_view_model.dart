import 'package:flutter/foundation.dart';

import '../../data/nfce_receipt_repository.dart';
import '../../data/product_catalog.dart';
import '../../data/shopping_lists_repository.dart';

/// Dados consolidados do catálogo (NFC-e + manual) para uma linha da lista.
@immutable
class ListProductMatch {
  const ListProductMatch({
    this.photoRelativePath,
    this.unitPriceRaw,
    this.recordedAtMs,
  });

  final String? photoRelativePath;
  final String? unitPriceRaw;
  final int? recordedAtMs;

  bool get isEmpty =>
      photoRelativePath == null && unitPriceRaw == null && recordedAtMs == null;
}

/// Resumo agregado da lista de compras (para a tela "Minha lista").
@immutable
class ShoppingListSummary {
  const ShoppingListSummary({
    required this.totalItems,
    required this.unregisteredItems,
    required this.itemsWithPrice,
    required this.estimatedTotalDecimal,
  });

  final int totalItems;

  /// Itens da lista sem produto correspondente no catálogo.
  final int unregisteredItems;

  /// Itens que contribuíram para a estimativa de preço.
  final int itemsWithPrice;

  /// Soma dos preços unitários conhecidos (último preço por item).
  final double estimatedTotalDecimal;
}

/// ViewModel da lista de compras única + orquestra o [ShoppingListsRepository].
class ListsViewModel extends ChangeNotifier {
  ListsViewModel(this._repository, this._nfceRepository);

  final ShoppingListsRepository _repository;
  final NfceReceiptRepository _nfceRepository;

  List<ShoppingListLineItem> _lines = [];

  /// Uma sugestão por produto do QR (último preço / data registrada no app).
  List<QrProductSuggestion> _qrSuggestions = [];

  /// Match por nome normalizado (label.toLowerCase().trim()) → produto.
  Map<String, ListProductMatch> _matchesByLabel = const {};

  List<ShoppingListLineItem> get lineItems => List.unmodifiable(_lines);

  /// Só os rótulos (atalho para código legado / títulos).
  List<String> get items => _lines.map((e) => e.label).toList();

  Future<void> load() async {
    await _repository.ensureSingletonList();
    _lines = await _repository.loadMainListLineItems();
    final purchased = await _nfceRepository.listAllPurchasedItemLines();
    _qrSuggestions =
        ProductCatalog.buildQrSuggestionsForAutocomplete(purchased);
    _matchesByLabel = _buildMatchesByLabel(purchased);
    notifyListeners();
  }

  /// Mantém a mais recente por nome normalizado.
  static Map<String, ListProductMatch> _buildMatchesByLabel(
    List<PurchasedItemLine> purchased,
  ) {
    final byKey = <String, PurchasedItemLine>{};
    for (final line in purchased) {
      final key = _normalizeLabel(line.description);
      if (key.isEmpty) continue;
      final prev = byKey[key];
      if (prev == null || line.receiptSavedAtMs > prev.receiptSavedAtMs) {
        byKey[key] = line;
      }
    }
    return {
      for (final e in byKey.entries)
        e.key: ListProductMatch(
          photoRelativePath: e.value.productPhotoRelativePath,
          unitPriceRaw: _nonEmpty(e.value.unitPrice),
          recordedAtMs:
              e.value.receiptSavedAtMs > 0 ? e.value.receiptSavedAtMs : null,
        ),
    };
  }

  static String _normalizeLabel(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  static String? _nonEmpty(String? s) {
    final t = s?.trim();
    if (t == null || t.isEmpty || t == '—') return null;
    return t;
  }

  /// Localiza foto/preço a partir do rótulo digitado/escolhido na lista.
  ListProductMatch? matchForLabel(String label) {
    final key = _normalizeLabel(label);
    if (key.isEmpty) return null;
    return _matchesByLabel[key];
  }

  /// Resumo: total de itens, soma estimada e itens sem cadastro no catálogo.
  ShoppingListSummary get summary {
    var unregistered = 0;
    var withPrice = 0;
    var sum = 0.0;
    for (final line in _lines) {
      final match = matchForLabel(line.label);
      if (match == null) {
        unregistered++;
      }
      final priceRaw = _nonEmpty(line.lastUnitPrice) ?? match?.unitPriceRaw;
      final price = _parseBrlPrice(priceRaw);
      if (price != null) {
        withPrice++;
        sum += price;
      }
    }
    return ShoppingListSummary(
      totalItems: _lines.length,
      unregisteredItems: unregistered,
      itemsWithPrice: withPrice,
      estimatedTotalDecimal: sum,
    );
  }

  static double? _parseBrlPrice(String? raw) {
    final s = raw?.trim().replaceAll(' ', '').replaceAll('R\$', '') ?? '';
    if (s.isEmpty || s == '—') return null;
    final normalized = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  /// Remove um item da lista pelo índice atual.
  Future<void> removeLineItemAt(int index) async {
    if (index < 0 || index >= _lines.length) return;
    final next = List<ShoppingListLineItem>.from(_lines)..removeAt(index);
    await _repository.replaceMainListLineItems(next);
    await load();
  }

  Future<void> addLineItems(List<ShoppingListLineItem> items) async {
    await _repository.appendMainListLineItems(items);
    await load();
  }

  /// Anexa itens à lista (o título é ignorado na persistência; útil para diálogos legados).
  Future<void> addList({required String title, required List<String> items}) async {
    final trimmed = items
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (trimmed.isEmpty) return;

    await addLineItems([
      for (final s in trimmed) ShoppingListLineItem(label: s),
    ]);
  }

  Future<void> replaceAllLineItems(List<ShoppingListLineItem> lines) async {
    await _repository.replaceMainListLineItems(lines);
    await load();
  }

  Future<void> clearList() async {
    await _repository.clearMainList();
    await load();
  }

  /// Itens distintos (case-insensitive) da lista atual.
  List<String> distinctHistoricalItems() {
    final byLower = <String, String>{};
    for (final line in _lines) {
      final t = line.label.trim();
      if (t.isEmpty) continue;
      final key = t.toLowerCase();
      byLower.putIfAbsent(key, () => t);
    }
    final out = byLower.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  /// Sugestões: produtos do QR (com preço/data) + rascunhos só com nome.
  List<QrProductSuggestion> suggestionsForField(
    String query,
    List<String> draftLabels,
  ) {
    final pool = <String, QrProductSuggestion>{};
    for (final s in _qrSuggestions) {
      pool[s.label.toLowerCase()] = s;
    }
    for (final d in draftLabels) {
      final t = d.trim();
      if (t.isEmpty) continue;
      pool.putIfAbsent(
        t.toLowerCase(),
        () => QrProductSuggestion(label: t, recordedAtMs: 0),
      );
    }
    var values = pool.values.toList();
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      values = values.where((s) => s.label.toLowerCase().contains(q)).toList();
    }
    values.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return values.take(24).toList();
  }

  static String defaultTitleForItems(List<String> items) {
    if (items.isEmpty) return 'Lista';
    if (items.length == 1) return items.single;
    return '${items.first} + ${items.length - 1} itens';
  }
}
