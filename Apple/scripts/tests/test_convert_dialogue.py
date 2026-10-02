import json
from pathlib import Path
import tempfile
import unittest
from convert_dialogue import convert_dialogue
class DialogueConversionTests(unittest.TestCase):
    def test_content_conditions_effects_and_unchanged_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'source';output=root/'out'
            (source/'text').mkdir(parents=True);(source/'pet').mkdir()
            (source/'pet/vup.lps').write_text('tag#all,vup,girl:|\n')
            (source/'text/ClickText.lps').write_text('clicktext:|Text#你好{name}:|Mode#2:|Money#-1:|LikeMin#40:|tag#girl:\n')
            convert_dialogue(source,output)
            entry=json.loads((output/'dialogue.json').read_text())['entries'][0]
            self.assertEqual(entry['text'],'你好{name}');self.assertEqual(entry['effects']['money'],-1)
            self.assertEqual(entry['bounds']['likemin'],40)
            before=(output/'dialogue.json').stat().st_mtime_ns
            convert_dialogue(source,output);self.assertEqual(before,(output/'dialogue.json').stat().st_mtime_ns)
            (source/'text/ClickText.lps').write_text('clicktext:|Text#未知{secret}:\n')
            with self.assertRaises(ValueError):convert_dialogue(source,output)
    def test_unknown_fields_and_nonfinite_values_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'text').mkdir();(root/'pet').mkdir();(root/'pet/vup.lps').write_text('tag#all:|')
            for line in ['clicktext:|Text#嗨:|Money#NaN:','clicktext:|Text#嗨:|Plugin#run:']:
                (root/'text/ClickText.lps').write_text(line)
                with self.assertRaises(ValueError):convert_dialogue(root,root/'out')
