#!/usr/bin/env python3
"""Export deterministic macOS AppIcon sizes from the committed generated master."""
from pathlib import Path
import json
import subprocess
import struct
import argparse

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / 'Design/ipet-icon-pixel-v1-master.png'
CATALOG = ROOT / 'Resources/Assets.xcassets'
ICONSET = CATALOG / 'AppIcon.appiconset'
SIZES = [16, 32, 64, 128, 256, 512, 1024]

def dimensions(path):
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f'Not a PNG: {path}')
    return struct.unpack('>II', data[16:24])

def contents():
    return {'images': [{'filename': f'icon-{size * scale}.png', 'idiom': 'mac', 'scale': f'{scale}x', 'size': f'{size}x{size}'} for size in [16, 32, 128, 256, 512] for scale in [1, 2]], 'info': {'author': 'xcode', 'version': 1}}

def check():
    assert dimensions(MASTER) == (1024, 1024), 'Master must be 1024 square'
    assert json.loads((ICONSET / 'Contents.json').read_text()) == contents(), 'AppIcon mappings differ'
    for size in SIZES:
        assert dimensions(ICONSET / f'icon-{size}.png') == (size, size), f'Invalid {size}px export'
    print('AppIcon master and all 10 macOS image wells validated.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--check', action='store_true'); args = parser.parse_args()
    if not args.check:
        assert dimensions(MASTER) == (1024, 1024)
        ICONSET.mkdir(parents=True, exist_ok=True)
        for size in SIZES:
            subprocess.run(['/usr/bin/sips', '-z', str(size), str(size), str(MASTER), '--out', str(ICONSET / f'icon-{size}.png')], check=True, stdout=subprocess.DEVNULL)
        (CATALOG / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
        (ICONSET / 'Contents.json').write_text(json.dumps(contents(), indent=2) + '\n')
    check()
