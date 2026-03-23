import 'package:flutter/foundation.dart';

import '../../data/nfce_receipt_repository.dart';
import '../../data/product_catalog.dart';

class ProductSearchViewModel extends ChangeNotifier {
  ProductSearchViewModel(this._repo);

  final NfceReceiptRepository _repo;

  bool _loading = false;
  bool get loading => _loading;

  String _query = '';
  String get query => _query;

  List<PurchasedItemLine> _lines = [];
  List<ProductSearchRow> _allRows = [];

  List<ProductSearchRow> get visibleRows =>
      ProductCatalog.filterRows(_allRows, _query);

  /// Há pelo menos um produto vindo das notas (antes do filtro de busca).
  bool get hasProducts => _allRows.isNotEmpty;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _lines = await _repo.listAllPurchasedItemLines();
      _allRows = ProductCatalog.buildSearchRows(_lines);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  ProductDetailSnapshot? detailForKey(String productKey) =>
      ProductCatalog.buildDetail(productKey, _lines);

  ProductSearchRow? rowMatchingBarcode(String raw) =>
      ProductCatalog.rowMatchingBarcode(_allRows, _lines, raw);

  ProductSearchRow? rowForProductKey(String productKey) {
    for (final r in _allRows) {
      if (r.productKey == productKey) return r;
    }
    return null;
  }

  /// Linhas agregadas neste produto (mesma chave canônica).
  List<PurchasedItemLine> linesForProductKey(String productKey) {
    return _lines.where((line) {
      final desc = line.description.trim();
      if (desc.isEmpty) return false;
      return ProductCatalog.canonicalKey(line.code, desc) == productKey;
    }).toList();
  }

  /// Só há cadastro manual (nenhuma NFC-e) — aí o produto pode ser editado sem mexer em preços das notas.
  String? editableManualProductId(String productKey) {
    final matches = linesForProductKey(productKey);
    if (matches.isEmpty) return null;
    if (!matches.every((l) => l.receiptId.startsWith('manual_'))) {
      return null;
    }
    final ids = matches.map((l) => l.receiptId).toSet();
    if (ids.length != 1) return null;
    return ids.single;
  }
}
