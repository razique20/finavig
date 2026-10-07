#!/usr/bin/env python3
"""Finalize raw simulator screenshots for docs/screenshots/.

The capture script takes raw `xcrun simctl io screenshot` images (iPhone 17
Pro, 1206x2622) at each `==SCREEN:==` marker. The committed gallery is a
uniform 1080x2400 (360x800 logical @3x), so each shot is resampled to that
canvas, sanity-checked (not blank, not a duplicate of another shot), and
written into docs/screenshots/<name>.png.

Usage: python3 tool/finalize_docs_shots.py <raw-dir>
"""

import sys
import os
from PIL import Image, ImageStat

TARGET = (1080, 2400)
# A screen with real content has plenty of spread; a blank/failed frame does not.
MIN_STDDEV = 8.0


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    raw_dir = sys.argv[1]
    out_dir = os.path.join('docs', 'screenshots')
    os.makedirs(out_dir, exist_ok=True)

    shots = sorted(f for f in os.listdir(raw_dir) if f.endswith('.png'))
    if not shots:
        print(f'no raw screenshots in {raw_dir}')
        return 1

    failed = []
    signatures = {}
    for name in shots:
        path = os.path.join(raw_dir, name)
        with Image.open(path) as im:
            im = im.convert('RGB')
            stat = ImageStat.Stat(im.convert('L'))
            spread = stat.stddev[0]
            resized = im.resize(TARGET, Image.LANCZOS)
            out_path = os.path.join(out_dir, name)
            resized.save(out_path, 'PNG', optimize=True)

        flag = ''
        if spread < MIN_STDDEV:
            flag = '  <-- LOOKS BLANK'
            failed.append(f'{name} (stddev {spread:.1f})')
        # Crude duplicate detection: a downscaled luminance signature.
        with Image.open(out_path) as chk:
            sig = tuple(chk.convert('L').resize((16, 16)).getdata())
        dup_of = signatures.get(sig)
        if dup_of:
            flag += f'  <-- DUPLICATE of {dup_of}'
            failed.append(f'{name} (duplicate of {dup_of})')
        signatures[sig] = name

        size = os.path.getsize(out_path)
        print(f'{name:<26} stddev={spread:6.1f}  {size // 1024} KB{flag}')

    print()
    if failed:
        print('PROBLEMS:')
        for f in failed:
            print(' -', f)
        return 1
    print(f'OK — {len(shots)} screenshots written to {out_dir}/')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
