import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iprecos/data/nfce_mt_html_parser.dart';
import 'package:iprecos/data/sefaz_mt_url.dart';

void main() {
  group('SefazMtUrl', () {
    test('aceita www.sefaz.mt.gov.br em https', () {
      final u = Uri.parse(
        'https://www.sefaz.mt.gov.br/nfce/consultanfce?tipoConsulta=qr&p=xxx',
      );
      expect(SefazMtUrl.isAllowedNfceConsulta(u), isTrue);
    });

    test('aceita sefaz.mt.gov.br sem www', () {
      final u = Uri.parse('https://sefaz.mt.gov.br/nfce/consultanfce');
      expect(SefazMtUrl.isAllowedNfceConsulta(u), isTrue);
    });

    test('aceita http e outro estado (UF)', () {
      final u = Uri.parse('http://www.sefaz.sp.gov.br/nfce/consultanfce');
      expect(SefazMtUrl.isAllowedNfceConsulta(u), isTrue);
    });

    test('aceita sefaz.pr.gov.br em https', () {
      final u = Uri.parse('https://sefaz.pr.gov.br/nfce');
      expect(SefazMtUrl.isAllowedNfceConsulta(u), isTrue);
    });

    test('rejeita host que não é sefaz.UF.gov.br', () {
      final u = Uri.parse('https://evil.com/www.sefaz.mt.gov.br');
      expect(SefazMtUrl.isAllowedNfceConsulta(u), isFalse);
    });

    test('rejeita subdomínio extra', () {
      final u = Uri.parse('https://nfc.sefaz.mt.gov.br/nfce');
      expect(SefazMtUrl.isAllowedNfceConsulta(u), isFalse);
    });

    test('tryParseScanned adiciona https em www', () {
      final u = SefazMtUrl.tryParseScanned(
        'www.sefaz.mt.gov.br/nfce/consultanfce',
      );
      expect(u, isNotNull);
      expect(u!.scheme, 'https');
      expect(SefazMtUrl.isAllowedNfceConsulta(u), isTrue);
    });

    test('tryParseScanned adiciona https em sefaz.UF.gov.br sem esquema', () {
      final u = SefazMtUrl.tryParseScanned(
        'sefaz.rj.gov.br/nfce/consultanfce',
      );
      expect(u, isNotNull);
      expect(u!.scheme, 'https');
      expect(SefazMtUrl.isAllowedNfceConsulta(u), isTrue);
    });
  });

  group('NfceMtHtmlParser', () {
    test('extrai itens e data de example_qr.html', () {
      final file = File('example_qr.html');
      if (!file.existsSync()) {
        fail('Coloque example_qr.html na raiz do pacote para este teste.');
      }
      final html = file.readAsStringSync();
      final r = NfceMtHtmlParser.parse(html);
      expect(r, isNotNull);
      expect(r!.items.length, 70);
      expect(r.emissionRaw, '22/03/2026 12:47:22');
      expect(r.items.first.description, 'OVO BCO PQ');
      expect(r.items.first.lineTotal, '20,90');
      expect(r.purchaseTotalRaw, '849,13');
      expect(r.taxesTotalRaw, '213,58');
    });
  });
}
