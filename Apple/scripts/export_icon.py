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
IOS_SOURCE = ROOT / 'Design/ipet-icon-ios-v1-source.png'
IOS_CATALOG = ROOT / 'Resources/iOSAssets.xcassets'
IOS_ICONSET = IOS_CATALOG / 'AppIcon.appiconset'
SIZES = [16, 32, 64, 128, 256, 512, 1024]

def dimensions(path):
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f'Not a PNG: {path}')
    return struct.unpack('>II', data[16:24])

def contents():
    return {'images': [{'filename': f'icon-{size * scale}.png', 'idiom': 'mac', 'scale': f'{scale}x', 'size': f'{size}x{size}'} for size in [16, 32, 128, 256, 512] for scale in [1, 2]], 'info': {'author': 'xcode', 'version': 1}}

def ios_contents():
    return {'images': [{'filename': 'icon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}}

def check():
    assert dimensions(MASTER) == (1024, 1024), 'Master must be 1024 square'
    assert json.loads((ICONSET / 'Contents.json').read_text()) == contents(), 'AppIcon mappings differ'
    for size in SIZES:
        assert dimensions(ICONSET / f'icon-{size}.png') == (size, size), f'Invalid {size}px export'
    print('AppIcon master and all 10 macOS image wells validated.')
    assert json.loads((IOS_ICONSET / 'Contents.json').read_text()) == ios_contents()
    path = IOS_ICONSET / 'icon-1024.png'
    assert dimensions(path) == (1024, 1024), 'iOS AppIcon must be 1024 square'
    assert path.read_bytes()[25] == 2, 'iOS AppIcon must be opaque RGB without alpha'
    print('Opaque full-bleed iOS AppIcon validated.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--check', action='store_true'); args = parser.parse_args()
    if not args.check:
        assert dimensions(MASTER) == (1024, 1024)
        ICONSET.mkdir(parents=True, exist_ok=True)
        for size in SIZES:
            subprocess.run(['/usr/bin/sips', '-z', str(size), str(size), str(MASTER), '--out', str(ICONSET / f'icon-{size}.png')], check=True, stdout=subprocess.DEVNULL)
        (CATALOG / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
        (ICONSET / 'Contents.json').write_text(json.dumps(contents(), indent=2) + '\n')
        IOS_ICONSET.mkdir(parents=True, exist_ok=True)
        subprocess.run(['/usr/bin/sips', '-z', '1024', '1024', str(IOS_SOURCE), '--out', str(IOS_ICONSET / 'icon-1024.png')], check=True, stdout=subprocess.DEVNULL)
        (IOS_CATALOG / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
        (IOS_ICONSET / 'Contents.json').write_text(json.dumps(ios_contents(), indent=2) + '\n')
    check()
