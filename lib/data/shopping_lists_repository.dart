import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'local/shopping_lists_database.dart';

/// Linha da lista de compras (rótulo + opcionalmente último preço visto no QR).
@immutable
class ShoppingListLineItem {
  const ShoppingListLineItem({
    required this.label,
    this.lastUnitPrice,
    this.lastPriceRecordedAtMs,
  });

  final String label;
  final String? lastUnitPrice;
  final int? lastPriceRecordedAtMs;

  static ShoppingListLineItem fromMap(Map<String, Object?> r) {
    return ShoppingListLineItem(
      label: r['label']! as String,
      lastUnitPrice: r['last_unit_price'] as String?,
      lastPriceRecordedAtMs: r['last_price_recorded_at_ms'] as int?,
    );
  }
}

/// Uma lista de compras persistida no SQLite.
@immutable
class ShoppingListEntry {
  const ShoppingListEntry({
    required this.id,
    required this.title,
    required this.items,
    required this.createdAt,
  });

  final String id;
  final String title;
  final List<String> items;
  final DateTime createdAt;
}

/// Camada de dados: apenas SQLite (sem estado de UI).
class ShoppingListsRepository {
  ShoppingListsRepository._(this._db);

  static const _singletonListId = '__main_shopping_list__';

  final Database _db;

  /// Compartilhado com [NfceReceiptRepository] (mesmo arquivo SQLite).
  Database get database => _db;

  static Future<ShoppingListsRepository> open() async {
    final db = await ShoppingListsDatabase.openDefault();
    return ShoppingListsRepository._(db);
  }

  /// Para testes: [db] já aberto (ex.: memória + FFI).
  @visibleForTesting
  static Future<ShoppingListsRepository> connect(Database db) async {
    return ShoppingListsRepository._(db);
  }

  /// Garante a lista única e migra listas antigas (várias linhas em `shopping_lists`) para ela.
  Future<void> ensureSingletonList() async {
    final main = await _db.query(
      'shopping_lists',
      where: 'id = ?',
      whereArgs: [_singletonListId],
      limit: 1,
    );
    if (main.isNotEmpty) return;

    final oldLists = await _loadLegacyListsUnordered();
    await _db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (oldLists.isEmpty) {
        await txn.insert('shopping_lists', {
          'id': _singletonListId,
          'title': 'Minha lista',
          'created_at_ms': now,
        });
        return;
      }

      final merged = <String>[];
      for (final l in oldLists.reversed) {
        merged.addAll(l.items);
      }
      await txn.insert('shopping_lists', {
        'id': _singletonListId,
        'title': 'Minha lista',
        'created_at_ms': now,
      });
      for (var i = 0; i < merged.length; i++) {
        await txn.insert('shopping_list_items', {
          'list_id': _singletonListId,
          'sort_order': i,
          'label': merged[i],
        });
      }
      for (final l in oldLists) {
        await txn.delete('shopping_lists', where: 'id = ?', whereArgs: [l.id]);
      }
    });
  }

  Future<List<ShoppingListEntry>> _loadLegacyListsUnordered() async {
    final listRows = await _db.query(
      'shopping_lists',
      orderBy: 'created_at_ms DESC',
    );
    final result = <ShoppingListEntry>[];
    for (final row in listRows) {
      final id = row['id']! as String;
      if (id == _singletonListId) continue;
      final itemRows = await _db.query(
        'shopping_list_items',
        columns: ['label'],
        where: 'list_id = ?',
        whereArgs: [id],
        orderBy: 'sort_order ASC',
      );
      final items = itemRows.map((r) => r['label']! as String).toList();
      result.add(
        ShoppingListEntry(
          id: id,
          title: row['title']! as String,
          items: items,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at_ms']! as int,
          ),
        ),
      );
    }
    return result;
  }

  /// Compatível com código legado: devolve só a lista principal (uma entrada).
  Future<List<ShoppingListEntry>> loadLists() async {
    await ensureSingletonList();
    final row = await _db.query(
      'shopping_lists',
      where: 'id = ?',
      whereArgs: [_singletonListId],
      limit: 1,
    );
    if (row.isEmpty) return [];
    final id = row.single['id']! as String;
    final itemRows = await _db.query(
      'shopping_list_items',
      columns: ['label'],
      where: 'list_id = ?',
      whereArgs: [id],
      orderBy: 'sort_order ASC',
    );
    final items = itemRows.map((r) => r['label']! as String).toList();
    return [
      ShoppingListEntry(
        id: id,
        title: row.single['title']! as String,
        items: items,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.single['created_at_ms']! as int,
        ),
      ),
    ];
  }

  Future<List<ShoppingListLineItem>> loadMainListLineItems() async {
    await ensureSingletonList();
    final itemRows = await _db.query(
      'shopping_list_items',
      columns: ['label', 'last_unit_price', 'last_price_recorded_at_ms'],
      where: 'list_id = ?',
      whereArgs: [_singletonListId],
      orderBy: 'sort_order ASC',
    );
    return itemRows.map(ShoppingListLineItem.fromMap).toList();
  }

  Future<void> replaceMainListLineItems(List<ShoppingListLineItem> items) async {
    await ensureSingletonList();
    final trimmed = items
        .map(
          (e) => ShoppingListLineItem(
            label: e.label.trim(),
            lastUnitPrice: e.lastUnitPrice?.trim().isNotEmpty == true
                ? e.lastUnitPrice!.trim()
                : null,
            lastPriceRecordedAtMs: e.lastPriceRecordedAtMs,
          ),
        )
        .where((e) => e.label.isNotEmpty)
        .toList();
    await _db.transaction((txn) async {
      await txn.delete(
        'shopping_list_items',
        where: 'list_id = ?',
        whereArgs: [_singletonListId],
      );
      for (var i = 0; i < trimmed.length; i++) {
        final e = trimmed[i];
        await txn.insert('shopping_list_items', {
          'list_id': _singletonListId,
          'sort_order': i,
          'label': e.label,
          'last_unit_price': e.lastUnitPrice,
          'last_price_recorded_at_ms': e.lastPriceRecordedAtMs,
        });
      }
    });
  }

  Future<void> appendMainListLineItems(List<ShoppingListLineItem> items) async {
    final trimmed = items
        .map(
          (e) => ShoppingListLineItem(
            label: e.label.trim(),
            lastUnitPrice: e.lastUnitPrice?.trim().isNotEmpty == true
                ? e.lastUnitPrice!.trim()
                : null,
            lastPriceRecordedAtMs: e.lastPriceRecordedAtMs,
          ),
        )
        .where((e) => e.label.isNotEmpty)
        .toList();
    if (trimmed.isEmpty) return;
    await ensureSingletonList();
    final existing = await loadMainListLineItems();
    await replaceMainListLineItems([...existing, ...trimmed]);
  }

  Future<void> clearMainList() async {
    await ensureSingletonList();
    await _db.delete(
      'shopping_list_items',
      where: 'list_id = ?',
      whereArgs: [_singletonListId],
    );
  }

  /// Anexa itens só com rótulo (o parâmetro [title] é ignorado).
  Future<void> addList({required String title, required List<String> items}) async {
    await appendMainListLineItems([
      for (final s in items)
        if (s.trim().isNotEmpty) ShoppingListLineItem(label: s.trim()),
    ]);
  }

  void dispose() {
    unawaited(_db.close());
  }
}
