import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/receipt_parser.dart';
import 'package:food_journal/services/worker_ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _ocr = 'Hannaford\nPRODUCE\nLIMES 0.59\nBALANCE DUE 0.59\nVISA 3319\nAUTH 123';

void main() {
  group('[MFT] buildReceiptAiText', () {
    // testTheory: minimum functionality — the AI request carries only the item
    //   region, optionally preceded by the user's known food names.
    // contract: "Known foods:\n<names>\n\n" + receiptItemRegion(text) when names
    //   are given; the bare region otherwise.
    // implication: decision 9 — payment lines never leave the phone; known names
    //   keep AI names consistent with the journal.

    test('with known foods', () {
      expect(
        buildReceiptAiText(_ocr, const ['limes', 'eggs']),
        'Known foods:\nlimes\neggs\n\nHannaford\nPRODUCE\nLIMES 0.59\nBALANCE DUE 0.59',
      );
    });

    test('without known foods', () {
      expect(buildReceiptAiText(_ocr, const []), 'Hannaford\nPRODUCE\nLIMES 0.59\nBALANCE DUE 0.59');
    });
  });

  group('[MFT] WorkerAiService.parseReceipt', () {
    // testTheory: minimum functionality + boundary — happy path maps every
    //   field; every failure returns success:false and never throws.
    // contract: POST {task:'parse_receipt', text}; 200 -> items with raw, qty,
    //   unit, food, name; non-200 / malformed / blank text -> failure message.
    // implication: AC10 — AI-optional: the review screen must survive any
    //   Worker outcome.

    test('AC10: posts the task and maps items', () async {
      Map<String, dynamic>? sent;
      final client = MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'items': [
              {'raw': 'LIMES', 'qty': 2, 'unit': 'ea', 'food': true, 'name': 'limes'},
              {'raw': 'SWEET POTATOES BULK', 'qty': 2.26, 'unit': 'lb', 'food': true, 'name': 'sweet potatoes'},
              {'raw': 'DVE MEN+CARE', 'qty': 1, 'unit': 'ea', 'food': false, 'name': null},
            ],
          }),
          200,
        );
      });
      final svc = WorkerAiService(workerUrl: 'https://example.workers.dev', client: client);

      final r = await svc.parseReceipt(_ocr, knownFoods: const ['limes']);

      expect(sent!['task'], 'parse_receipt');
      expect(sent!['text'], buildReceiptAiText(_ocr, const ['limes']));
      expect(r.success, isTrue);
      expect(r.items!.map((i) => (i.raw, i.qty, i.unit, i.food, i.name)).toList(), [
        ('LIMES', 2.0, 'ea', true, 'limes'),
        ('SWEET POTATOES BULK', 2.26, 'lb', true, 'sweet potatoes'),
        ('DVE MEN+CARE', 1.0, 'ea', false, null),
      ]);
    });

    test('AC10: unknown unit falls back to ea; missing qty is 1', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'items': [
                {'raw': 'X', 'unit': 'kg', 'food': true, 'name': 'x'},
              ],
            }),
            200,
          ));
      final svc = WorkerAiService(workerUrl: 'https://example.workers.dev', client: client);
      final item = (await svc.parseReceipt(_ocr)).items!.single;
      expect((item.qty, item.unit), (1.0, 'ea'));
    });

    test('AC10: non-200 is a failure with the status', () async {
      final client = MockClient((_) async => http.Response('quota', 429));
      final svc = WorkerAiService(workerUrl: 'https://example.workers.dev', client: client);
      final r = await svc.parseReceipt(_ocr);
      expect(r.success, isFalse);
      expect(r.errorMessage, contains('429'));
    });

    test('AC10: malformed JSON is a failure, not a throw', () async {
      final client = MockClient((_) async => http.Response('{"items": "nope"}', 200));
      final svc = WorkerAiService(workerUrl: 'https://example.workers.dev', client: client);
      final r = await svc.parseReceipt(_ocr);
      expect(r.success, isFalse);
      expect(r.errorMessage, isNotEmpty);
    });

    test('AC10: blank text fails before any request', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      final svc = WorkerAiService(workerUrl: 'https://example.workers.dev', client: client);
      final r = await svc.parseReceipt('   ');
      expect(r.success, isFalse);
      expect(calls, 0);
    });

    test('AC10: empty URL fails before any request', () async {
      final r = await WorkerAiService(workerUrl: '').parseReceipt(_ocr);
      expect(r.success, isFalse);
      expect(r.errorMessage, contains('MEAL_PARSER_URL'));
    });
  });
}
