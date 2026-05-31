# Headless Blender pipeline for Diceforge dice assets.
#
# For each die it:
#   1. Imports the OpenGameArt CC0 Collada mesh (.dae) — geometry + UVs.
#   2. Joins sub-meshes, recenters origin to bbox center (fixes d4's pivot).
#   3. Normalizes scale so every die shares an identical bounding size.
#   4. BEVELS the edges (rounded corners that catch light), angle-limited, applied.
#   5. NORMAL map — two modes:
#        - BAKE (default): duplicates a dense high-poly, drives a UV
#          texture-displacement from the numeral mask so numerals are physically
#          INDENTED, then bakes a tangent-space normal map (Cycles, selected->
#          active with a cage) onto the low-poly. Real anti-aliased relief.
#        - --no-bake: cheap procedural normal from the mask gradient.
#   6. METALLIC-ROUGHNESS map: packed glTF layout (G=roughness, B=metallic) from
#      the gold-numeral mask — gold = polished metal, obsidian body = matte.
#   7. Builds Principled BSDF (Base Color + MetallicRoughness + Normal) and
#      exports a self-contained .glb (all maps embedded) to meshes_gltf/.
#
# Run headless:
#   blender --background --python tools/dice_assetprep.py -- [flags]
#
# Flags after `--`:
#   --target-size N     uniform max bounding dimension (default 1.25)
#   --bevel-width F     bevel width in object units (default 0.03; 0 disables)
#   --bevel-segments N  bevel segments (default 2)
#   --no-bake           use the cheap procedural normal instead of a high-poly bake
#   --bake-size N       baked normal map resolution (default 1024)
#   --bake-subdiv N     simple-subdivision levels for the high-poly (default 6)
#   --engrave-depth F   displacement depth of numerals, object units (default 0.02)
#   --cage-extrusion F  bake cage extrusion (default 0.05)
#   --blur-radius N     box-blur radius (px) applied to the height field (default 4)
#   --normal-strength F procedural-normal slope gain when --no-bake (default 4.0)
#   --gold-threshold F  luminance cutoff that marks gold numerals (default 0.5)
#   --gold-roughness F  roughness of gold numerals (default 0.25)
#   --body-roughness F  roughness of obsidian body (default 0.7)
#   --no-maps           skip all maps, use scalar metallic/roughness
#   --metallic F        scalar metallic when --no-maps (default 0.4)
#   --roughness F       scalar roughness when --no-maps (default 0.55)

import bpy
import sys
import os
import math
import tempfile
import numpy as np

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GAME_DIR = os.path.dirname(SCRIPT_DIR)
SRC_DIR = os.path.join(GAME_DIR, "assets", "dice", "meshes_textured")
TEX_DIR = os.path.join(SRC_DIR, "textures")
OUT_DIR = os.path.join(GAME_DIR, "assets", "dice", "meshes_gltf")
MAP_DIR = os.path.join(tempfile.gettempdir(), "diceforge_dice_maps")

DICE = ["d4", "d6", "d8", "d10", "d12", "d20"]


def _parse_args():
    argv = sys.argv
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    cfg = {
        "target_size": 1.25, "bevel_width": 0.03, "bevel_segments": 2,
        "no_bake": False, "bake_size": 1024, "bake_subdiv": 6,
        "engrave_depth": 0.02, "cage_extrusion": 0.05, "blur_radius": 4,
        "normal_strength": 4.0, "gold_threshold": 0.5,
        "gold_roughness": 0.25, "body_roughness": 0.7,
        "no_maps": False, "metallic": 0.4, "roughness": 0.55,
    }
    flag_floats = {"--target-size", "--bevel-width", "--engrave-depth",
                   "--cage-extrusion", "--normal-strength", "--gold-threshold",
                   "--gold-roughness", "--body-roughness", "--metallic", "--roughness"}
    flag_ints = {"--bevel-segments", "--bake-size", "--bake-subdiv", "--blur-radius"}
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--no-bake":
            cfg["no_bake"] = True; i += 1
        elif a == "--no-maps":
            cfg["no_maps"] = True; i += 1
        elif a in flag_floats:
            cfg[a[2:].replace("-", "_")] = float(args[i + 1]); i += 2
        elif a in flag_ints:
            cfg[a[2:].replace("-", "_")] = int(args[i + 1]); i += 2
        else:
            i += 1
    return cfg


def _clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images,
                  bpy.data.textures):
        for d in list(block):
            if d.users == 0:
                block.remove(d)


def _activate(obj, also=None):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    if also is not None:
        also.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _import_dae(path):
    before = set(bpy.data.objects)
    bpy.ops.wm.collada_import(filepath=path)
    return [o for o in bpy.data.objects if o not in before and o.type == "MESH"]


