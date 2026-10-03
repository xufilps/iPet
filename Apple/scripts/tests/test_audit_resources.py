import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from audit_resources import audit, METADATA


class AuditResourcesTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.source = Path(self.directory.name) / 'source'
        self.output = Path(self.directory.name) / 'output'
        self.output.mkdir()
        self.names = set(METADATA) | {'pet/vup/Default/idle_100.png', 'food/food.lps'}
        for name in self.names:
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(name.encode())
        digest = lambda name: hashlib.sha256((self.source / name).read_bytes()).hexdigest()
        (self.output / 'sources.sha256.json').write_text(json.dumps({'Default/idle_100.png': {'sha256': digest('pet/vup/Default/idle_100.png')}}))
        (self.output / 'gameplay-sources.sha256.json').write_text(json.dumps({'food/food.lps': digest('food/food.lps')}))
        (self.output / 'dialogue-sources.sha256.json').write_text(json.dumps({'pet/vup.lps': digest('pet/vup.lps')}))

    def testExactClosureAndUnusedTrackedFile(self):
        count, size = audit(self.source, self.output, self.names)
        self.assertEqual(count, len(self.names))
        self.assertEqual(size, sum((self.source / name).stat().st_size for name in self.names))
        with self.assertRaisesRegex(ValueError, 'Unused tracked'):
            audit(self.source, self.output, self.names | {'file/gallery.zlps'})

    def testChangedMissingAndUntrackedDependency(self):
        path = self.source / 'food/food.lps'
        original = path.read_bytes()
        path.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'digest differs'):
            audit(self.source, self.output, self.names)
        path.unlink()
        with self.assertRaisesRegex(ValueError, 'Missing'):
            audit(self.source, self.output, self.names)
        path.write_bytes(original)
        with self.assertRaisesRegex(ValueError, 'not tracked'):
            audit(self.source, self.output, self.names - {'food/food.lps'})

    def testUnsafeManifestPathIsRejected(self):
        (self.output / 'gameplay-sources.sha256.json').write_text(json.dumps({'../outside': 'ignored'}))
        with self.assertRaisesRegex(ValueError, 'Unsafe'):
            audit(self.source, self.output, self.names)
