# Copyright (C) 2026 Font Harbor contributors
# SPDX-License-Identifier: GPL-3.0-only

import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'Scripts'))
from generate_font_index import category, preferred_file, encoded_raw_url
from validate_catalog import validate


class CatalogTests(unittest.TestCase):
    def document(self):
        return {'schemaVersion': 1, 'generatedAt': '2026-10-13T20:00:00+00:00',
                'sources': [{'name': 'Google Fonts', 'count': 1}],
                'fonts': [{'id': 'example', 'family': 'Example', 'designer': 'Designer',
                           'license': 'SIL Open Font License', 'description': 'Example family',
                           'category': 'Sans Serif', 'source': 'Google Fonts', 'tags': ['Variable'],
                           'fileName': 'Example.ttf', 'downloadURL': 'https://example.com/Example.ttf',
                           'repositoryURL': 'https://example.com/source'}]}

    def test_prefers_upright_variable_over_static_and_italic(self):
        paths = ['ofl/example/Example-Italic.ttf', 'ofl/example/Example-Regular.ttf', 'ofl/example/Example[wght].ttf']
        self.assertEqual(preferred_file(paths), paths[2])
        self.assertEqual(category('Handwriting'), 'Display')
        self.assertIn('Example%5Bwght%5D.ttf', encoded_raw_url('google/fonts', 'main', paths[2]))

    def test_valid_document(self):
        self.assertEqual(validate(self.document()), 1)

    def test_duplicate_ids_and_wrong_counts(self):
        doc = self.document()
        doc['fonts'].append(copy.deepcopy(doc['fonts'][0]))
        with self.assertRaises(ValueError): validate(doc)
        doc = self.document()
        doc['sources'][0]['count'] = 2
        with self.assertRaises(ValueError): validate(doc)

    def test_unsafe_url_and_filename(self):
        for field, value in [('downloadURL', 'http://example.com/a.ttf'), ('repositoryURL', 'https://user:secret@example.com'), ('fileName', '../a.ttf')]:
            with self.subTest(field=field):
                doc = self.document()
                doc['fonts'][0][field] = value
                with self.assertRaises(ValueError): validate(doc)


if __name__ == '__main__': unittest.main()
