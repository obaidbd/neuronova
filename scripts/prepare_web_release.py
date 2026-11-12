#!/usr/bin/env python3
"""Fingerprint Flutter entrypoints so long-lived HTTP caches cannot pin an old UI."""
import argparse
import hashlib
from pathlib import Path


def prepare(directory: Path, revision: str) -> tuple[str, str]:
    main = directory / 'main.dart.js'
    bootstrap = directory / 'flutter_bootstrap.js'
    index = directory / 'index.html'
    source = bootstrap.read_text()
    html = index.read_text()
    if 'main.dart.js' not in source or 'flutter_bootstrap.js' not in html:
        raise ValueError('Expected Flutter JavaScript entrypoints were not found')
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
