#!/usr/bin/env python3
"""Fingerprint Flutter entrypoints and assets so long-lived caches cannot pin old UI or fonts."""
import argparse
import hashlib
import shutil
from pathlib import Path


def prepare(directory: Path, revision: str) -> tuple[str, str]:
    main = directory / 'main.dart.js'
    bootstrap = directory / 'flutter_bootstrap.js'
    index = directory / 'index.html'
    source = bootstrap.read_text()
    html = index.read_text()
    if 'main.dart.js' not in source or 'flutter_bootstrap.js' not in html:
        raise ValueError('Expected Flutter JavaScript entrypoints were not found')
    assets = directory / 'assets'
    asset_digest = hashlib.sha256()
    for file in sorted(assets.rglob('*')):
        if file.is_file():
            asset_digest.update(file.relative_to(assets).as_posix().encode() + b'\0')
            asset_digest.update(hashlib.sha256(file.read_bytes()).digest())
    asset_base = f'resources.{asset_digest.hexdigest()[:20]}/'
    if '__NEURONOVA_ASSET_BASE__' not in source:
        raise ValueError('Asset version marker is missing from the Flutter bootstrap')
    source = source.replace('__NEURONOVA_ASSET_BASE__', asset_base)
    shutil.copytree(assets, directory / asset_base / 'assets', dirs_exist_ok=True)
    # Retain the root assets for already-open clients; new builds use hashed paths.
    for icon_path in ['favicon.png', 'icons/Icon-192.png']:
        icon = directory / icon_path
        if icon.is_file():
            name = f'{icon.stem}.{hashlib.sha256(icon.read_bytes()).hexdigest()[:20]}{icon.suffix}'
            icon.with_name(name).write_bytes(icon.read_bytes())
            html = html.replace(icon_path, Path(icon_path).with_name(name).as_posix())
    main_name = f'main.{hashlib.sha256(main.read_bytes()).hexdigest()[:20]}.dart.js'
    source = source.replace('main.dart.js', main_name)
    bootstrap_name = f'flutter_bootstrap.{hashlib.sha256(source.encode()).hexdigest()[:20]}.js'
    html = html.replace('flutter_bootstrap.js', bootstrap_name)
    # No release identifier is shown in the game UI; this aids deployment checks.
    if revision:
        import html as html_module
        html = html.replace('</head>', f'<meta name="neuronova-release" content="{html_module.escape(revision, quote=True)}">\n</head>')
    (directory / main_name).write_bytes(main.read_bytes())
    (directory / bootstrap_name).write_text(source)
    index.write_text(html)
    main.unlink()
    bootstrap.unlink()
    return main_name, bootstrap_name


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--revision', default='')
    args = parser.parse_args()
    names = prepare(args.directory, args.revision)
    print('Prepared cache-safe entrypoints:', *names)
