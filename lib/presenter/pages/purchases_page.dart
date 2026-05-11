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
      widget.viewModel.resetFilterToNow();
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

  static String _monthLabel(int m) {
    const names = [
      '', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
    ];
    return names[m];
  }

  static String _formatBrlSimple(double v) {
    final s = v.toStringAsFixed(2);
    final i = s.lastIndexOf('.');
    return '${s.substring(0, i)},${s.substring(i + 1)}';
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

          final years = <int>{};
          for (final r in vm.receipts) {
            years.add(
              DateTime.fromMillisecondsSinceEpoch(r.createdAtMs).year,
            );
          }
          years.add(vm.filterYear);
          final yearList = years.toList()..sort();

          final filtered = vm.filteredReceipts;
          final sum = vm.monthSummary;

          return RefreshIndicator(
            onRefresh: vm.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Text(
                  'Período',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('m_${vm.filterYear}_${vm.filterMonth}'),
                        initialValue: vm.filterMonth,
                        decoration: const InputDecoration(
                          labelText: 'Mês',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (var m = 1; m <= 12; m++)
                            DropdownMenuItem(
                              value: m,
                              child: Text('${_monthLabel(m)} ($m)'),
                            ),
                        ],
                        onChanged: (m) {
                          if (m != null) {
                            vm.setFilterMonthYear(vm.filterYear, m);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('y_${vm.filterYear}_${vm.filterMonth}'),
                        initialValue: yearList.contains(vm.filterYear)
                            ? vm.filterYear
                            : yearList.last,
                        decoration: const InputDecoration(
                          labelText: 'Ano',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final y in yearList)
                            DropdownMenuItem(
                              value: y,
                              child: Text('$y'),
                            ),
                        ],
                        onChanged: (y) {
                          if (y != null) {
                            vm.setFilterMonthYear(y, vm.filterMonth);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumo (${_monthLabel(vm.filterMonth)}/${vm.filterYear})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Compras: ${sum.receiptCount}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          'Itens comprados: ${sum.totalItems}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sum.receiptsWithTotal > 0
                              ? 'Valor total (notas com total): R\$ ${_formatBrlSimple(sum.sumPurchaseDecimal)}'
                              : 'Valor total: — (nenhuma nota com total neste período)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (sum.receiptCount > 0 &&
                            sum.receiptsWithTotal < sum.receiptCount)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${sum.receiptCount - sum.receiptsWithTotal} nota(s) sem valor total reconhecido.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Notas (${filtered.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Nenhuma compra salva neste mês.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  )
                else
                  ...filtered.map((r) {
                    final theme = Theme.of(context);
                    final emission = r.emissionRaw == '—'
                        ? 'Não informada na nota'
                        : r.emissionRaw;
                    final total = r.purchaseTotalRaw?.trim();
                    final totalLabel = total != null && total.isNotEmpty
                        ? 'R\$ $total'
                        : '—';
                    final store = r.storeName?.trim();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          'Total da compra: $totalLabel',
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (store != null && store.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Mercado: $store',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
