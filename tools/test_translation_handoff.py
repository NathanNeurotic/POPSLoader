"""Regression checks for volunteer returns; no Excel installation required."""
import tempfile
import unittest
import zipfile
from pathlib import Path

from translation_handoff import (FORMAT, check_catalogs, decode_literal, escape_handoff,
                                 read_tsv, read_xlsx, source_data, unescape_handoff, validate_rows)


class TranslationHandoffTests(unittest.TestCase):
    def test_current_catalogs_and_workbook(self):
        self.assertEqual(check_catalogs(), [])

    def test_partial_translation_omits_empty_values(self):
        self.assertEqual(validate_rows([('Settings', 'Nastavenia'), ('Close', '')],
                                       {'Settings', 'Close'}), {'Settings': 'Nastavenia'})

    def test_invalid_returns(self):
        for rows, allowed in [
            ([('Changed key', 'x')], {'Settings'}),
            ([('Settings', 'a'), ('Settings', 'b')], {'Settings'}),
            ([('Value %s %d', 'Hodnota %d %s')], {'Value %s %d'}),
            ([('Value %s', 'Hodnota')], {'Value %s'}),
            ([('Value %s', 'Hodnota %1$s')], {'Value %s'}),
            ([(r'Line\nLine', 'Riadok')], {r'Line\nLine'}),
            ([('Settings', 'Riadok\nRiadok')], {'Settings'}),
            ([(' (%d hidden)', '(%d skryté)')], {' (%d hidden)'}),
        ]:
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                validate_rows(rows, allowed)

    def test_lua_and_handoff_escaping(self):
        text = 'C:\\new\\test "quoted"\nčľťž\t'
        self.assertEqual(unescape_handoff(escape_handoff(text)), text)
        self.assertEqual(decode_literal(r'"A\nB\032\x43\u{10D}"'), 'A\nB Cč')
        self.assertEqual(decode_literal('[=[\ncredits\n]=]'), 'credits\n')

    def test_tsv_bom_empty_target_and_broken_record(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'return.tsv'
            path.write_text('\ufeffEnglish (do not edit)\tSlovak\nSettings\t\n', encoding='utf-8')
            self.assertEqual(read_tsv(path), [['Settings', '']])
            path.write_text('English\tSlovak\nSettings\tbad\nfragment\n', encoding='utf-8')
            with self.assertRaises(ValueError):
                read_tsv(path)

    def test_xlsx_named_sheet_inline_shared_rich_text_and_rejections(self):
        # A return may reorder tabs or use Excel's shared or inline strings.
        ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'return.xlsx'
            for target, expected in [
                ('<c r="B2" t="s"><v>1</v></c>', 'Nastavenia'),
                ('<c r="B2" t="inlineStr"><is><r><t>Nasta</t></r><r><t>venia</t></r></is></c>', 'Nastavenia'),
                ('', ''),
                ('<c r="B2"><f>1+1</f><v>2</v></c>', ValueError),
                ('<c r="B2"><v>123</v></c>', ValueError),
            ]:
                with zipfile.ZipFile(path, 'w') as z:
                    z.writestr('xl/workbook.xml', f'<workbook xmlns="{ns}" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Instructions" r:id="r1"/><sheet name="Slovak" r:id="r9"/></sheets></workbook>')
                    z.writestr('xl/_rels/workbook.xml.rels', '<Relationships><Relationship Id="r9" Target="worksheets/sheet9.xml"/></Relationships>')
                    z.writestr('xl/sharedStrings.xml', f'<sst xmlns="{ns}"><si><t>Settings</t></si><si><t>Nastavenia</t></si></sst>')
                    z.writestr('xl/worksheets/sheet9.xml', f'<worksheet xmlns="{ns}"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>English (do not edit)</t></is></c></row><row r="2"><c r="A2" t="s"><v>0</v></c>{target}</row></sheetData></worksheet>')
                if expected is ValueError:
                    with self.assertRaises(ValueError):
                        read_xlsx(path)
                else:
                    self.assertEqual(read_xlsx(path), [('Settings', expected)])

    def test_shipped_catalogs_cover_current_runtime_keys(self):
        _, required, dictionaries = source_data()
        self.assertEqual({'FR', 'DE', 'PT', 'ES', 'IT', 'HU'}, set(dictionaries))
        for language, rows in dictionaries.items():
            with self.subTest(language=language):
                catalog = dict(rows)
                self.assertEqual([], sorted((required | {'Detecting MMCE device...'}) - set(catalog)))
                for english, translated in rows:
                    self.assertEqual(FORMAT.findall(english), FORMAT.findall(translated))
                    self.assertEqual(english.count('\n'), translated.count('\n'))
                    self.assertEqual(english.startswith(' '), translated.startswith(' '))


if __name__ == '__main__':
    unittest.main()
