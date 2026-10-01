import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from convert_gameplay import convert_gameplay, normalize_work

SOURCE = Path(__file__).resolve().parents[3] / 'VPet-Simulator.Windows/mod/0000_core'
class GameplayTests(unittest.TestCase):
    def test_catalog_counts_source_values_and_stable_outputs(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp); convert_gameplay(SOURCE, out)
            data = json.loads((out/'gameplay.json').read_text())
            self.assertEqual(len(data['activities']),13); self.assertEqual(len(data['items']),118)
            work = next(x for x in data['activities'] if x['name']=='文案')
            self.assertEqual(work['moneyBase'],8); self.assertEqual(work['durationSeconds'],3600)
            drug = next(x for x in data['items'] if x['name']=='太阳系')
            self.assertEqual(drug['price'],0); self.assertEqual(drug['experience'],-180)
            self.assertEqual(drug['strength'],-100)
            self.assertEqual(len({x['id'] for x in data['items']}),118)
            before={p:(p.read_bytes(),p.stat().st_mtime_ns) for p in out.rglob('*') if p.is_file()}
            convert_gameplay(SOURCE,out)
            self.assertEqual(before,{p:(p.read_bytes(),p.stat().st_mtime_ns) for p in before})
    def test_overload_normalization_and_validation(self):
        fields={'Type':'Play','MoneyBase':'10000','StrengthFood':'1','StrengthDrink':'1.5','Feeling':'1','Time':'1','FinishBonus':'5','LevelLimit':'-1'}
        work = normalize_work(fields)
        self.assertEqual(work['durationSeconds'],600); self.assertLessEqual(work['moneyBase'],100)
        self.assertLessEqual(work['feeling'],0); self.assertLessEqual(work['finishBonus'],2)
        with self.assertRaises(ValueError): normalize_work({'Type':'Work','Time':'nan'})

    def test_duplicate_items_and_nonfinite_fields_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'source'; (source/'pet').mkdir(parents=True); (source/'food').mkdir()
            (source/'pet/vup.lps').write_text('work:|Type#Work:|Name#x:|Graph#workone:|Time#10:\n')
            for name in ['food.lps','moredrink.lps','drug.lps','gift.lps']: (source/'food'/name).write_text('')
            item='food:|name#x:|price#1:\n'
            (source/'food/food.lps').write_text(item+item)
            with self.assertRaisesRegex(ValueError,'Duplicate'): convert_gameplay(source,Path(tmp)/'output')
            (source/'food/food.lps').write_text('food:|name#x:|price#nan:\n')
            with self.assertRaises(ValueError): convert_gameplay(source,Path(tmp)/'output')
