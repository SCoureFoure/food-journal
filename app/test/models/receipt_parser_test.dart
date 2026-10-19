import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/receipt_parser.dart';

const _hannaford = '''Hannaford
Hannaford Supermarket & Pharmacy
7 Kilton Road, Bedford, NH 03110
DELI
CDR ORIGINAL HMS 4.49 米
GROCERY
GM HNY NUT CHEERIOS 46617
HRD STM IB WGB EX FN W
2@ 1.39 2.78
ICE SKYR CHRY & CRNT
1@5 FOR 5.00 1.00 米
THOM ORIG ENG MFFN 6 3.99 *
HEALTH & BEAUTY
DVE MEN+CARE CDRWD/T 10.49
PRODUCE
SWEET POTATOES BULK W
2.26 1b @ 1.49/1b 3.37 *
SHALLOTS W
C 04 1b @ 3.99/16 0.16 *
WAGO OCN SP SMPLR 15.99 B *
23 BALANCE DUE 68.11
RRN: 060535
VISA Entry Method:Cntctless''';

List<(String, double, String, bool?)> _simple(List<ParsedReceiptItem> items) =>
    [for (final i in items) (i.raw, i.qty, i.unit, i.food)];

void main() {
  group('[MFT] parseReceiptText — Hannaford layout', () {
    // testTheory: minimum functionality — the bake-off fixture must parse to the
    //   exact item list the Python reference produced.
    // contract: section headers start the region and set food; quantity lines
    //   update the previous item; prices and B/W flags are stripped.
    // implication: AC1 — this is the store the parser was tuned on; a miss here
    //   means the port drifted from the measured reference.

    test('AC1: items, quantities, units and food flags', () {
      expect(_simple(parseReceiptText(_hannaford)), [
        ('CDR ORIGINAL HMS', 1.0, 'ea', true),
        ('GM HNY NUT CHEERIOS 46617', 1.0, 'ea', true),
        ('HRD STM IB WGB EX FN', 2.0, 'ea', true),
        ('ICE SKYR CHRY & CRNT', 1.0, 'ea', true),
        ('THOM ORIG ENG MFFN 6', 1.0, 'ea', true),
        ('DVE MEN+CARE CDRWD/T', 1.0, 'ea', false),
        ('SWEET POTATOES BULK', 2.26, 'lb', true),
        ('SHALLOTS', 1.0, 'ea', true),
        ('WAGO OCN SP SMPLR', 1.0, 'ea', true),
      ]);
    });

    test('AC1: parser never invents a generic name', () {
      expect(parseReceiptText(_hannaford).every((i) => i.name == null), isTrue);
    });

    test('AC1: lines with fewer than 3 letters are skipped', () {
      const text = 'PRODUCE\nW\n0.59\nLIMES W 0.59 *\nBALANCE DUE 0.59';
      expect(_simple(parseReceiptText(text)), [('LIMES', 1.0, 'ea', true)]);
    });

    test('AC1: nothing before the first section header is an item', () {
      // Header-less text falls through to the price rule (AC4), so the preamble
      // line carries a price here to prove the header pass ignores it.
      const text = 'Hannaford\nKilton Road 4.99\nGROCERY\nLIMES 0.59\nBALANCE DUE 5.58';
      expect(_simple(parseReceiptText(text)), [('LIMES', 1.0, 'ea', true)]);
    });
  });

  group('[BVA] parseReceiptText — region end markers', () {
    // testTheory: boundary — the first end marker closes the item region.
    // contract: BALANCE DUE, TAX PAID, a line starting "TAX ", and
    //   "(SUB)TOTAL <price>" end the region; an item that merely starts with
    //   TOTAL does not.
    // implication: AC2/AC5 — payment and tax lines must never become pantry items.

    test('AC2: TAX PAID ends the region', () {
      const text = 'GROCERY\nLIMES 0.59\nTax Paid\n8.50% Tax 2 5.99 0.51\nFAKE ITEM LINE 1.00';
      expect(_simple(parseReceiptText(text)), [('LIMES', 1.0, 'ea', true)]);
    });

    test('AC5: TOTAL <price> ends the region', () {
      const text = 'GROCERY\nLIMES 0.59\nTOTAL \$12.34\nVISA CARD ITEM 1.00';
      expect(_simple(parseReceiptText(text)), [('LIMES', 1.0, 'ea', true)]);
    });

    test('AC5: SUBTOTAL <price> ends the region', () {
      const text = 'GROCERY\nLIMES 0.59\nSUBTOTAL 12.34\nVISA CARD ITEM 1.00';
      expect(_simple(parseReceiptText(text)), [('LIMES', 1.0, 'ea', true)]);
    });

    test('AC5: an item starting with TOTAL is still an item', () {
      const text = 'GROCERY\nTOTAL CEREAL 4.99\nBALANCE DUE 4.99';
      expect(_simple(parseReceiptText(text)), [('TOTAL CEREAL', 1.0, 'ea', true)]);
    });
  });

  group('[INV] parseReceiptText — fuzzy headers and header-less stores', () {
    // testTheory: invariant — OCR misreads of a header are still headers; a
    //   receipt with no headers still yields items with unknown food status.
    // contract: header if sequenceRatio >= 0.80 against a known section;
    //   no header anywhere -> region starts at the first line ending in a price,
    //   food is null.
    // implication: AC3/AC4 — other stores and bad photos must not yield zero items.

    test('AC3: misread headers still switch section', () {
      const text = 'GENERA MDSE\n8I STNLS STEEL SCISR 5.75\nGROCER\nLIMES 0.59\nBALANCE DUE 6.34';
      expect(_simple(parseReceiptText(text)), [
        ('8I STNLS STEEL SCISR', 1.0, 'ea', false),
        ('LIMES', 1.0, 'ea', true),
      ]);
    });

    test('AC4: no headers -> start at first priced line, food unknown', () {
      const text = 'MARKET BASKET\n123 MAIN ST\nBANANAS 1.29\nOAT MILK 3.99\n2 @ 3.99\nTOTAL 9.27';
      expect(_simple(parseReceiptText(text)), [
        ('BANANAS', 1.0, 'ea', null),
        ('OAT MILK', 2.0, 'ea', null),
      ]);
    });
  });

  group('[EQUIV] mergeReceiptItems', () {
    // testTheory: equivalence — identical raw text with the same unit is one
    //   product bought several times.
    // contract: key = raw + unit; first-seen order kept; quantities summed.
    // implication: AC6 — six identical soup lines become one review row of 6.

    test('AC6: identical ea lines merge and sum', () {
      const soup = ParsedReceiptItem(raw: 'PROG TRD CHK ORZ LMN', qty: 1, unit: 'ea', food: true);
      final merged = mergeReceiptItems([
        soup,
        const ParsedReceiptItem(raw: 'LIMES', qty: 1, unit: 'ea', food: true),
        soup,
        soup.copyWith(qty: 2),
      ]);
      expect(_simple(merged), [
        ('PROG TRD CHK ORZ LMN', 4.0, 'ea', true),
        ('LIMES', 1.0, 'ea', true),
      ]);
    });

    test('AC6: different units stay separate; weights sum', () {
      final merged = mergeReceiptItems(const [
        ParsedReceiptItem(raw: 'SHALLOTS', qty: 1, unit: 'ea', food: true),
        ParsedReceiptItem(raw: 'SHALLOTS', qty: 0.5, unit: 'lb', food: true),
        ParsedReceiptItem(raw: 'SHALLOTS', qty: 0.25, unit: 'lb', food: true),
      ]);
      expect(_simple(merged), [
        ('SHALLOTS', 1.0, 'ea', true),
        ('SHALLOTS', 0.75, 'lb', true),
      ]);
    });
  });

  group('[MFT] receiptItemRegion and helpers', () {
    // testTheory: minimum functionality — the AI only ever sees text up to the
    //   end marker, never card or payment lines.
    // contract: lines up to and including the first BALANCE DUE or
    //   (SUB)TOTAL <price> line; all lines if none.
    // implication: decision 9 — privacy of payment lines.

    test('region stops at BALANCE DUE inclusive', () {
      expect(receiptItemRegion(_hannaford).split('\n').last, '23 BALANCE DUE 68.11');
      expect(receiptItemRegion(_hannaford), isNot(contains('VISA')));
    });

    test('region is the whole text without a marker', () {
      expect(receiptItemRegion('A 1.00\nB 2.00'), 'A 1.00\nB 2.00');
    });

    test('normalizeReceiptLine uppercases and keeps receipt symbols', () {
      expect(normalizeReceiptLine('  Dve men+care cdrwd/t 10.49 米 '), 'DVE MEN+CARE CDRWD/T 10.49');
      expect(normalizeReceiptLine('2@ 1.39'), '2@ 1.39');
    });

    test('sequenceRatio matches Python difflib', () {
      expect(sequenceRatio('GENERA MDSE', 'GENERAL MDSE'), closeTo(22 / 23, 1e-9));
      expect(sequenceRatio('GROCER', 'GROCERY'), closeTo(12 / 13, 1e-9));
      expect(sequenceRatio('ABCD', 'BCDA'), closeTo(0.75, 1e-9));
      expect(sequenceRatio('', ''), 1.0);
    });
  });
}
