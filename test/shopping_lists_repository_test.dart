import 'package:flutter_test/flutter_test.dart';
import 'package:iprecos/data/local/shopping_lists_database.dart';
import 'package:iprecos/data/shopping_lists_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ShoppingListsRepository', () {
    Future<ShoppingListsRepository> openRepo() async {
      final db = await ShoppingListsDatabase.openInMemory();
      return ShoppingListsRepository.connect(db);
    }

    test('addList ignora itens só com espaços', () async {
      final repo = await openRepo();
      addTearDown(repo.dispose);

      await repo.addList(title: 'X', items: ['  ', '']);

      expect(await repo.loadMainListLineItems(), isEmpty);
    });

    test('addList guarda lista com itens trimados', () async {
      final repo = await openRepo();
      addTearDown(repo.dispose);

      await repo.addList(title: 'Almoço', items: ['  Arroz ', 'Feijão']);

      final lines = await repo.loadMainListLineItems();
      expect(lines.map((e) => e.label), ['Arroz', 'Feijão']);
    });

    test('persiste preço e data ao anexar linhas', () async {
      final repo = await openRepo();
      addTearDown(repo.dispose);

      await repo.appendMainListLineItems([
        const ShoppingListLineItem(
          label: 'Café',
          lastUnitPrice: '12,90',
          lastPriceRecordedAtMs: 1700000000000,
        ),
      ]);

      final lines = await repo.loadMainListLineItems();
      expect(lines.single.label, 'Café');
      expect(lines.single.lastUnitPrice, '12,90');
      expect(lines.single.lastPriceRecordedAtMs, 1700000000000);
    });
  });
}