def _join_meshes(meshes):
    if not meshes:
        return None
    _activate(meshes[0])
    for m in meshes:
        m.select_set(True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def _recenter_and_normalize(obj, target_size):
    _activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    obj.location = (0.0, 0.0, 0.0)
    dims = obj.dimensions
    longest = max(dims.x, dims.y, dims.z)
    if longest > 1e-6:
        obj.scale = (target_size / longest,) * 3
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def _add_bevel(obj, width, segments):
    if width <= 0.0:
        return
    _activate(obj)
    bpy.ops.object.shade_smooth()
    mod = obj.modifiers.new(name="Bevel", type="BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(30.0)
    mod.harden_normals = True
    bpy.ops.object.modifier_apply(modifier=mod.name)


# ── Image helpers ───────────────────────────────────────────────────────────────

def _read_image_raw(path):
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    arr = buf.reshape(h, w, 4)[:, :, :3]
    bpy.data.images.remove(img)
    return h, w, arr


def _box_blur(a, r):
    if r <= 0:
        return a
    k = 2 * r + 1
    pad = np.pad(a, r, mode="edge")
    csum = np.cumsum(np.cumsum(pad, axis=0), axis=1)
    csum = np.pad(csum, ((1, 0), (1, 0)), mode="constant")
    h, w = a.shape
    out = (csum[k:k + h, k:k + w] - csum[0:h, k:k + w]
           - csum[k:k + h, 0:w] + csum[0:h, 0:w]) / float(k * k)
    return out


def _gold_mask(rgb, threshold):
    lum = rgb[:, :, 0] * 0.299 + rgb[:, :, 1] * 0.587 + rgb[:, :, 2] * 0.114
    return (lum > threshold).astype(np.float32)


def _new_image(name, h, w, rgb, non_color=True, float_buffer=False):
    img = bpy.data.images.new(name, width=w, height=h, alpha=False,
                              float_buffer=float_buffer)
    rgba = np.empty((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(rgb, 0.0, 1.0)
    rgba[:, :, 3] = 1.0
    img.pixels.foreach_set(rgba.ravel())
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def _save_image(img, fname):
    os.makedirs(MAP_DIR, exist_ok=True)
    path = os.path.join(MAP_DIR, fname)
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return path


# ── Metallic-roughness (always procedural) ──────────────────────────────────────

def _make_orm(tex_path, name, cfg):
    h, w, rgb = _read_image_raw(tex_path)
    gold = _gold_mask(rgb, cfg["gold_threshold"])
    rough = np.where(gold > 0.5, cfg["gold_roughness"], cfg["body_roughness"])
    metal = np.where(gold > 0.5, 1.0, 0.0)
    orm = np.stack([np.ones_like(gold), rough, metal], axis=-1)
    img = _new_image("%s_orm" % name, h, w, orm)
    path = _save_image(img, "%s_orm.png" % name)
    bpy.data.images.remove(img)
    return path


# ── Procedural normal (fallback) ────────────────────────────────────────────────

def _make_normal_procedural(tex_path, name, cfg):
    h, w, rgb = _read_image_raw(tex_path)
    gold = _box_blur(_gold_mask(rgb, cfg["gold_threshold"]), cfg["blur_radius"])
    gy, gx = np.gradient(gold)
    s = cfg["normal_strength"]
    nx, ny, nz = -gx * s, -gy * s, np.ones_like(gold)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx * inv, ny * inv, nz * inv], axis=-1) * 0.5 + 0.5
    img = _new_image("%s_normal" % name, h, w, normal)
    path = _save_image(img, "%s_normal.png" % name)
    bpy.data.images.remove(img)
    return path


# ── High-poly displacement + Cycles normal bake ─────────────────────────────────

def _build_height_image(tex_path, name, cfg):
    """In-memory height field datablock for the Displace modifier (numerals=high)."""
    h, w, rgb = _read_image_raw(tex_path)
    height = _box_blur(_gold_mask(rgb, cfg["gold_threshold"]), cfg["blur_radius"])
    himg = _new_image("%s_height" % name, h, w,
                      np.stack([height] * 3, axis=-1), float_buffer=True)
    return himg


def _bake_normal_highpoly(low, tex_path, name, cfg):
    uv_name = low.data.uv_layers.active.name if low.data.uv_layers.active else "UVMap"

    # High-poly duplicate: dense simple-subdivision so displacement has resolution.
    _activate(low)
    bpy.ops.object.duplicate()
    high = bpy.context.view_layer.objects.active
    high.name = "%s_high" % name

    sub = high.modifiers.new(name="Subsurf", type="SUBSURF")
    sub.subdivision_type = "SIMPLE"
    sub.levels = cfg["bake_subdiv"]
    sub.render_levels = cfg["bake_subdiv"]
    _activate(high)
    bpy.ops.object.modifier_apply(modifier=sub.name)

    himg = _build_height_image(tex_path, name, cfg)
    htex = bpy.data.textures.new("%s_disp" % name, type="IMAGE")
    htex.image = himg
    htex.extension = "EXTEND"
    disp = high.modifiers.new(name="Displace", type="DISPLACE")
    disp.texture = htex
    disp.texture_coords = "UV"
    disp.uv_layer = uv_name
    disp.mid_level = 0.0
    disp.strength = -cfg["engrave_depth"]   # negative -> numerals recess (engraved)
    _activate(high)
    bpy.ops.object.modifier_apply(modifier=disp.name)

    # Bake target image, assigned as the ACTIVE image node of the low-poly material.
    bs = cfg["bake_size"]
    bake_img = bpy.data.images.new("%s_normal" % name, width=bs, height=bs,
                                   alpha=False, float_buffer=False)
    bake_img.colorspace_settings.name = "Non-Color"

    if not low.data.materials:
        low.data.materials.append(bpy.data.materials.new("%s_mat" % name))
    mat = low.data.materials[0]
    mat.use_nodes = True
    nt = mat.node_tree
    bake_node = nt.nodes.new("ShaderNodeTexImage")
    bake_node.image = bake_img
    bake_node.location = (-900, -400)
    nt.nodes.active = bake_node

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = cfg["cage_extrusion"]
    scene.render.bake.margin = 16

    # selected = {high, low}; active = low (the bake receiver).
    _activate(low, also=high)
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")

    path = _save_image(bake_img, "%s_normal.png" % name)

    # Cleanup: remove the temp bake node, high-poly, displacement datablocks.
    nt.nodes.remove(bake_node)
    bpy.data.objects.remove(high, do_unlink=True)
    bpy.data.textures.remove(htex)
    bpy.data.images.remove(himg)
    bpy.data.images.remove(bake_img)
    return path


# ── Material assembly ────────────────────────────────────────────────────────────

def _make_material(name, base_tex, normal_path, orm_path, cfg):
    mat = bpy.data.materials.new(name="%s_mat" % name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial"); out.location = (600, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled"); bsdf.location = (200, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    if os.path.exists(base_tex):
        img = bpy.data.images.load(base_tex, check_existing=True)
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img; tex.location = (-400, 200)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

    if cfg["no_maps"]:
        bsdf.inputs["Metallic"].default_value = cfg["metallic"]
        bsdf.inputs["Roughness"].default_value = cfg["roughness"]
        return mat

    orm_img = bpy.data.images.load(orm_path, check_existing=True)
    orm_img.colorspace_settings.name = "Non-Color"
    orm_tex = nt.nodes.new("ShaderNodeTexImage")
    orm_tex.image = orm_img; orm_tex.location = (-400, -100)
    sep = nt.nodes.new("ShaderNodeSeparateColor"); sep.location = (-100, -100)
    nt.links.new(orm_tex.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])

    norm_img = bpy.data.images.load(normal_path, check_existing=True)
    norm_img.colorspace_settings.name = "Non-Color"
    norm_tex = nt.nodes.new("ShaderNodeTexImage")
    norm_tex.image = norm_img; norm_tex.location = (-400, -400)
    nmap = nt.nodes.new("ShaderNodeNormalMap"); nmap.location = (-100, -400)
    nt.links.new(norm_tex.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def _export_glb(obj, out_path):
    _activate(obj)
    bpy.ops.export_scene.gltf(
        filepath=out_path, export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True,
    )


def main():
    cfg = _parse_args()
    os.makedirs(OUT_DIR, exist_ok=True)
    print("=== Diceforge dice asset prep ===")
    print("cfg=%s" % cfg)

    summary = []
    for name in DICE:
        dae = os.path.join(SRC_DIR, "%s.dae" % name)
        tex = os.path.join(TEX_DIR, "%s_Numbers.png" % name)
        if not os.path.exists(dae):
            print("SKIP %s (no .dae)" % name); continue

        _clear_scene()
        obj = _join_meshes(_import_dae(dae))
        if obj is None:
            print("SKIP %s (no mesh)" % name); continue
        obj.name = name

        _recenter_and_normalize(obj, cfg["target_size"])
        _add_bevel(obj, cfg["bevel_width"], cfg["bevel_segments"])

        normal_path = orm_path = None
        mode = "scalar"
        if not cfg["no_maps"]:
            orm_path = _make_orm(tex, name, cfg)
            if cfg["no_bake"]:
                normal_path = _make_normal_procedural(tex, name, cfg)
                mode = "procedural"
            else:
                normal_path = _bake_normal_highpoly(obj, tex, name, cfg)
                mode = "baked"

        obj.data.materials.clear()
        obj.data.materials.append(_make_material(name, tex, normal_path, orm_path, cfg))

        out_path = os.path.join(OUT_DIR, "%s.glb" % name)
        _export_glb(obj, out_path)

        ok = os.path.exists(out_path)
        kb = (os.path.getsize(out_path) / 1024.0) if ok else 0.0
        polys = len(obj.data.polygons)
        summary.append((name, ok, polys, kb, mode))
        print("DONE %s -> %.1f KB polys=%d normal=%s" % (name, kb, polys, mode))

    print("\n=== SUMMARY ===")
    for s in summary:
        print("%-4s ok=%s polys=%d %.1fKB normal=%s" % (s[0], s[1], s[2], s[3], s[4]))
    print("PIPELINE_OK %d/%d" % (sum(1 for s in summary if s[1]), len(DICE)))


main()
