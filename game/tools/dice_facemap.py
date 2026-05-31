# Extract, per die, each face's outward normal (in glTF Y-up space to match the
# exported .glb) and the UV centroid, plus a montage PNG of each face's numeral
# crop so the digit on each face can be read and mapped to its normal.
#
# Outputs (to %TEMP%/diceforge_facemap/):
#   <die>_faces.json   -> [{i, normal:[x,y,z], uv:[u,v]}...]  (normal in Y-up)
#   <die>_montage.png  -> grid of face numeral crops, row-major by face index i
#
# Run: blender --background --python tools/dice_facemap.py -- [--dice d6,d20]

import bpy, sys, os, json, tempfile
import numpy as np

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GAME_DIR = os.path.dirname(SCRIPT_DIR)
SRC_DIR = os.path.join(GAME_DIR, "assets", "dice", "meshes_textured")
TEX_DIR = os.path.join(SRC_DIR, "textures")
OUT = os.path.join(tempfile.gettempdir(), "diceforge_facemap")

ALL = ["d4", "d6", "d8", "d10", "d12", "d20"]


def _args():
    argv = sys.argv
    a = argv[argv.index("--") + 1:] if "--" in argv else []
    dice = ALL
    if "--dice" in a:
        dice = a[a.index("--dice") + 1].split(",")
    return dice


def _clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for blk in (bpy.data.meshes, bpy.data.images):
        for d in list(blk):
            if d.users == 0:
                blk.remove(d)


def _import(path):
    before = set(bpy.data.objects)
    bpy.ops.wm.collada_import(filepath=path)
    ms = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for m in ms:
        m.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    if len(ms) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def _read_tex(path):
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "sRGB"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    arr = buf.reshape(h, w, 4)[:, :, :3]
    bpy.data.images.remove(img)
    # Blender pixels are bottom-up; flip to top-down image rows.
    return np.flipud(arr), w, h


def main():
    os.makedirs(OUT, exist_ok=True)
    dice = _args()
    for name in dice:
        dae = os.path.join(SRC_DIR, "%s.dae" % name)
        tex = os.path.join(TEX_DIR, "%s_Numbers.png" % name)
        if not os.path.exists(dae):
            print("SKIP", name); continue
        _clear()
        obj = _import(dae)
        me = obj.data
        uv = me.uv_layers.active.data
        rgb, w, h = _read_tex(tex)

        # Group triangles by shared normal DIRECTION (dot > 0.99) so each die
        # FACE is one entry with its full UV region, regardless of how it was
        # triangulated. Direction clustering avoids the coordinate-rounding
        # over-split that gave d10 sixteen "faces".
        from mathutils import Vector as _V
        group_list = []  # each: {"n": Vector, "nx/ny/nz": sum, "us":[], "vs":[]}
        for poly in me.polygons:
            n = poly.normal.normalized()
            g = None
            for cand in group_list:
                if n.dot(cand["n"]) > 0.99:
                    g = cand; break
            if g is None:
                g = {"n": n, "nx": 0.0, "ny": 0.0, "nz": 0.0, "us": [], "vs": []}
                group_list.append(g)
            g["nx"] += n.x; g["ny"] += n.y; g["nz"] += n.z
            for li in poly.loop_indices:
                u, v = uv[li].uv
                g["us"].append(u); g["vs"].append(v)

        faces = []
        crops = []
        tile = 160
        for g in group_list:
            from mathutils import Vector as _V
            nn = _V((g["nx"], g["ny"], g["nz"])).normalized()
            # Blender Z-up -> glTF Y-up (export_yup): (x,y,z) -> (x, z, -y)
            ny_up = [round(nn.x, 4), round(nn.z, 4), round(-nn.y, 4)]
            us, vs = g["us"], g["vs"]
            cu, cv = float(np.mean(us)), float(np.mean(vs))
            faces.append({"i": len(faces), "normal": ny_up, "uv": [round(cu, 4), round(cv, 4)]})

            # crop a fixed window CENTERED on the UV centroid (digits are centered
            # in their face cell, so this reliably frames the numeral)
            hw = 0.11
            u0, u1 = max(cu - hw, 0.0), min(cu + hw, 1.0)
            v0, v1 = max(cv - hw, 0.0), min(cv + hw, 1.0)
            x0, x1 = int(u0 * (w - 1)), int(u1 * (w - 1))
            # image row 0 = top = v=1
            y0, y1 = int((1.0 - v1) * (h - 1)), int((1.0 - v0) * (h - 1))
            x0, x1 = min(x0, x1), max(x0, x1)
            y0, y1 = min(y0, y1), max(y0, y1)
            sub = rgb[y0:y1 + 1, x0:x1 + 1, :]
            if sub.size == 0:
                sub = np.zeros((4, 4, 3), dtype=np.float32)
            # nearest-resize to tile
            sy = np.linspace(0, sub.shape[0] - 1, tile).astype(int)
            sx = np.linspace(0, sub.shape[1] - 1, tile).astype(int)
            crops.append(sub[sy][:, sx])

        # montage grid, row-major by face index
        cols = int(np.ceil(np.sqrt(len(crops))))
        rows = int(np.ceil(len(crops) / cols))
        pad = 6
        mh = rows * (tile + pad) + pad
        mw = cols * (tile + pad) + pad
        mont = np.full((mh, mw, 3), 0.15, dtype=np.float32)
        for idx, c in enumerate(crops):
            r, cc = divmod(idx, cols)
            y = pad + r * (tile + pad)
            x = pad + cc * (tile + pad)
            mont[y:y + tile, x:x + tile, :] = c

        # save montage via a Blender image (sRGB)
        mimg = bpy.data.images.new("%s_mont" % name, width=mw, height=mh, alpha=False)
        rgba = np.empty((mh, mw, 4), dtype=np.float32)
        rgba[:, :, :3] = np.clip(np.flipud(mont), 0, 1)  # flip back to bottom-up for save
        rgba[:, :, 3] = 1.0
        mimg.pixels.foreach_set(rgba.ravel())
        mp = os.path.join(OUT, "%s_montage.png" % name)
        mimg.filepath_raw = mp; mimg.file_format = "PNG"; mimg.save()
        bpy.data.images.remove(mimg)

        with open(os.path.join(OUT, "%s_faces.json" % name), "w") as f:
            json.dump({"die": name, "cols": cols, "faces": faces}, f, indent=1)
        print("FACEMAP %s faces=%d cols=%d -> %s" % (name, len(faces), cols, mp))

    print("FACEMAP_DONE out=%s" % OUT)


main()
