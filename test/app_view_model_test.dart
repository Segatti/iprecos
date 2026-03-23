import 'package:flutter_test/flutter_test.dart';
import 'package:iprecos/presenter/view_models/app_view_model.dart';

void main() {
  group('AppViewModel', () {
    test('inicia deslogado com nome vazio', () {
      final vm = AppViewModel();
      addTearDown(vm.dispose);

      expect(vm.session.authenticated, isFalse);
      expect(vm.session.userName, '');
    });

    test('signOut mantém deslogado sem chamar plugin quando já visitante', () async {
      final vm = AppViewModel();
      addTearDown(vm.dispose);

      await vm.signOut();

      expect(vm.session.authenticated, isFalse);
      expect(vm.session.userName, '');
    });

    test('signOut notifica ouvintes', () async {
      final vm = AppViewModel();
      addTearDown(vm.dispose);

      var calls = 0;
      vm.addListener(() => calls++);

      await vm.signOut();

      expect(calls, 1);
    });
  });
}
