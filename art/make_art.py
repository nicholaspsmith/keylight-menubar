#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Nicholas Smith

"""Build Lumen's (KeyLight's) menu-bar keycap from the Gemini edit of the mascot.

Input:  keycap-raw.png  (Gemini edit of source.png: hand and sun rays removed)
Output: ../Resources/bundle/lumen-keycap.png and @2x — a 22x22pt canvas with the
        keycap centred, KEYCAP_W points wide. The rays are drawn in code around it.
Needs Pillow + numpy.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "Resources" / "bundle"
CANVAS = 22        # points, square
KEYCAP_W = 12.0    # points


def cutout(img, tolerance=60):
    im = img.convert("RGBA")
    w, h = im.size
    for seed in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if im.getpixel(seed)[3] != 0:
            ImageDraw.floodfill(im, seed, (255, 255, 255, 0), thresh=tolerance)
    im.putalpha(im.getchannel("A").filter(ImageFilter.GaussianBlur(1.2)))
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cap = cutout(Image.open(HERE / "keycap-raw.png"))
    box = cap.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
    cap = cap.crop(box)
    print("keycap box", box, cap.size)
    for scale, suffix in ((1, ""), (2, "@2x")):
        W = CANVAS * scale
        w = round(KEYCAP_W * scale)
        h = round(cap.height * w / cap.width)
        small = cap.resize((w, h), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=0.6, percent=60, threshold=1))
        canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        canvas.paste(small, ((W - w) // 2, (W - h) // 2))
        canvas.save(OUT / f"lumen-keycap{suffix}.png", optimize=True)
        print(f"{suffix or '@1x'}: keycap {w}x{h}px at ({(W - w) // 2}, {(W - h) // 2})")


if __name__ == "__main__":
    main()
