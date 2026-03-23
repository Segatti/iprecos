import 'package:flutter_test/flutter_test.dart';
import 'package:iprecos/data/local/shopping_lists_database.dart';
import 'package:iprecos/data/nfce_receipt_repository.dart';
import 'package:iprecos/data/shopping_lists_repository.dart';
import 'package:iprecos/presenter/view_models/lists_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ListsViewModel', () {
    Future<ListsViewModel> openVm() async {
      final db = await ShoppingListsDatabase.openInMemory();
      final repo = await ShoppingListsRepository.connect(db);
      final nfceRepo = NfceReceiptRepository(db);
      final vm = ListsViewModel(repo, nfceRepo);
      await vm.load();
      addTearDown(vm.dispose);
      addTearDown(repo.dispose);
      return vm;
    }

    Future<void> seedQrItems(
      NfceReceiptRepository nfce,
      List<Map<String, String>> items,
    ) async {
      await nfce.savePayload(
        sourceUrl: 'https://test/nfce',
        emissionRaw: '—',
        payload: {
          'items': [
            for (final m in items)
              {
                'description': m['description']!,
                'quantity': m['quantity'] ?? '1',
                'lineTotal': m['lineTotal'] ?? '1,00',
                if (m['unitPrice'] != null) 'unitPrice': m['unitPrice']!,
              },
          ],
        },
      );
    }

    test('suggestionsForField usa produtos do QR e o rascunho atual', () async {
      final db = await ShoppingListsDatabase.openInMemory();
      final repo = await ShoppingListsRepository.connect(db);
      final nfceRepo = NfceReceiptRepository(db);
      await seedQrItems(nfceRepo, [
        {'description': 'Arroz', 'unitPrice': '5,50'},
        {'description': 'Feijão', 'unitPrice': '8,00'},
      ]);
      final vm = ListsViewModel(repo, nfceRepo);
      await vm.load();
      addTearDown(vm.dispose);
      addTearDown(repo.dispose);

      final s = vm.suggestionsForField('', ['Arroz integral']);

      final labels = s.map((e) => e.label).toList();
      expect(labels, contains('Arroz'));
      expect(labels, contains('Arroz integral'));
      expect(labels, contains('Feijão'));
      final arroz = s.firstWhere((e) => e.label == 'Arroz');
      expect(arroz.unitPriceRaw, '5,50');
      expect(arroz.recordedAtMs, greaterThan(0));
    });

    test('suggestionsForField filtra por texto e ordena', () async {
      final db = await ShoppingListsDatabase.openInMemory();
      final repo = await ShoppingListsRepository.connect(db);
      final nfceRepo = NfceReceiptRepository(db);
      await seedQrItems(nfceRepo, [
        {'description': 'Banana'},
        {'description': 'Melão'},
      ]);
      final vm = ListsViewModel(repo, nfceRepo);
      await vm.load();
      addTearDown(vm.dispose);
      addTearDown(repo.dispose);

      final s = vm.suggestionsForField('ban', []);

      expect(s.map((e) => e.label), equals(['Banana']));
    });

    test('distinctHistoricalItems unifica casing', () async {
      final vm = await openVm();

      await vm.addList(title: '1', items: ['Leite']);
      await vm.addList(title: '2', items: ['leite']);

      expect(vm.distinctHistoricalItems(), ['Leite']);
    });
  });
}
