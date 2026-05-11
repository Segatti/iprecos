import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/product_catalog.dart';
import '../../data/product_photo_storage.dart';
import '../../data/shopping_lists_repository.dart';
import '../view_models/lists_view_model.dart';

class MyListPage extends StatefulWidget {
  const MyListPage({super.key, required this.viewModel});

  final ListsViewModel viewModel;

  @override
  State<MyListPage> createState() => _MyListPageState();
}

class _MyListPageState extends State<MyListPage> {
  /// Modo compras: marcar itens como já comprados (riscados).
  bool _shoppingMode = false;

  /// Índices em [viewModel.items] marcados como comprados nesta sessão.
  final Set<int> _boughtIndices = {};

  void _enterShopping() {
    setState(() {
      _shoppingMode = true;
      _boughtIndices.clear();
    });
  }

  void _cancelShopping() {
    setState(() {
      _shoppingMode = false;
      _boughtIndices.clear();
    });
  }

  Future<void> _saveShopping() async {
    final lines = widget.viewModel.lineItems;
    final remaining = <ShoppingListLineItem>[];
    for (var i = 0; i < lines.length; i++) {
      if (!_boughtIndices.contains(i)) {
        remaining.add(lines[i]);
      }
    }
    await widget.viewModel.replaceAllLineItems(remaining);
    if (!mounted) return;
    setState(() {
      _shoppingMode = false;
      _boughtIndices.clear();
    });
  }

  void _toggleBought(int index) {
    setState(() {
      if (_boughtIndices.contains(index)) {
        _boughtIndices.remove(index);
      } else {
        _boughtIndices.add(index);
      }
    });
  }

