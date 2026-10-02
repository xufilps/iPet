"""Regression tests for actual conversion outputs and recovery, using tiny valid PNGs."""
import contextlib
import io
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from convert_assets import convert


def png(red):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes([0, red, 0, 0, 255]))) + chunk(b'IEND', b'')


class ConversionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.source = Path(self.temp.name) / 'source'
        self.output = Path(self.temp.name) / 'output'
        self.frame = self.source / 'pet/vup/Default/Nomal/idle_0_100.png'
        self.frame.parent.mkdir(parents=True)
        self.frame.write_bytes(png(100))
        self.config = self.source / 'pet/vup.lps'
        self.config.write_text('touchhead:|px#10:|py#20:|sw#30:|sh#40:\n')
        self.run_conversion()
        self.exported_frame = self.output / 'frames/Default/Nomal/idle_0_100.png'

    def run_conversion(self):
        with contextlib.redirect_stdout(io.StringIO()):
            convert(self.source, self.output)

    def stamp_outputs(self):
        for p in self.output.rglob('*'):
            if p.is_file():
                os.utime(p, ns=(1_600_000_000_000_000_000, 1_600_000_000_000_000_000))
        return {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in self.output.rglob('*') if p.is_file()}

    def test_upstream_numeric_only_filename_uses_final_numeric_milliseconds(self):
        directory=self.source/'pet/vup/IDEL/Squat/C_Happy'
        directory.mkdir(parents=True)
        start=self.source/'pet/vup/IDEL/Squat/A_Happy'
        start.mkdir(parents=True)
        (start/'000_100.png').write_bytes(png(5))
        (directory/'0002.png').write_bytes(png(10))
        (directory/'0001.png').write_bytes(png(20))
        self.run_conversion()
        manifest=json.loads((self.output/'manifest.json').read_text())
        clip=next(c for c in manifest['clips'] if c.get('graphID')=='squat')
        frames=next(s for s in clip['stages'] if s['phase']=='end')['layers'][0]['frames']
        self.assertEqual([f['duration'] for f in frames],[0.001,0.002])
        self.assertTrue(frames[0]['path'].endswith('0001.png'))

    def test_original_raised_regions_keep_per_mood_coordinates(self):
        raised=''.join(f'|{mode}_px#0:|{mode}_py#{200 if mode=="ill" else 50}:|{mode}_sw#500:|{mode}_sh#200:' for mode in ['happy','nomal','poorcondition','ill'])
        self.config.write_text(self.config.read_text()+'touchraised:'+raised+'\n')
        self.run_conversion()
        regions=json.loads((self.output/'manifest.json').read_text())['regions']
        self.assertEqual(regions['raised:Nomal']['y'],50)
        self.assertEqual(regions['raised:Ill']['y'],200)

    def test_default_alternatives_are_exported_and_validated(self):
        directory=self.source/'pet/vup/Default/Nomal/2'
        directory.mkdir(parents=True)
        (directory/'idle_0_200.png').write_bytes(png(20))
        self.run_conversion()
        manifest=json.loads((self.output/'manifest.json').read_text())
        stage=next(c for c in manifest['clips'] if c['action']=='idle')['stages'][0]
        self.assertEqual(len(stage['variants']),1)
        self.assertEqual(stage['variants'][0][0]['frames'][0]['duration'],0.2)
        self.assertTrue((self.output/'frames/Default/Nomal/2/idle_0_200.png').exists())

    def test_unchanged_conversion_preserves_all_output_content_and_mtimes(self):
        before = self.stamp_outputs()
        self.run_conversion()
        self.assertEqual(before, {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in before})

    def test_changed_source_frame_updates_bytes_and_record_hash(self):
        self.frame.write_bytes(png(200))
        self.run_conversion()
        self.assertEqual(self.frame.read_bytes(), self.exported_frame.read_bytes())
        import hashlib
        records = json.loads((self.output / 'sources.sha256.json').read_text())
        self.assertEqual(records['Default/Nomal/idle_0_100.png']['sha256'], hashlib.sha256(png(200)).hexdigest())

    def test_changed_config_updates_manifest_without_rewriting_frames(self):
        before = self.stamp_outputs()
        self.config.write_text('touchhead:|px#55:|py#20:|sw#30:|sh#40:\n')
        self.run_conversion()
        self.assertEqual(json.loads((self.output / 'manifest.json').read_text())['regions']['head']['x'], 55)
        self.assertEqual(before[self.exported_frame][1], self.exported_frame.stat().st_mtime_ns)

    def test_invalid_source_is_rejected_without_replacing_valid_frame(self):
        original = self.exported_frame.read_bytes()
        self.frame.write_bytes(b'invalid png')
        with self.assertRaisesRegex(ValueError, 'Invalid PNG'):
            self.run_conversion()
        self.assertEqual(original, self.exported_frame.read_bytes())

    def test_invalid_config_is_not_bypassed_when_outputs_exist(self):
        self.config.write_text('touchhead:|px#invalid:|py#20:|sw#30:|sh#40:\n')
        with self.assertRaises(ValueError):
            self.run_conversion()

    def test_missing_and_corrupt_outputs_are_repaired(self):
        before = self.stamp_outputs()
        self.exported_frame.unlink()
        (self.output / 'manifest.json').write_text('broken json')
        (self.output / 'sources.sha256.json').write_text('{}')
        self.run_conversion()
        for p, (data, _) in before.items():
            self.assertEqual(data, p.read_bytes())
        self.exported_frame.write_bytes(b'corrupt png')
        self.run_conversion()
        self.assertEqual(self.frame.read_bytes(), self.exported_frame.read_bytes())


if __name__ == '__main__':
    unittest.main()
