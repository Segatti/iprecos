import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Abertura do SQLite (listas de compras + NFC-e SEFAZ-MT).
abstract final class ShoppingListsDatabase {
  static const version = 6;

  static Future<Database> openDefault() async {
    final dir = await getDatabasesPath();
    final filePath = p.join(dir, 'shopping_lists.db');
    return openDatabase(
      filePath,
      version: version,
      onConfigure: _onConfigure,
      onCreate: (db, _) => createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createNfceReceiptsTable(db);
        }
        if (oldVersion < 3) {
          await db.execute('''
ALTER TABLE shopping_list_items ADD COLUMN last_unit_price TEXT;
''');
          await db.execute('''
ALTER TABLE shopping_list_items ADD COLUMN last_price_recorded_at_ms INTEGER;
''');
        }
        if (oldVersion < 4) {
          await _createManualProductsTable(db);
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE manual_products ADD COLUMN measure_qty TEXT',
          );
          await db.execute(
            'ALTER TABLE manual_products ADD COLUMN measure_unit_code TEXT',
          );
          await db.execute(
            'ALTER TABLE manual_products ADD COLUMN photo_relative_path TEXT',
          );
        }
        if (oldVersion < 6) {
          await _createNfceReceiptItemOverridesTable(db);
        }
      },
    );
  }

  /// Banco em memória (testes com `sqflite_common_ffi`).
  ///
  /// [singleInstance: false] evita reutilizar a mesma conexão `:memory:` entre aberturas.
  static Future<Database> openInMemory() async {
    return openDatabase(
      inMemoryDatabasePath,
      version: version,
      singleInstance: false,
      onConfigure: _onConfigure,
      onCreate: (db, _) => createSchema(db),
    );
  }

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> createSchema(Database db) async {
    await _createShoppingListsTables(db);
    await _createNfceReceiptsTable(db);
    await _createManualProductsTable(db);
    await _createNfceReceiptItemOverridesTable(db);
  }

  static Future<void> _createShoppingListsTables(Database db) async {
    await db.execute('''
CREATE TABLE shopping_lists (
  id TEXT NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');
    await db.execute('''
CREATE TABLE shopping_list_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  list_id TEXT NOT NULL,
  sort_order INTEGER NOT NULL,
  label TEXT NOT NULL,
  last_unit_price TEXT,
  last_price_recorded_at_ms INTEGER,
  FOREIGN KEY (list_id) REFERENCES shopping_lists (id) ON DELETE CASCADE
);
''');
  }

  static Future<void> _createNfceReceiptsTable(Database db) async {
    await db.execute('''
CREATE TABLE nfce_receipts (
  id TEXT NOT NULL PRIMARY KEY,
  source_url TEXT NOT NULL,
  emission_raw TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');
  }

  static Future<void> _createManualProductsTable(Database db) async {
    await db.execute('''
CREATE TABLE manual_products (
  id TEXT NOT NULL PRIMARY KEY,
  barcode TEXT,
  store_code TEXT,
  name TEXT NOT NULL,
  brand TEXT,
  unit_price TEXT,
  measure_label TEXT,
  measure_qty TEXT,
  measure_unit_code TEXT,
  photo_relative_path TEXT,
  created_at_ms INTEGER NOT NULL
);
''');
  }

  static Future<void> _createNfceReceiptItemOverridesTable(Database db) async {
    await db.execute('''
CREATE TABLE nfce_receipt_item_overrides (
  receipt_id TEXT NOT NULL,
  item_index INTEGER NOT NULL,
  photo_relative_path TEXT,
  user_barcode TEXT,
  user_brand TEXT,
  PRIMARY KEY (receipt_id, item_index),
  FOREIGN KEY (receipt_id) REFERENCES nfce_receipts (id) ON DELETE CASCADE
);
''');
  }
}
