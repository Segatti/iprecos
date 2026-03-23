/// Caminhos do [GoRouter] (sem dependência de páginas — evita import cíclico).
abstract final class AppRoutePaths {
  static const home = '/';
  static const lists = '/lists';
  static const scan = '/scan';
  static const search = '/search';
  static const searchScanBarcode = '/search/scan-barcode';
  static const searchRegister = '/search/register';
  static const searchEditManual = '/search/edit-manual';
  static const auth = '/auth';
  static const purchases = '/purchases';
  static const purchaseReceiptItemEdit = '/purchase-receipt-item-edit';
}
