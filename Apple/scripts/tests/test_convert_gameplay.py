import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from convert_gameplay import convert_gameplay, normalize_work, normalize_package

SOURCE = Path(__file__).resolve().parents[3] / 'VPet-Simulator.Windows/mod/0000_core'
class GameplayTests(unittest.TestCase):
    def test_catalog_counts_source_values_and_stable_outputs(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp); convert_gameplay(SOURCE, out)
            data = json.loads((out/'gameplay.json').read_text())
            self.assertEqual(len(data['activities']),13); self.assertEqual(len(data['items']),118)
            self.assertEqual(len(data['packages']),14)
            self.assertEqual({p['kind'] for p in data['packages']},{'work','study'})
            self.assertEqual(len({p['id'] for p in data['packages']}),14)
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
            (source/'text').mkdir();(source/'text/SchedulePackage.lps').write_text('')
            (source/'pet/vup.lps').write_text('work:|Type#Work:|Name#x:|Graph#workone:|Time#10:\n')
            for name in ['food.lps','moredrink.lps','drug.lps','gift.lps']: (source/'food'/name).write_text('')
            item='food:|name#x:|price#1:\n'
            (source/'food/food.lps').write_text(item+item)
            with self.assertRaisesRegex(ValueError,'Duplicate'): convert_gameplay(source,Path(tmp)/'output')
            (source/'food/food.lps').write_text('food:|name#x:|price#nan:\n')
            with self.assertRaises(ValueError): convert_gameplay(source,Path(tmp)/'output')

    def test_package_source_normalization_and_zero_price(self):
        base=normalize_package({'WorkType':'Work','Duration':'7','Price':'1','LevelInNeed':'1.25','Commissions':'.2'})
        self.assertEqual(base,{'kind':'work','durationDays':7,'unitPrice':1,'levelRatio':1.25,'commission':.2})
        fallback=normalize_package({'WorkType':'Study','Duration':'30','Price':'0','LevelInNeed':'1','Commissions':'0'})
        self.assertEqual(fallback['unitPrice'],1);self.assertEqual(fallback['durationDays'],7)
        zero=normalize_package({'WorkType':'Study','Duration':'30','Price':'0','LevelInNeed':'1','Commissions':'.5'})
        self.assertEqual(zero['unitPrice'],0);self.assertEqual(zero['commission'],.5)
        with self.assertRaises(ValueError): normalize_package({'WorkType':'Play'})
        with self.assertRaises(ValueError): normalize_package({'WorkType':'Work','Price':'nan'})
        with self.assertRaises(ValueError): normalize_package({'WorkType':'Work','Duration':'7.5'})

    def test_package_duplicate_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            import shutil
            source=Path(tmp)/'source';shutil.copytree(SOURCE,source,ignore=shutil.ignore_patterns('*.png'))
            config=source/'text/SchedulePackage.lps'
            config.write_text(config.read_text()+config.read_text().splitlines()[0]+'\n')
            with self.assertRaisesRegex(ValueError,'Duplicate'): convert_gameplay(source,Path(tmp)/'output')
