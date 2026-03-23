import 'package:flutter_test/flutter_test.dart';
import 'package:iprecos/app_injector.dart';
import 'package:iprecos/data/nfce_receipt_repository.dart';
import 'package:iprecos/data/shopping_lists_repository.dart';
import 'package:iprecos/presenter/view_models/app_view_model.dart';
import 'package:iprecos/presenter/view_models/lists_view_model.dart';
import 'package:iprecos/presenter/view_models/product_search_view_model.dart';
import 'package:iprecos/presenter/view_models/purchases_view_model.dart';
import 'package:iprecos/presenter/view_models/qr_market_scanner_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await sl.reset(dispose: true);
  });

  group('configureDependencies', () {
    test('registra AppViewModel', () async {
      await configureDependencies();

      expect(sl.isRegistered<AppViewModel>(), isTrue);
    });

    test('registra ShoppingListsRepository', () async {
      await configureDependencies();

      expect(sl.isRegistered<ShoppingListsRepository>(), isTrue);
    });

    test('registra ListsViewModel', () async {
      await configureDependencies();

      expect(sl.isRegistered<ListsViewModel>(), isTrue);
    });

    test(
        'registra NfceReceiptRepository, PurchasesViewModel, ProductSearchViewModel e QrMarketScannerViewModel',
        () async {
      await configureDependencies();

      expect(sl.isRegistered<NfceReceiptRepository>(), isTrue);
      expect(sl.isRegistered<PurchasesViewModel>(), isTrue);
      expect(sl.isRegistered<ProductSearchViewModel>(), isTrue);
      expect(sl.isRegistered<QrMarketScannerViewModel>(), isTrue);
    });

    test('retorna a mesma instância em múltiplos get', () async {
      await configureDependencies();

      final a = sl<AppViewModel>();
      final b = sl<AppViewModel>();

      expect(identical(a, b), isTrue);
    });

    test('é idempotente se chamado mais de uma vez', () async {
      await configureDependencies();
      await configureDependencies();

      expect(() => sl<AppViewModel>(), returnsNormally);
      expect(() => sl<ShoppingListsRepository>(), returnsNormally);
      expect(() => sl<ListsViewModel>(), returnsNormally);
      expect(() => sl<NfceReceiptRepository>(), returnsNormally);
      expect(() => sl<PurchasesViewModel>(), returnsNormally);
      expect(() => sl<ProductSearchViewModel>(), returnsNormally);
      expect(() => sl<QrMarketScannerViewModel>(), returnsNormally);
    });
  });
}
