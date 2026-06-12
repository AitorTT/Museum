#!/usr/bin/env python3
"""Compress and resize images for itch.io size budget.

Overwrites originals with smaller JPEGs. Also downsizes images
whose longer edge exceeds MAX_PX to reduce Godot's S3TC VRAM usage.

Usage:
    python tools/compress_images.py [--dry-run] [--revert] [path ...]
"""

import os
import sys
import shutil
import argparse
from pathlib import Path
from PIL import Image

THRESHOLD_BYTES = 600 * 1024
MAX_PX = 1200  # downsize longer edge to this max
VALID_EXT = {".jpg", ".jpeg", ".png", ".bmp", ".tiff", ".webp"}
DEFAULT_DIRS = ["SCENES/PAINTINGS", "SCENES/SCULPTURE", "SCENES/KALEIDER"]


def _collect_files(paths: list[str]) -> list[Path]:
    files: list[Path] = []
    for entry in paths:
        p = Path(entry)
        if not p.exists():
            print(f"Warning: {p} does not exist", file=sys.stderr)
            continue
        if p.is_file():
            files.append(p)
        else:
            for root, _dirs, fnames in os.walk(p):
                for fn in fnames:
                    ext = Path(fn).suffix.lower()
                    if ext in VALID_EXT:
                        files.append(Path(root) / fn)
    return files


def _process_one(path: Path, *, force: bool = False) -> bool:
    """Compress and/or downsize path. Returns True if changed."""
    size = path.stat().st_size
    img = Image.open(path)
    w, h = img.size
    longest = max(w, h)
    needs_resize = longest > MAX_PX
    needs_compress = size >= THRESHOLD_BYTES

    if not needs_resize and not needs_compress and not force:
        return False

    # Backup original
    bak = path.with_suffix(path.suffix + ".bak")
    if not bak.exists():
        shutil.copy2(path, bak)

    # Downsize if needed
    if needs_resize:
        ratio = MAX_PX / longest
        new_w = int(w * ratio)
        new_h = int(h * ratio)
        img = img.resize((new_w, new_h), Image.LANCZOS)

    # Convert to RGB
    if img.mode in ("RGBA", "P"):
        img = img.convert("RGBA")
        bg = Image.new("RGB", img.size, (0, 0, 0))
        bg.paste(img, mask=img.split()[3])
        img = bg
    elif img.mode != "RGB":
        img = img.convert("RGB")

    # Save with quality that gets under threshold
    quality = 85
    img.save(path, "JPEG", quality=quality, optimize=True)
    compressed = path.stat().st_size

    while compressed > THRESHOLD_BYTES and quality > 15:
        quality -= 10
        img.save(path, "JPEG", quality=quality, optimize=True)
        compressed = path.stat().st_size

    old_kb = size / 1024
    new_kb = compressed / 1024
    dims = f" ({w}x{h} -> {img.width}x{img.height})" if needs_resize else ""
    ratio = (1 - compressed / size) * 100
    print(f"  {path.name}: {old_kb:.0f}KB -> {new_kb:.0f}KB ({ratio:.0f}% saved, q={quality}){dims}")
    return True


def _revert():
    count = 0
    for root, _dirs, fnames in os.walk("."):
        for fn in fnames:
            if fn.endswith(".bak"):
                bak = Path(root) / fn
                orig = bak.with_suffix("")
                if orig.exists():
                    orig.unlink()
                shutil.move(str(bak), str(orig))
                count += 1
    print(f"Restored {count} backup(s).")


def main():
    parser = argparse.ArgumentParser(description="Compress + resize images for itch.io")
    parser.add_argument("paths", nargs="*", help="Files or directories")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--revert", action="store_true")
    parser.add_argument("--force", action="store_true", help="Process all images even if under threshold")
    args = parser.parse_args()

    if args.revert:
        _revert()
        return

    raw = args.paths if args.paths else DEFAULT_DIRS
    files = _collect_files(raw)

    if not files:
        print("No image files found.")
        return

    count = 0
    for f in sorted(files):
        if args.dry_run:
            img = Image.open(f)
            longest = max(img.size)
            needs = img.size[0] * img.size[1] > THRESHOLD_BYTES or longest > MAX_PX
            if needs or args.force:
                print(f"  WOULD process: {f.name} ({img.size[0]}x{img.size[1]}, {f.stat().st_size/1024:.0f}KB)")
                count += 1
            img.close()
        else:
            if _process_one(f, force=args.force):
                count += 1

    print(f"\n{'Would process' if args.dry_run else 'Processed'} {count} file(s).")


if __name__ == "__main__":
    main()
