import 'package:flutter/foundation.dart';

import '../../data/nfce_receipt_repository.dart';
import '../../data/product_catalog.dart';
import '../../data/shopping_lists_repository.dart';

/// ViewModel da lista de compras única + orquestra o [ShoppingListsRepository].
class ListsViewModel extends ChangeNotifier {
  ListsViewModel(this._repository, this._nfceRepository);

  final ShoppingListsRepository _repository;
  final NfceReceiptRepository _nfceRepository;

  List<ShoppingListLineItem> _lines = [];

  /// Uma sugestão por produto do QR (último preço / data registrada no app).
  List<QrProductSuggestion> _qrSuggestions = [];

  List<ShoppingListLineItem> get lineItems => List.unmodifiable(_lines);

  /// Só os rótulos (atalho para código legado / títulos).
  List<String> get items => _lines.map((e) => e.label).toList();

  Future<void> load() async {
    await _repository.ensureSingletonList();
    _lines = await _repository.loadMainListLineItems();
    final purchased = await _nfceRepository.listAllPurchasedItemLines();
    _qrSuggestions =
        ProductCatalog.buildQrSuggestionsForAutocomplete(purchased);
    notifyListeners();
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
