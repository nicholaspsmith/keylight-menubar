# Menu-bar art

The menu-bar icon (Lumen) is the illustrated keycap shrunk to 12pt inside a 22x22pt
canvas (1x + @2x in `../Resources/bundle/lumen-keycap*.png`). The sun rays are
not in the art: StatusItemKit's `CharacterIcon.lumen(keycap:level:active:)` draws
eight of them in code, lit with the backlight level, and greys the keycap when
the backlight is off or KeyLight is inactive.

| File | What it is |
|---|---|
| `source.png` | The original illustration (Gemini, `gemini-2.5-flash-image`). |
| `keycap-raw.png` | Gemini edit of `source.png` with the thumbs-up hand and the sun rays removed. |
| `make_art.py` | Cuts out the background, crops the keycap tight and writes the 1x/@2x canvas PNGs. |
| `gemini_edit.py` | The image-edit call (`gemini-2.5-flash-image`; key from the site repo's untracked `.env`). |

Rebuild: `python3 art/make_art.py` (needs Pillow), then `scripts/build-app.sh`. The app icon
and `docs/mascot.png` are this same keycap and rays, redrawn at icon size from `keycap-raw.png`
by the Menumon site's `art/glyphs/app-icons.sh keylight`.
The edit was made with:

```
python3 art/gemini_edit.py art/source.png art/keycap-raw.png "Edit this image: remove the thumbs-up hand and arm completely, and remove all the sun rays around the keycap. Keep only the same yellow keycap character with its sunglasses, eyes, eyebrows and smile, exactly the same style and colours, centered on a plain white background. Where the hand was, the keycap's edge and face continue normally."
```