  Future<void> _confirmClearList() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar lista'),
        content: const Text(
          'Todos os itens serão removidos. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await widget.viewModel.clearList();
      _cancelShopping();
    }
  }

  Future<void> _openAddDialog() async {
    await widget.viewModel.load();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AddItemsDialog(viewModel: widget.viewModel),
    );
  }

  Future<void> _confirmRemoveItem(int index, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover item'),
        content: Text('Remover "$label" da lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await widget.viewModel.removeLineItemAt(index);
  }

  static String _formatBrl(double v) {
    final s = v.toStringAsFixed(2);
    final i = s.lastIndexOf('.');
    return '${s.substring(0, i)},${s.substring(i + 1)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final lines = widget.viewModel.lineItems;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !_shoppingMode,
            title: Text(_shoppingMode ? 'Às compras' : 'Lista de compras'),
            leading: _shoppingMode
                ? TextButton(
                    onPressed: _cancelShopping,
                    child: const Text('Cancelar'),
                  )
                : null,
            leadingWidth: _shoppingMode ? 100 : null,
            actions: _shoppingMode
                ? [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilledButton(
                        onPressed: _saveShopping,
                        child: const Text('Salvar'),
                      ),
                    ),
                  ]
                : null,
          ),
          body: lines.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nenhum item ainda.\nToque em + para adicionar.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_shoppingMode)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _enterShopping,
                              icon: const Icon(Icons.shopping_cart_outlined),
                              label: const Text('Ir às compras'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _confirmClearList,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Limpar lista'),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: _ListSummaryCard(
                        summary: widget.viewModel.summary,
                        shoppingMode: _shoppingMode,
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 88),
                        itemCount: lines.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final line = lines[index];
                          final bought =
                              _shoppingMode && _boughtIndices.contains(index);
                          final match = widget.viewModel.matchForLabel(
                            line.label,
                          );
                          final sub = _listItemPriceSubtitle(line, match);
                          final isRegistered = match != null;
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 0,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _shoppingMode
                                  ? () => _toggleBought(index)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (_shoppingMode)
                                      Checkbox(
                                        value: bought,
                                        onChanged: (_) => _toggleBought(index),
                                      ),
                                    _ListItemThumb(
                                      relativePath: match?.photoRelativePath,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  line.label,
                                                  style: theme
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.copyWith(
                                                        decoration: bought
                                                            ? TextDecoration
                                                                  .lineThrough
                                                            : null,
                                                        color: bought
                                                            ? theme
                                                                  .colorScheme
                                                                  .onSurfaceVariant
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurface,
                                                      ),
                                                ),
                                              ),
                                              if (!isRegistered)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 6,
                                                      ),
                                                  child: Tooltip(
                                                    message:
                                                        'Item não cadastrado no catálogo',
                                                    child: Icon(
                                                      Icons.help_outline,
                                                      size: 18,
                                                      color: theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (sub != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              sub,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                    decoration: bought
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (!_shoppingMode)
                                      IconButton(
                                        tooltip: 'Remover item',
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                        ),
                                        onPressed: () => _confirmRemoveItem(
                                          index,
                                          line.label,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          floatingActionButton: _shoppingMode
              ? null
              : FloatingActionButton(
                  onPressed: _openAddDialog,
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }

  /// Texto de preço + data do último registro (QR / catálogo), se existir.
  static String? _listItemPriceSubtitle(
    ShoppingListLineItem line, [
    ListProductMatch? match,
  ]) {
    final parts = <String>[];
    final priceRaw = line.lastUnitPrice?.trim().isNotEmpty == true
        ? line.lastUnitPrice!.trim()
        : match?.unitPriceRaw;
    if (priceRaw != null && priceRaw.isNotEmpty) {
      parts.add('Últ. preço unit. R\$ $priceRaw');
    }
    final ms = line.lastPriceRecordedAtMs ?? match?.recordedAtMs;
    if (ms != null && ms > 0) {
      parts.add('Registrado em ${ProductCatalog.formatSavedDate(ms)}');
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}

class _ListItemThumb extends StatelessWidget {
  const _ListItemThumb({required this.relativePath});

  final String? relativePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rel = relativePath?.trim();
    final placeholder = _placeholder(theme);
    if (rel == null || rel.isEmpty) {
      return placeholder;
    }
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<String?>(
          future: ProductPhotoStorage.absolutePathForRelative(rel),
          builder: (context, snap) {
            final path = snap.data;
            final hasFile = path != null && File(path).existsSync();
            return hasFile
                ? Image.file(File(path), fit: BoxFit.cover)
                : ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
          },
        ),
      ),
    );
  }

  static Widget _placeholder(ThemeData theme) {
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ListSummaryCard extends StatelessWidget {
  const _ListSummaryCard({required this.summary, required this.shoppingMode});

  final ShoppingListSummary summary;
  final bool shoppingMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estimated = summary.itemsWithPrice == 0
        ? null
        : 'R\$ ${_MyListPageState._formatBrl(summary.estimatedTotalDecimal)}';
    final unknownPriceCount = summary.totalItems - summary.itemsWithPrice;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shoppingMode ? 'Resumo da lista' : 'Resumo',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            _SummaryRow(
              icon: Icons.list_alt_rounded,
              label: 'Total de itens',
              value: '${summary.totalItems}',
            ),
            const SizedBox(height: 4),
            _SummaryRow(
              icon: Icons.payments_outlined,
              label: 'Previsão de valor',
              value: estimated ?? '—',
              valueStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (unknownPriceCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 24),
                child: Text(
                  '$unknownPriceCount item(s) sem preço conhecido na estimativa.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            // const SizedBox(height: 4),
            // _SummaryRow(
            //   icon: Icons.help_outline,
            //   label: 'Não cadastrados',
            //   value: '${summary.unregisteredItems}',
            //   valueColor: summary.unregisteredItems > 0
            //       ? theme.colorScheme.error
            //       : null,
            // ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueStyle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          value,
          style: (valueStyle ?? theme.textTheme.bodyLarge)?.copyWith(
            color: valueColor,
            fontWeight: valueStyle == null ? FontWeight.w500 : null,
          ),
        ),
      ],
    );
  }
}

class _AddItemsDialog extends StatefulWidget {
  const _AddItemsDialog({required this.viewModel});

  final ListsViewModel viewModel;

  @override
  State<_AddItemsDialog> createState() => _AddItemsDialogState();
}

class _AddItemsDialogState extends State<_AddItemsDialog> {
  final List<ShoppingListLineItem> _draftLines = [];
  final TextEditingController _itemFieldController = TextEditingController();
  final FocusNode _itemFieldFocus = FocusNode();

  @override
  void dispose() {
    _itemFieldController.dispose();
    _itemFieldFocus.dispose();
    super.dispose();
  }

  void _commitRawLine(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    setState(() => _draftLines.add(ShoppingListLineItem(label: t)));
  }

  void _commitSuggestion(QrProductSuggestion s) {
    setState(() {
      _draftLines.add(
        ShoppingListLineItem(
          label: s.label,
          lastUnitPrice: s.unitPriceRaw,
          lastPriceRecordedAtMs: s.recordedAtMs > 0 ? s.recordedAtMs : null,
        ),
      );
    });
  }

  void _removeDraftAt(int index) {
    setState(() => _draftLines.removeAt(index));
  }

  Future<void> _save() async {
    if (_draftLines.isEmpty) return;
    await widget.viewModel.addLineItems(
      List<ShoppingListLineItem>.from(_draftLines),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Adicionar itens'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_draftLines.isNotEmpty) ...[
                Text('Novos itens', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(_draftLines.length, (i) {
                    final line = _draftLines[i];
                    final chipSub = _MyListPageState._listItemPriceSubtitle(
                      line,
                    );
                    return InputChip(
                      label: Text(line.label),
                      tooltip: chipSub,
                      onDeleted: () => _removeDraftAt(i),
                    );
                  }),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Busque pelos produtos das notas escaneadas ou digite um nome.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _ItemSuggestionField(
                viewModel: widget.viewModel,
                draftLabels: _draftLines.map((e) => e.label).toList(),
                controller: _itemFieldController,
                focusNode: _itemFieldFocus,
                onCommitRawLine: (raw) {
                  _commitRawLine(raw);
                  _itemFieldController.clear();
                },
                onCommitSuggestion: (s) {
                  _commitSuggestion(s);
                  _itemFieldController.clear();
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _draftLines.isEmpty ? null : _save,
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

/// Campo + lista de sugestões (evita overlay do [Autocomplete] dentro de [AlertDialog]).
class _ItemSuggestionField extends StatefulWidget {
  const _ItemSuggestionField({
    required this.viewModel,
    required this.draftLabels,
    required this.controller,
    required this.focusNode,
    required this.onCommitRawLine,
    required this.onCommitSuggestion,
  });

  final ListsViewModel viewModel;
  final List<String> draftLabels;
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String raw) onCommitRawLine;
  final void Function(QrProductSuggestion suggestion) onCommitSuggestion;

  @override
  State<_ItemSuggestionField> createState() => _ItemSuggestionFieldState();
}

class _ItemSuggestionFieldState extends State<_ItemSuggestionField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.viewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.viewModel.suggestionsForField(
      widget.controller.text,
      widget.draftLabels,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Ex.: arroz',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: widget.onCommitRawLine,
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Sugestões das notas (QR)',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final s = suggestions[index];
                  final sub = _qrSuggestionSubtitle(s);
                  return ListTile(
                    dense: true,
                    title: Text(s.label),
                    subtitle: sub == null
                        ? null
                        : Text(
                            sub,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                    onTap: () => widget.onCommitSuggestion(s),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String? _qrSuggestionSubtitle(QrProductSuggestion s) {
  final parts = <String>[];
  final p = s.unitPriceRaw?.trim();
  if (p != null && p.isNotEmpty) {
    parts.add('Últ. preço unit. R\$ $p');
  }
  if (s.recordedAtMs > 0) {
    parts.add(
      'Registrado em ${ProductCatalog.formatSavedDate(s.recordedAtMs)}',
    );
  }
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}
