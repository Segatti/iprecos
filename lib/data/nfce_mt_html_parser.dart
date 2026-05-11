import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Linha de produto extraída da consulta NFC-e SEFAZ-MT.
class NfceLineItem {
  const NfceLineItem({
    required this.description,
    this.code,
    required this.quantityText,
    this.unit,
    this.unitPrice,
    required this.lineTotal,
  });

  final String description;
  final String? code;
  final String quantityText;
  final String? unit;
  final String? unitPrice;
  final String lineTotal;

  Map<String, dynamic> toJson() => {
        'description': description,
        if (code != null) 'code': code,
        'quantity': quantityText,
        if (unit != null) 'unit': unit,
        if (unitPrice != null) 'unitPrice': unitPrice,
        'lineTotal': lineTotal,
      };
}

/// Resultado do parse do HTML da página de consulta NFC-e (MT).
class NfceParseResult {
  const NfceParseResult({
    required this.emissionRaw,
    required this.items,
    this.purchaseTotalRaw,
    this.taxesTotalRaw,
    this.emitterName,
    this.emitterCnpj,
    this.emitterAddressLine,
  });

  final String emissionRaw;
  final List<NfceLineItem> items;

  /// Valor de "Valor total R$:" em `#totalNota`, ou "Valor a pagar R$:" se a
  /// primeira linha não existir (layout mobile / nota simplificada).
  final String? purchaseTotalRaw;

  /// Valor da linha de tributos (Lei 12.741/2012) em `#totalNota`.
  final String? taxesTotalRaw;

  /// Razão social / nome fantasia no topo da nota (`div.txtTopo`), quando houver.
  final String? emitterName;

  /// Linha "CNPJ: …" no bloco do emitente.
  final String? emitterCnpj;

  /// Endereço do emitente (linhas em `div.text` após o CNPJ).
  final String? emitterAddressLine;

  Map<String, dynamic> toJson(String sourceUrl) => {
        'sourceUrl': sourceUrl,
        'emissionAt': emissionRaw,
        'items': items.map((e) => e.toJson()).toList(),
        if (purchaseTotalRaw != null) 'purchaseTotal': purchaseTotalRaw,
        if (taxesTotalRaw != null) 'taxesTotal': taxesTotalRaw,
        if (emitterName != null && emitterName!.trim().isNotEmpty)
          'emitterName': emitterName!.trim(),
        if (emitterCnpj != null && emitterCnpj!.trim().isNotEmpty)
          'emitterCnpj': emitterCnpj!.trim(),
        if (emitterAddressLine != null &&
            emitterAddressLine!.trim().isNotEmpty)
          'emitterAddress': emitterAddressLine!.trim(),
      };
}

/// Parser do HTML no formato de [example_qr.html] (tabela `#tabResult`).
abstract final class NfceMtHtmlParser {
  static final _emissionRe = RegExp(
    r'Emiss(?:ão|&atilde;o|&Atilde;o):\s*</strong>\s*(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})',
    caseSensitive: false,
  );

  static final _codeRe = RegExp(
    r'C[oó]digo:\s*([^)]+)',
    caseSensitive: false,
  );

  static final _qtyRe = RegExp(r'Qtde\.:\s*([\d,\.]+)');
  static final _unitRe = RegExp(r'UN:\s*(\S+)');
  static final _vlUnitRe = RegExp(
    r'Vl\.\s*Unit\.:\s*([\d,\.\s]+)',
    caseSensitive: false,
  );

