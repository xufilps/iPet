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
    def test_selection_distinct_tags_clamps_bounds_and_stable_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'text').mkdir();(root/'pet').mkdir();(root/'pet/vup.lps').write_text('tag#all,girl:|')
            (root/'text/SelectText.lps').write_text('selecttext:|Choose#问候:|Text#金币{money}:|tag#girl:|Tags#a,b:|ToTags#b:|Money#2000:|Feeling#200:|Likability#-80:|Exp#2:|FoodMin#20:|FoodMax#20:')
            convert_dialogue(root,root/'out')
            path=root/'out/selection-dialogue.json';entry=json.loads(path.read_text())['entries'][0]
            self.assertEqual(entry['characterTags'],['girl']);self.assertEqual(entry['conversationTags'],['a','b']);self.assertEqual(entry['toTags'],['b'])
            self.assertEqual(entry['effects']['money'],1000);self.assertEqual(entry['effects']['feeling'],100);self.assertEqual(entry['effects']['affection'],-50);self.assertEqual(entry['effects']['experience'],2)
            self.assertEqual(entry['bounds'],{'foodmin':20,'foodmax':20})
            before=path.stat().st_mtime_ns;convert_dialogue(root,root/'out');self.assertEqual(before,path.stat().st_mtime_ns)
            self.assertIn('text/SelectText.lps',json.loads((root/'out/dialogue-sources.sha256.json').read_text()))
    def test_selection_rejects_unsupported_or_invalid_data(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'text').mkdir();(root/'pet').mkdir();(root/'pet/vup.lps').write_text('tag#all:|')
            for tail in ['Money#NaN','Exp#2.9','Plugin#run','FoodMin#30:|FoodMax#20','Text#{secret}']:
                (root/'text/SelectText.lps').write_text('selecttext:|Choose#问:|Text#答:|'+tail+':|')
                with self.assertRaises(ValueError):convert_dialogue(root,root/'out')
