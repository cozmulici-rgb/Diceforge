# Recolor the ORIGINAL CC0 numeral textures (white digits on light-grey cells)
# into the gold-on-obsidian look WITHOUT moving any pixels, so the mesh UVs stay
# aligned (the previous hand-recolor repacked the net and broke alignment + the
# sum-to-7 layout). Reads from _backup_original_textures/, writes textures/.
#
# Mapping by luminance: grey cell -> obsidian, white (digit / outside) -> gold,
# with a smoothstep ramp for anti-aliased edges.
#
# Run: blender --background --python tools/recolor_numbers.py

import bpy, os
import numpy as np

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GAME_DIR = os.path.dirname(SCRIPT_DIR)
DICE_DIR = os.path.join(GAME_DIR, "assets", "dice")
SRC = os.path.join(DICE_DIR, "_backup_original_textures")
DST = os.path.join(DICE_DIR, "meshes_textured", "textures")

DICE = ["d4", "d6", "d8", "d10", "d12", "d20"]

OBSIDIAN = np.array([0.07, 0.07, 0.09], dtype=np.float32)
GOLD = np.array([0.80, 0.60, 0.16], dtype=np.float32)
EDGE0, EDGE1 = 0.85, 0.97   # raw-sRGB luminance ramp: grey cell(~0.8)->obsidian, white->gold


def _smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def main():
    for name in DICE:
        src = os.path.join(SRC, "%s_Numbers.png" % name)
        if not os.path.exists(src):
            print("SKIP", name); continue
        img = bpy.data.images.load(src, check_existing=False)
        # Non-Color: read/write the raw stored sRGB-encoded values so the obsidian
        # /gold constants land exactly as written (no gamma round-trip).
        img.colorspace_settings.name = "Non-Color"
        w, h = img.size
        buf = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(buf)
        px = buf.reshape(h, w, 4)
        rgb = px[:, :, :3]
        lum = rgb[:, :, 0] * 0.299 + rgb[:, :, 1] * 0.587 + rgb[:, :, 2] * 0.114
        t = _smoothstep(EDGE0, EDGE1, lum)[:, :, None]
        out = OBSIDIAN[None, None, :] * (1.0 - t) + GOLD[None, None, :] * t
        px[:, :, :3] = out
        # Original textures use alpha (cells ~25% opaque, bg transparent) which
        # would make the die see-through. Force fully opaque — we only want RGB.
        px[:, :, 3] = 1.0
        img.pixels.foreach_set(px.ravel())

        dst = os.path.join(DST, "%s_Numbers.png" % name)
        img.filepath_raw = dst
        img.file_format = "PNG"
        img.save()
        bpy.data.images.remove(img)
        print("RECOLOR %s -> %s (%dx%d)" % (name, dst, w, h))
    print("RECOLOR_DONE")


main()
