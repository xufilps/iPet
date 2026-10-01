import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from convert_assets import convert
SOURCE=Path(__file__).resolve().parents[3]/'VPet-Simulator.Windows/mod/0000_core'
class ActivityAssetsTests(unittest.TestCase):
    def test_all_activity_graphs_and_gift_have_real_stages(self):
        with tempfile.TemporaryDirectory() as tmp:
            convert(SOURCE,Path(tmp));manifest=json.loads((Path(tmp)/'manifest.json').read_text())
            graphs={c.get('graphID') for c in manifest['clips'] if c['action']=='activity'}
            self.assertEqual(len(graphs),13)
            for name in ['workone','study','playone']:
                clips=[c for c in manifest['clips'] if c.get('graphID')==name]
                self.assertTrue(clips)
                self.assertTrue(any(s['phase']=='loop' for c in clips for s in c['stages']))
            self.assertTrue(any(c['action']=='gift' for c in manifest['clips']))