  /// Retorna `null` se não houver tabela de itens reconhecível.
  static NfceParseResult? parse(String html) {
    final doc = html_parser.parse(html);
    final table = doc.querySelector('table#tabResult');
    if (table == null) return null;

    final items = <NfceLineItem>[];
    for (final row in table.querySelectorAll('tr')) {
      final id = row.attributes['id'] ?? '';
      if (!id.contains('Item')) continue;

      final tit = row.querySelector('span.txtTit');
      if (tit == null) continue;
      final description = tit.text.trim();
      if (description.isEmpty) continue;

      String? code;
      final rc = row.querySelector('span.RCod')?.text ?? '';
      final cm = _codeRe.firstMatch(rc);
      if (cm != null) {
        code = cm.group(1)?.trim();
      }

      final rq = row.querySelector('span.Rqtd')?.text ?? '';
      final qm = _qtyRe.firstMatch(rq);
      final quantityText = qm?.group(1)?.trim() ?? '';

      String? unit;
      final run = row.querySelector('span.RUN')?.text ?? '';
      final um = _unitRe.firstMatch(run);
      if (um != null) unit = um.group(1)?.trim();

      String? unitPrice;
      final rv = row.querySelector('span.RvlUnit')?.text ?? '';
      final rvClean = rv.replaceAll('\u00a0', ' ');
      final vm = _vlUnitRe.firstMatch(rvClean);
      if (vm != null) {
        unitPrice = vm.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
      }

      final total =
          row.querySelector('span.valor')?.text.trim() ?? '';

      items.add(
        NfceLineItem(
          description: description,
          code: code,
          quantityText: quantityText,
          unit: unit,
          unitPrice: unitPrice,
          lineTotal: total,
        ),
      );
    }

    if (items.isEmpty) return null;

    final rawHtml = doc.outerHtml;
    final em = _emissionRe.firstMatch(rawHtml);
    final emissionRaw = em?.group(1)?.trim() ?? '';

    final totals = _parseTotalNota(doc);
    final emit = _parseEmitter(doc);

    return NfceParseResult(
      emissionRaw: emissionRaw,
      items: items,
      purchaseTotalRaw: totals.$1,
      taxesTotalRaw: totals.$2,
      emitterName: emit.$1,
      emitterCnpj: emit.$2,
      emitterAddressLine: emit.$3,
    );
  }

  /// Bloco `div.txtCenter`: nome (`txtTopo`), CNPJ e endereço em `div.text`.
  static (String?, String?, String?) _parseEmitter(Document doc) {
    final txtCenter =
        doc.querySelector('div#conteudo div.txtCenter') ??
            doc.querySelector('div.txtCenter');
    if (txtCenter == null) return (null, null, null);

    final topo = txtCenter.querySelector('div#u20.txtTopo') ??
        txtCenter.querySelector('div.txtTopo');
    final name = topo?.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final nameNorm = name != null && name.isNotEmpty ? name : null;

    String? cnpj;
    final addressLines = <String>[];
    for (final el in txtCenter.querySelectorAll('div.text')) {
      final s = el.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (s.isEmpty) continue;
      if (s.toUpperCase().startsWith('CNPJ:')) {
        cnpj = s;
      } else {
        addressLines.add(s);
      }
    }
    final joined = addressLines.join(' · ').trim();
    return (nameNorm, cnpj, joined.isEmpty ? null : joined);
  }

  /// Lê `#totalNota`: valor total da nota e tributos (Lei Federal 12.741/2012).
  ///
  /// Várias versões da página omitem "Valor total R$:" e exibem só
  /// "Valor a pagar R$:" (ex.: [example_qr2.html], [example_qr3.html]).
  /// Nesse caso usamos o valor a pagar como total salvo.
  static (String?, String?) _parseTotalNota(Document doc) {
    final block = doc.querySelector('#totalNota');
    if (block == null) return (null, null);

    String? valorTotalProdutos;
    String? valorAPagar;
    String? taxesTotal;

    for (final line in block.children) {
      if (line.localName != 'div') continue;
      final labelEl = line.querySelector('label');
      final labelText = labelEl?.text
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim() ??
          '';
      final value =
          line.querySelector('span.totalNumb')?.text.trim() ?? '';
      if (value.isEmpty || value == 'NaN') continue;

      // "Valor total R$:" (com desconto em linhas separadas) vs só "Valor a pagar R$:"
      if (labelText.contains('Valor total') && labelText.contains(r'$')) {
        valorTotalProdutos = value;
      } else if (labelText.contains('Valor a pagar')) {
        valorAPagar = value;
      }
      if (labelText.contains('Tributos Totais')) {
        taxesTotal = value;
      }
    }

    final purchaseTotal = valorTotalProdutos ?? valorAPagar;
    return (purchaseTotal, taxesTotal);
  }
}
