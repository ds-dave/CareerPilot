#!/usr/bin/env python3
"""Create a reviewable source archive from an explicit allowlist; never include user data."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
import json

root = Path(__file__).resolve().parents[1]
files = [root / name for name in ('.gitignore', 'README.md', 'LICENSE', 'SECURITY.md')]
patterns = {
    'CareerPilot': ('*.swift', '*.json', '*.png', '*.ttf', '*.txt'),
    'CareerPilotTests': ('*.swift',),
    'Config': ('*.entitlements',),
    'docs': ('*.md', '*.jpg', '*.png', '*.svg', '*.json'),
    'scripts': ('*.sh', '*.py'),
}
for directory, globs in patterns.items():
    for pattern in globs:
        files.extend((root / directory).rglob(pattern))
files += [root / 'CareerPilot.xcodeproj/project.pbxproj',
          root / 'CareerPilot.xcodeproj/xcshareddata/xcschemes/CareerPilot.xcscheme']
files = sorted(set(files))
for file in files:
    if not file.is_file() or file.is_symlink() or any(p.startswith('.') for p in file.relative_to(root).parts[:-1]):
        raise SystemExit(f'Unexpected source path: {file.relative_to(root)}')
    if any(parent.is_symlink() for parent in file.parents if parent != root.parent):
        raise SystemExit(f'Symlinked source path: {file.relative_to(root)}')
output = root / 'release'
output.mkdir(exist_ok=True)
archive = output / 'CareerPilot-source.zip'
manifest = {}
with ZipFile(archive, 'w', ZIP_DEFLATED) as z:
    for file in files:
        name = file.relative_to(root).as_posix()
        data = file.read_bytes()
        manifest[name] = hashlib.sha256(data).hexdigest()
        z.writestr('CareerPilot/' + name, data)
(output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f'{len(files)} files packaged: {archive}')
print('Review release/manifest.json before publication. This is a source archive, not a signed app.')
