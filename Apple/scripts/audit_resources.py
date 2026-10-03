#!/usr/bin/env python3
"""Check the current built-in source subset against converter dependency manifests.

Read-only: no source pruning, compression, runtime downloads or user-data access.
"""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Assets/Upstream/VPet/Core'
OUTPUT = ROOT / 'Apple/Resources/PetAssets'
# Food layers are read from info.lps but are not represented by the PNG source map.
ANIMATION_CONFIGS = {'pet/vup/Drink/info.lps'} | {
    f'pet/vup/{action}/{mood}/info.lps'
    for action in ['Eat', 'Gift'] for mood in ['Happy', 'Nomal', 'PoorCondition', 'Ill']
}
METADATA = {'info.lps', 'icon.png', 'pet/vup.lps'} | ANIMATION_CONFIGS


def audit(source, output, tracked):
    dependencies = {}
    frames = json.loads((output / 'sources.sha256.json').read_text())
    for path, record in frames.items():
        dependencies['pet/vup/' + path] = record['sha256']
    for filename in ['gameplay-sources.sha256.json', 'dialogue-sources.sha256.json']:
        for path, digest in json.loads((output / filename).read_text()).items():
            if path in dependencies and dependencies[path] != digest:
                raise ValueError('Conflicting dependency digest: ' + path)
            dependencies[path] = digest
    source = source.resolve()
    required = set(dependencies) | METADATA
    for relative in required:
        path = source / relative
        if Path(relative).is_absolute() or not path.resolve().is_relative_to(source):
            raise ValueError('Unsafe dependency path: ' + relative)
        if not path.is_file() or path.is_symlink():
            raise ValueError('Missing or linked dependency: ' + relative)
        if relative in dependencies and hashlib.sha256(path.read_bytes()).hexdigest() != dependencies[relative]:
            raise ValueError('Source digest differs from conversion: ' + relative)
    tracked = set(tracked)
    missing = required - tracked
    extra = tracked - required
    if missing:
        raise ValueError('Required source is not tracked: ' + ', '.join(sorted(missing)))
    if extra:
        raise ValueError('Unused tracked source files: ' + ', '.join(sorted(extra)))
    return len(required), sum((source / path).stat().st_size for path in required)


if __name__ == '__main__':
    names = subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', '-z', '--', str(SOURCE)]).split(b'\0')
    tracked = [Path(name.decode()).relative_to(SOURCE.relative_to(ROOT)).as_posix() for name in names if name]
    count, size = audit(SOURCE, OUTPUT, tracked)
    print(f'Built-in source closure verified: {count} files, {size / 1024**2:.2f} MiB; no unused tracked assets.')
