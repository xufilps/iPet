#!/usr/bin/env python3
"""Validate maintained entry points, original legal bytes and generated project drift.

Uses only the standard library; does not read user data or edit generated resources.
Historical upstream Markdown is preserved, not treated as current build documentation.
"""
from pathlib import Path
import hashlib
import re
import subprocess
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]
LICENSE_SHA256 = 'c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4'


def verify():
    errors = []
    required = [
        'Apple/Package.swift', 'Apple/Sources/PetCore', 'Apple/Sources/PetRendering',
        'Apple/Sources/PetMacInput', 'Apple/Apps/macOS/main.swift',
        'Apple/Tests/PetCoreTests', 'Apple/Tests/PetRenderingTests', 'Apple/Tests/PetMacInputTests',
        'Assets/Upstream/VPet/Core/pet/vup', 'Apple/docs/README.md',
        'CONTRIBUTING.md', 'CODE_OF_CONDUCT.md', 'SECURITY.md', 'SUPPORT.md',
        '.github/ISSUE_TEMPLATE/bug_report.yml', '.github/ISSUE_TEMPLATE/feature_request.yml',
        '.github/ISSUE_TEMPLATE/security_contact.yml',
        '.github/PULL_REQUEST_TEMPLATE.md', '.github/workflows/verify.yml',
    ]
    for relative in required:
        if not (ROOT / relative).exists():
            errors.append(f'Missing entry point: {relative}')
    if hashlib.sha256((ROOT / 'LICENSE').read_bytes()).hexdigest() != LICENSE_SHA256:
        errors.append('The upstream LICENSE has changed.')
    for line in (ROOT / 'docs/upstream/SHA256SUMS').read_text().splitlines():
        digest, filename = line.split('  ', 1)
        path = ROOT / 'docs/upstream' / filename
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            errors.append(f'Upstream archive changed: {filename}')
    documents = list((ROOT / 'Apple/docs').rglob('*.md')) + [
        ROOT / 'Apple/README.md', ROOT / 'Apple/ATTRIBUTION.md',
        ROOT / 'CONTRIBUTING.md', ROOT / 'SUPPORT.md', ROOT / 'SECURITY.md',
        ROOT / 'CODE_OF_CONDUCT.md', ROOT / 'Assets/Upstream/README.md',
        ROOT / 'docs/upstream/README.md', ROOT / 'README.md',
    ]
    for path in documents:
        content = path.read_text()
        for target in re.findall(r'\]\(([^)]+)\)', content):
            if '://' in target or target.startswith('#'):
                continue
            relative = unquote(target.split('#')[0])
            if relative and not (path.parent / relative).exists():
                errors.append(f'Broken link: {path.relative_to(ROOT)} -> {target}')
    # Generate into the existing project, restoring original files even on failure.
    paths = [ROOT / 'Apple/iPet.xcodeproj/project.pbxproj',
             ROOT / 'Apple/iPet.xcodeproj/xcshareddata/xcschemes/iPet.xcscheme']
    before = {path: path.read_bytes() for path in paths}
    try:
        subprocess.run(['/usr/bin/python3', str(ROOT / 'Apple/scripts/create_project.py')], check=True)
        for path in paths:
            if path.read_bytes() != before[path]:
                errors.append(f'Generated project drift: {path.relative_to(ROOT)}')
    finally:
        for path, data in before.items():
            if path.read_bytes() != data:
                path.write_bytes(data)
    if errors:
        raise SystemExit('\n'.join(errors))
    print('Repository entry points, original legal/archive bytes, documentation links and project generation verified.')


if __name__ == '__main__':
    verify()
