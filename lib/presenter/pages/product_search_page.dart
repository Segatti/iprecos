import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_route_paths.dart';
import 'product_register_page.dart';
import '../view_models/product_search_view_model.dart';

class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({super.key, required this.viewModel});

  final ProductSearchViewModel viewModel;

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.viewModel.load();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode(BuildContext context) async {
    final code = await context.push<String>(AppRoutePaths.searchScanBarcode);
    if (!context.mounted || code == null || code.isEmpty) return;
    await widget.viewModel.load();
    if (!context.mounted) return;
    final row = widget.viewModel.rowMatchingBarcode(code);
    if (row != null) {
      context.push('${AppRoutePaths.search}/p', extra: row);
    } else {
      context.push(
        AppRoutePaths.searchRegister,
        extra: ProductRegisterArgs(initialBarcode: code),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar produto')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Nome ou código da nota',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onChanged: widget.viewModel.setQuery,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () => _scanBarcode(context),
              icon: const Icon(Icons.barcode_reader),
              label: const Text('Buscar por código de barras'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Itens das notas escaneadas (QR SEFAZ-MT).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.viewModel,
              builder: (context, _) {
                final vm = widget.viewModel;
                if (vm.loading && !vm.hasProducts) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (vm.visibleRows.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: vm.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.25,
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              !vm.hasProducts
                                  ? 'Nenhum item ainda.\nEscaneie uma nota na home.'
                                  : 'Nenhum resultado para “${vm.query}”.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: vm.load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: vm.visibleRows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final row = vm.visibleRows[index];
                      final price = row.lastUnitPrice;
                      final subtitle = StringBuffer();
                      if (row.storeCode != null) {
                        subtitle.write('Cód. nota: ${row.storeCode}');
                      }
                      if (price != null) {
                        if (subtitle.isNotEmpty) subtitle.write(' · ');
                        subtitle.write('Últ. unit. R\$ $price');
                      }
                      if (row.purchaseCount > 1) {
                        if (subtitle.isNotEmpty) subtitle.write(' · ');
                        subtitle.write('${row.purchaseCount} compras');
                      }
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          title: Text(
                            row.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: subtitle.isEmpty
                              ? null
                              : Text(subtitle.toString()),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(
                            '${AppRoutePaths.search}/p',
                            extra: row,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
