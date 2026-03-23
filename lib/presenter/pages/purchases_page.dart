import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_route_paths.dart';
import '../view_models/purchases_view_model.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key, required this.viewModel});

  final PurchasesViewModel viewModel;

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.viewModel.load();
    });
  }

  String _shortUrl(String url) {
    try {
      final u = Uri.parse(url);
      final q = u.query.isEmpty ? '' : '?…';
      return '${u.host}${u.path}$q';
    } catch (_) {
      return url.length > 48 ? '${url.substring(0, 45)}…' : url;
    }
  }

  String _formatSaved(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas compras')),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final vm = widget.viewModel;
          if (vm.loading && vm.receipts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.receipts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nenhuma nota escaneada ainda.\nUse “Escanear nota” na home.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: vm.load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: vm.receipts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = vm.receipts[index];
                final theme = Theme.of(context);
                final emission = r.emissionRaw == '—'
                    ? 'Não informada na nota'
                    : r.emissionRaw;
                final total = r.purchaseTotalRaw?.trim();
                final totalLabel = total != null && total.isNotEmpty
                    ? 'R\$ $total'
                    : '—';
                return ListTile(
                  title: Text(
                    'Total da compra: $totalLabel',
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '${r.itemCount} ${r.itemCount == 1 ? 'item' : 'itens'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Data da compra (emissão): $emission',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Salvo no app: ${_formatSaved(r.createdAtMs)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _shortUrl(r.sourceUrl),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(
                    '${AppRoutePaths.purchases}/${Uri.encodeComponent(r.id)}',
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
