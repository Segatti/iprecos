import 'package:flutter/foundation.dart';

import '../../data/nfce_receipt_models.dart';
import '../../data/nfce_receipt_repository.dart';

/// Lista de compras escaneadas (NFC-e salvas).
class PurchasesViewModel extends ChangeNotifier {
  PurchasesViewModel(this._repository);

  final NfceReceiptRepository _repository;

  List<NfceReceiptSummary> _receipts = [];
  bool _loading = false;

  List<NfceReceiptSummary> get receipts => List.unmodifiable(_receipts);
  bool get loading => _loading;

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
