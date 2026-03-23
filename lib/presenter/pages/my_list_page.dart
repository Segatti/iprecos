import 'package:flutter/material.dart';

import '../../data/product_catalog.dart';
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
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        itemCount: lines.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final line = lines[index];
                          final bought =
                              _shoppingMode && _boughtIndices.contains(index);
                          final sub = _listItemPriceSubtitle(line);
                          return InkWell(
                            onTap: _shoppingMode
                                ? () => _toggleBought(index)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_shoppingMode) ...[
                                    Checkbox(
                                      value: bought,
                                      onChanged: (_) => _toggleBought(index),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          line.label,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                decoration: bought
                                                    ? TextDecoration
                                                        .lineThrough
                                                    : null,
                                                color: bought
                                                    ? theme.colorScheme
                                                        .onSurfaceVariant
                                                    : theme
                                                        .colorScheme.onSurface,
                                              ),
                                        ),
                                        if (sub != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            sub,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme.colorScheme
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
                                ],
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

  /// Texto de preço + data do último registro (QR), se existir.
  static String? _listItemPriceSubtitle(ShoppingListLineItem line) {
    final parts = <String>[];
    final p = line.lastUnitPrice?.trim();
    if (p != null && p.isNotEmpty) {
      parts.add('Últ. preço unit. R\$ $p');
    }
    final ms = line.lastPriceRecordedAtMs;
    if (ms != null) {
      parts.add('Registrado em ${ProductCatalog.formatSavedDate(ms)}');
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
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
          lastPriceRecordedAtMs:
              s.recordedAtMs > 0 ? s.recordedAtMs : null,
        ),
      );
    });
  }

  void _removeDraftAt(int index) {
    setState(() => _draftLines.removeAt(index));
  }

  Future<void> _save() async {
    if (_draftLines.isEmpty) return;
    await widget.viewModel.addLineItems(List<ShoppingListLineItem>.from(_draftLines));
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
                  final chipSub = _MyListPageState._listItemPriceSubtitle(line);
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
    parts.add('Registrado em ${ProductCatalog.formatSavedDate(s.recordedAtMs)}');
  }
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}
