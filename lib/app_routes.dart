import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_injector.dart';
import 'app_route_paths.dart';
import 'data/nfce_receipt_repository.dart';
import 'data/product_catalog.dart';
import 'presenter/pages/auth_page.dart';
import 'presenter/pages/home_page.dart';
import 'presenter/pages/my_list_page.dart';
import 'presenter/pages/product_barcode_scan_page.dart';
import 'presenter/pages/product_detail_page.dart';
import 'presenter/pages/product_edit_manual_page.dart';
import 'presenter/pages/product_register_page.dart';
import 'presenter/pages/product_search_page.dart';
import 'presenter/pages/purchase_detail_page.dart';
import 'presenter/pages/receipt_item_edit_page.dart';
import 'presenter/pages/purchases_page.dart';
import 'presenter/pages/qr_market_scanner_page.dart';
import 'presenter/view_models/app_view_model.dart';
import 'presenter/view_models/lists_view_model.dart';
import 'presenter/view_models/product_search_view_model.dart';
import 'presenter/view_models/purchases_view_model.dart';
import 'presenter/view_models/qr_market_scanner_view_model.dart';

/// Configura o [GoRouter] do app.
///
/// [appViewModel] alimenta [refreshListenable] e a home.
GoRouter createAppRouter(AppViewModel appViewModel) {
  return GoRouter(
    initialLocation: AppRoutePaths.home,
    refreshListenable: appViewModel,
    routes: [
      GoRoute(
        path: AppRoutePaths.home,
        builder: (context, state) {
          final s = appViewModel.session;
          return HomePage(
            userName: s.userName,
            isAuthenticated: s.authenticated,
            onAuthPressed: () {
              if (appViewModel.session.authenticated) {
                appViewModel.signOut();
              } else {
                context.push(AppRoutePaths.auth);
              }
            },
            onMinhasListas: () => context.push(AppRoutePaths.lists),
            onMinhasCompras: () => context.push(AppRoutePaths.purchases),
            onEscanearNota: () => context.push(AppRoutePaths.scan),
            onBuscarProduto: () => context.push(AppRoutePaths.search),
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.lists,
        builder: (context, state) => MyListPage(viewModel: sl<ListsViewModel>()),
      ),
      GoRoute(
        path: AppRoutePaths.purchases,
        builder: (context, state) =>
            PurchasesPage(viewModel: sl<PurchasesViewModel>()),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = Uri.decodeComponent(state.pathParameters['id']!);
              return PurchaseDetailPage(
                receiptId: id,
                repository: sl<NfceReceiptRepository>(),
                productSearchViewModel: sl<ProductSearchViewModel>(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutePaths.purchaseReceiptItemEdit,
        builder: (context, state) {
          final args = state.extra as ReceiptItemEditArgs?;
          if (args == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Editar item')),
              body: const Center(child: Text('Dados inválidos.')),
            );
          }
          return ReceiptItemEditPage(
            args: args,
            repository: sl<NfceReceiptRepository>(),
            productSearchViewModel: sl<ProductSearchViewModel>(),
            listsViewModel: sl<ListsViewModel>(),
          );
        },
      ),
      GoRoute(
        path: AppRoutePaths.scan,
        builder: (context, state) => QrMarketScannerPage(
          viewModel: sl<QrMarketScannerViewModel>(),
        ),
      ),
      GoRoute(
        path: AppRoutePaths.search,
        builder: (context, state) => ProductSearchPage(
          viewModel: sl<ProductSearchViewModel>(),
        ),
        routes: [
          GoRoute(
            path: 'p',
            builder: (context, state) {
              final row = state.extra as ProductSearchRow?;
              if (row == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Produto')),
                  body: const Center(
                    child: Text('Abra o produto pela lista de busca.'),
                  ),
                );
              }
              return ProductDetailPage(
                viewModel: sl<ProductSearchViewModel>(),
                row: row,
              );
            },
          ),
          GoRoute(
            path: 'scan-barcode',
            builder: (context, state) => const ProductBarcodeScanPage(),
          ),
          GoRoute(
            path: 'register',
            builder: (context, state) {
              final args = state.extra as ProductRegisterArgs?;
              return ProductRegisterPage(
                repository: sl<NfceReceiptRepository>(),
                productSearchViewModel: sl<ProductSearchViewModel>(),
                listsViewModel: sl<ListsViewModel>(),
                initialBarcode: args?.initialBarcode,
              );
            },
          ),
          GoRoute(
            path: 'edit-manual',
            builder: (context, state) {
              final id = state.extra as String?;
              if (id == null || id.isEmpty) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Editar produto')),
                  body: const Center(
                    child: Text('Não foi possível abrir a edição.'),
                  ),
                );
              }
              return ProductEditManualPage(
                manualProductId: id,
                repository: sl<NfceReceiptRepository>(),
                productSearchViewModel: sl<ProductSearchViewModel>(),
                listsViewModel: sl<ListsViewModel>(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutePaths.auth,
        builder: (context, state) =>
            AuthPage(appViewModel: appViewModel),
      ),
    ],
  );
}
