import 'package:get_it/get_it.dart';

import 'data/nfce_receipt_repository.dart';
import 'data/shopping_lists_repository.dart';
import 'presenter/view_models/app_view_model.dart';
import 'presenter/view_models/lists_view_model.dart';
import 'presenter/view_models/product_search_view_model.dart';
import 'presenter/view_models/purchases_view_model.dart';
import 'presenter/view_models/qr_market_scanner_view_model.dart';

/// Instância global do GetIt (padrão do pacote).
final sl = GetIt.instance;

/// Registra dependências da aplicação. Chame no [main] após
/// [WidgetsFlutterBinding.ensureInitialized], antes do [runApp].
///
/// É idempotente. Em testes, use `await sl.reset(dispose: true)` no [tearDown].
Future<void> configureDependencies() async {
  if (!sl.isRegistered<AppViewModel>()) {
    sl.registerLazySingleton<AppViewModel>(
      () => AppViewModel(),
      dispose: (c) => c.dispose(),
    );
  }
  if (!sl.isRegistered<ShoppingListsRepository>()) {
    final repo = await ShoppingListsRepository.open();
    sl.registerSingleton<ShoppingListsRepository>(
      repo,
      dispose: (c) => c.dispose(),
    );
  }
  if (!sl.isRegistered<NfceReceiptRepository>()) {
    sl.registerSingleton<NfceReceiptRepository>(
      NfceReceiptRepository(sl<ShoppingListsRepository>().database),
    );
  }
  if (!sl.isRegistered<PurchasesViewModel>()) {
    sl.registerLazySingleton<PurchasesViewModel>(
      () => PurchasesViewModel(sl<NfceReceiptRepository>()),
      dispose: (c) => c.dispose(),
    );
  }
  if (!sl.isRegistered<ProductSearchViewModel>()) {
    sl.registerLazySingleton<ProductSearchViewModel>(
      () => ProductSearchViewModel(sl<NfceReceiptRepository>()),
      dispose: (c) => c.dispose(),
    );
  }
  if (!sl.isRegistered<QrMarketScannerViewModel>()) {
    sl.registerLazySingleton<QrMarketScannerViewModel>(
      () => QrMarketScannerViewModel(
        sl<NfceReceiptRepository>(),
        onReceiptSaved: () {
          sl<PurchasesViewModel>().load();
          sl<ProductSearchViewModel>().load();
          sl<ListsViewModel>().load();
        },
      ),
      dispose: (c) => c.dispose(),
    );
  }
  if (!sl.isRegistered<ListsViewModel>()) {
    final vm = ListsViewModel(
      sl<ShoppingListsRepository>(),
      sl<NfceReceiptRepository>(),
    );
    await vm.load();
    sl.registerSingleton<ListsViewModel>(
      vm,
      dispose: (c) => c.dispose(),
    );
  }
}
