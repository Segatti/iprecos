import 'package:flutter/foundation.dart';

import '../../data/nfce_receipt_models.dart';
import '../../data/nfce_receipt_repository.dart';

/// Totais do mês filtrado na tela de compras.
@immutable
class PurchasesMonthSummary {
  const PurchasesMonthSummary({
    required this.receiptCount,
    required this.totalItems,
    required this.sumPurchaseDecimal,
    required this.receiptsWithTotal,
  });

  final int receiptCount;
  final int totalItems;

  /// Soma dos totais das notas em que `purchaseTotalRaw` pôde ser interpretado.
  final double sumPurchaseDecimal;

  /// Quantas notas entraram na soma monetária (as demais só entram na contagem de notas/itens).
  final int receiptsWithTotal;
}

/// Lista de compras escaneadas (NFC-e salvas).
class PurchasesViewModel extends ChangeNotifier {
  PurchasesViewModel(this._repository)
      : _filterYear = DateTime.now().year,
        _filterMonth = DateTime.now().month;

  final NfceReceiptRepository _repository;

  List<NfceReceiptSummary> _receipts = [];
  bool _loading = false;

  int _filterYear;
  int _filterMonth;

  List<NfceReceiptSummary> get receipts => List.unmodifiable(_receipts);
  bool get loading => _loading;

  int get filterYear => _filterYear;
  int get filterMonth => _filterMonth;

  /// Notas cuja data de **salvamento no app** cai no mês/ano filtrados (fuso local).
  List<NfceReceiptSummary> get filteredReceipts {
    return _receipts.where((r) {
      final d = DateTime.fromMillisecondsSinceEpoch(r.createdAtMs);
      return d.year == _filterYear && d.month == _filterMonth;
    }).toList();
  }

  PurchasesMonthSummary get monthSummary {
    final list = filteredReceipts;
    var totalItems = 0;
    double sum = 0;
    var withTotal = 0;
    for (final r in list) {
      totalItems += r.itemCount;
      final v = _parseBrlTotal(r.purchaseTotalRaw);
      if (v != null) {
        sum += v;
        withTotal++;
      }
    }
    return PurchasesMonthSummary(
      receiptCount: list.length,
      totalItems: totalItems,
      sumPurchaseDecimal: sum,
      receiptsWithTotal: withTotal,
    );
  }

  static double? _parseBrlTotal(String? raw) {
    final s = raw?.trim().replaceAll(' ', '').replaceAll('R\$', '') ?? '';
    if (s.isEmpty || s == '—') return null;
    final normalized = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  void setFilterMonthYear(int year, int month) {
    if (month < 1 || month > 12) return;
    if (_filterYear == year && _filterMonth == month) return;
    _filterYear = year;
    _filterMonth = month;
    notifyListeners();
  }

  /// Ao abrir a tela: mês e ano atuais.
  void resetFilterToNow() {
    final now = DateTime.now();
    _filterYear = now.year;
    _filterMonth = now.month;
    notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _receipts = await _repository.listReceipts();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
