# Dice Tuner Parallel Comparison Rows — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two parallel rows of 4 dice each (mesh-loaded `.glb` row on top, `MeshInstance3D` + `BoxMesh` row on bottom) to the `test_dice_tuner` scene for side-by-side render-path debugging. Both rows animate in sync and are driven by identical tuner controls.

**Architecture:** Two independent `DiceRollOverlay` instances live inside the tuner. The overlay gains two debug-flavoured additions (`force_box_fallback` and `set_strip_rect()`) — both inert in production. The tuner fans out every Roll/Re-roll/spinbox change to both overlays so the only difference between rows is the mesh source.

**Tech Stack:** Godot 4.3 (GDScript), `SubViewport`/`Camera3D`/`DirectionalLight3D`/`MeshInstance3D`/`BoxMesh`, headless verify via `make verify` (Docker).

**Spec reference:** `docs/superpowers/specs/2026-05-16-dice-tuner-comparison-rows-design.md`

---

## File Structure

**Modified files:**

- `game/scripts/combat/dice_roll_overlay.gd` — adds one field (`force_box_fallback`) and one method (`set_strip_rect`), plus a one-branch tweak inside `_load_visual()`. Stays a single ~390-line file; responsibility unchanged: own a 3D dice rendering rig and animate it.
- `game/scripts/test_dice_tuner.gd` — replaces the single `_overlay` field with two overlay instances and rewires every callback to fan out. Responsibility unchanged: drive a debug UI for the overlay rig(s).

**Unchanged files:**

- `game/scenes/test_dice_tuner.tscn` — scene file is empty (just attaches the script). No edits needed.
- All production scenes that consume `DiceRollOverlay` (combat scene). The new flag defaults `false` and the new method is only called when the tuner explicitly invokes it.

---

## Task 1: Add overlay debug capabilities (`force_box_fallback` + `set_strip_rect`)

**Files:**
- Modify: `game/scripts/combat/dice_roll_overlay.gd`

- [ ] **Step 1: Add the `force_box_fallback` field**

Open `game/scripts/combat/dice_roll_overlay.gd`. Find the runtime-tuneable variables block at the top (lines 6–23). Append the new field at the end of that block, just before line 25's `var camera: Camera3D` declaration.

```gdscript
# Debug: when true, _load_visual() always returns a BoxMesh fallback,
# skipping the .glb mesh lookup. Used by test_dice_tuner for side-by-side
# render-path comparison. Leave false in production.
var force_box_fallback: bool = false
```

- [ ] **Step 2: Branch in `_load_visual()` for the new flag**

Find `_load_visual()` (currently at line 277). Replace the function body so the `.glb` lookup is skipped when `force_box_fallback` is true. The fallback construction code stays unchanged.

```gdscript
func _load_visual(sides: int, body_id: String = "") -> Node3D:
	var mat := _make_dice_material(body_id)
	if not force_box_fallback:
		var mesh_path := "res://assets/dice/meshes/d%d.glb" % sides
		if ResourceLoader.exists(mesh_path):
			var packed := load(mesh_path) as PackedScene
			if packed != null:
				var instance := packed.instantiate()
				_apply_material_recursive(instance, mat)
				return instance
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.9, 0.9)
	mi.mesh = bm
	mi.material_override = mat
	return mi
```

- [ ] **Step 3: Add `set_strip_rect()` method**

After the existing `resize_strip()` method (currently lines 366–371), append the new method. It positions both the `SubViewportContainer` and the inner `SubViewport` to a given `Rect2`.

```gdscript
func set_strip_rect(rect: Rect2) -> void:
	if _vp_container == null:
		return
	_vp_container.position = rect.position
	_vp_container.size = rect.size
	if _viewport != null:
		_viewport.size = Vector2i(int(rect.size.x), int(rect.size.y))
	strip_height = rect.size.y
```

The `strip_height` assignment keeps the field in sync so consumers reading it (e.g. the tuner panel anchor) see the right value.

- [ ] **Step 4: Run headless verify to catch parse errors**

Run from the repo root:

```bash
make verify
```

Expected output ends with `Running deterministic test harness` followed by GUT test runs. No GDScript parse errors anywhere in the log. If you see `Parse Error: ...` referencing `dice_roll_overlay.gd`, the step above has a typo — fix and re-run.

- [ ] **Step 5: Commit**

```bash
git add game/scripts/combat/dice_roll_overlay.gd
git commit -m "feat(combat): add force_box_fallback flag and set_strip_rect to DiceRollOverlay

Both additions are inert when unused: force_box_fallback defaults false,
set_strip_rect is only called by the test_dice_tuner. Lets the tuner host
two independent overlay instances for side-by-side render-path debugging."
```

---

## Task 2: Refactor tuner to host two overlays

**Files:**
- Modify: `game/scripts/test_dice_tuner.gd`

This task swaps the single `_overlay` field for two instances, wires up the Roll/Re-roll fan-out, and re-anchors the panel. Spinbox callbacks are NOT yet touched — that's Task 3, after the smoke check confirms the bones work.

- [ ] **Step 1: Replace overlay field declaration and instantiation**

Open `game/scripts/test_dice_tuner.gd`. Replace line 10 (`var _overlay`) with two fields:

```gdscript
var _overlay_mesh: DiceRollOverlay
var _overlay_box: DiceRollOverlay
```

In `_ready()`, replace the existing overlay instantiation block (lines 21–23) with:

```gdscript
	var overlay_script = load("res://scripts/combat/dice_roll_overlay.gd")
	_overlay_mesh = overlay_script.new()
	_overlay_box  = overlay_script.new()
	_overlay_box.force_box_fallback = true
	add_child(_overlay_mesh)
	add_child(_overlay_box)
	_layout_strip(_overlay_mesh.strip_height)
```

- [ ] **Step 2: Add the `_layout_strip()` helper**

Append this helper anywhere in the script (recommended: just above `_make_section()`, around line 109). It splits the strip envelope into top and bottom halves and pushes the rects to both overlays.

```gdscript
func _layout_strip(strip_h: float) -> void:
	var screen := get_viewport().get_visible_rect().size
	var half := strip_h / 2.0
	var top_y := screen.y - strip_h
	_overlay_mesh.set_strip_rect(Rect2(0.0, top_y,        screen.x, half))
	_overlay_box.set_strip_rect( Rect2(0.0, top_y + half, screen.x, half))
```

- [ ] **Step 3: Update the tuner panel anchor**

Find the `PanelContainer` setup block (currently lines 25–30). Replace the `SIDE_BOTTOM` line so it uses `_overlay_mesh.strip_height` instead of the removed `_overlay`:

```gdscript
	panel.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -(_overlay_mesh.strip_height + 8.0))
```

- [ ] **Step 4: Fan out roll/re-roll calls and the completion signal**

Replace `_do_roll()`, `_do_reroll()` and the `_overlay.roll_complete.connect(...)` line (currently lines 158–165 and 106) with the fan-out versions:

```gdscript
func _do_roll() -> void:
	_overlay_mesh.start_roll(MOCK_ROLLS)
	_overlay_box.start_roll(MOCK_ROLLS)
	_status("Rolling...")


func _do_reroll(die_id: String) -> void:
	var new_value := randi_range(1, 20)
	_overlay_mesh.trigger_reroll(die_id, new_value)
	_overlay_box.trigger_reroll(die_id, new_value)
	_status("Re-rolling %s..." % die_id)
```

For the signal connection (line 106), only connect to one overlay — they animate in sync, so one completion is the signal for both:

```gdscript
	_overlay_mesh.roll_complete.connect(func(): _status("Roll complete."))
```

Note the change to `_do_reroll`: the random value is now generated once and passed to both overlays so they show the same number.

- [ ] **Step 5: Headless verify (catch parse errors only — visual check comes next)**

```bash
make verify
```

Expected: no parse errors in `test_dice_tuner.gd`. The tuner scene itself isn't a startup scene, so a parse-clean import is all this confirms.

- [ ] **Step 6: Visual smoke check**

Open the Godot editor (either via `make gui`/the new `editor` Docker service, or natively) and run the `res://scenes/test_dice_tuner.tscn` scene directly (F6 with the scene focused).

Expected:
- Two empty rectangular regions stacked vertically in the bottom half of the window.
- Tuner panel sits above them.
- Click "Roll All". Four `.glb` dice appear in the top region and animate; four box cubes appear in the bottom region and animate in parallel. Decal labels land on both rows.
- Click "Re-roll d1". Both top and bottom d1 (leftmost die in each row) re-animate to the same new value.

If only one row appears, check that `_overlay_box.force_box_fallback = true` was set BEFORE `add_child(_overlay_box)` — Godot calls `_ready()` synchronously on `add_child`, and `_ready` calls `_build_scene()` which doesn't itself use the flag, but the flag must be set before any `start_roll`. (`_ready` doesn't roll anything, so order is actually fine; this is a debugging hint only.)

- [ ] **Step 7: Commit**

```bash
git add game/scripts/test_dice_tuner.gd
git commit -m "feat(combat): host two overlays in test_dice_tuner for render-path comparison

Adds a second DiceRollOverlay with force_box_fallback=true and lays both
rigs out as stacked top/bottom halves of the strip envelope. Roll All
and Re-roll fan out to both rigs with the same data so the only visible
difference is the mesh source."
```

---

## Task 3: Fan-out tuner spinbox callbacks to both overlays

**Files:**
- Modify: `game/scripts/test_dice_tuner.gd`

The tuner has five spinbox groups: Camera, Animation, Scene, Texture, Lighting. Each currently mutates `_overlay`. Update each to mutate both overlays.

- [ ] **Step 1: Update camera spinbox helper `_set_cam()`**

Find `_set_cam()` (currently lines 168–170). Replace with:

```gdscript
func _set_cam(mutate: Callable) -> void:
	if _overlay_mesh.camera != null:
		mutate.call(_overlay_mesh.camera)
	if _overlay_box.camera != null:
		mutate.call(_overlay_box.camera)
```

- [ ] **Step 2: Update material spinbox helper `_set_material()`**

Find `_set_material()` (currently lines 173–175). Replace with:

```gdscript
func _set_material(prop_name: String, value: float) -> void:
	_overlay_mesh.set(prop_name, value)
	_overlay_box.set(prop_name, value)
	_overlay_mesh.refresh_materials()
	_overlay_box.refresh_materials()
```

- [ ] **Step 3: Update lighting spinbox helper `_set_light()`**

Find `_set_light()` (currently lines 178–180). Replace with:

```gdscript
func _set_light(prop_name: String, value: float) -> void:
	_overlay_mesh.set(prop_name, value)
	_overlay_box.set(prop_name, value)
	_overlay_mesh.refresh_lighting()
	_overlay_box.refresh_lighting()
```

- [ ] **Step 4: Update Animation column callbacks**

Find the Animation column block (currently lines 73–78). Each spinbox callback currently writes to `_overlay`. Replace those five callbacks with versions that write to both. The order/labels/values stay identical — only the closures change.

```gdscript
	var anim_col := _make_section(cols, "Animation")
	_spin(anim_col, "Float H",   0.5, 10.0, 3.7,  0.1,  func(v):
		_overlay_mesh.float_height  = v
		_overlay_box.float_height   = v)
	_spin(anim_col, "Float Dur", 0.05, 2.0, 0.25, 0.05, func(v):
		_overlay_mesh.float_duration = v
		_overlay_box.float_duration  = v)
	_spin(anim_col, "Spin Dur",  0.05, 4.0, 0.3,  0.05, func(v):
		_overlay_mesh.spin_duration  = v
		_overlay_box.spin_duration   = v)
	_spin(anim_col, "Spin Rot",  0.5, 10.0, 5.5,  0.5,  func(v):
		_overlay_mesh.spin_rotations = v
		_overlay_box.spin_rotations  = v)
	_spin(anim_col, "Stagger",   0.0,  0.5, 0.08, 0.01, func(v):
		_overlay_mesh.stagger_delay  = v
		_overlay_box.stagger_delay   = v)
```

- [ ] **Step 5: Update Scene column callbacks (including Strip H)**

Find the Scene column block (currently lines 80–83). Replace with:

```gdscript
	var scene_col := _make_section(cols, "Scene")
	_spin(scene_col, "Die Scale",  1.0,  20.0,  6.0, 0.5,  func(v):
		_overlay_mesh.die_visual_scale = v
		_overlay_box.die_visual_scale  = v)
	_spin(scene_col, "Spacing",    0.5,   8.0,  2.0, 0.1,  func(v):
		_overlay_mesh.die_spacing      = v
		_overlay_box.die_spacing       = v)
	_spin(scene_col, "Strip H",   80.0, 800.0, 530.0, 10.0, func(v):
		_layout_strip(v))
```

The "Strip H" spinbox now drives `_layout_strip(v)` directly — no separate `resize_strip` call needed since `set_strip_rect()` covers what `resize_strip` did, and the helper does both halves at once.

- [ ] **Step 6: Headless verify**

```bash
make verify
```

Expected: clean import, no parse errors.

- [ ] **Step 7: Visual sync check**

Run `test_dice_tuner.tscn` again. Click "Roll All" so both rows have dice on screen. Then scrub the spinboxes one column at a time:

- **Camera → Pitch**: both rows reorient identically.
- **Camera → FOV**: both rows zoom together.
- **Animation → Spin Rot**: click Roll All; both rows spin the new count.
- **Scene → Die Scale**: next roll shows resized dice in both rows.
- **Scene → Strip H**: both rectangles shrink/grow proportionally (top half always half, bottom half always half).
- **Texture → Light**: next roll shows the lightness change on both rows.
- **Lighting → Sun**: both rows immediately brighten/dim.

If any spinbox affects only one row, re-check that you updated the closure in Step 4/5 to write both fields.

- [ ] **Step 8: Commit**

```bash
git add game/scripts/test_dice_tuner.gd
git commit -m "feat(combat): sync tuner spinboxes across both overlay rigs

Every Camera/Animation/Scene/Texture/Lighting spinbox now applies its
value to both _overlay_mesh and _overlay_box, so the two rows differ
only in mesh source. Strip H now drives the two-half layout helper
instead of the legacy single-strip resize call."
```

---

## Task 4: Production regression check

**Files:** none modified.

- [ ] **Step 1: Identify a production scene that uses `DiceRollOverlay`**

```bash
grep -rln "DiceRollOverlay\|dice_roll_overlay.gd" /Users/vcozmulici/workspace/ai/Diceforge/game --include="*.gd" --include="*.tscn" | grep -v "test_dice_tuner\|tests/"
```

Expected: at least one combat-related script or scene that loads or instantiates the overlay. Note which scene runs that script.

- [ ] **Step 2: Run that scene and trigger a real combat roll**

Open the editor and run the identified combat scene (or run the game from `app_root.tscn` and reach a combat encounter). Trigger a normal dice roll.

Expected:
- The combat overlay still renders as a single full-width strip at the bottom of the screen — not two stacked halves.
- The dice use the `.glb` meshes (not box cubes).
- Animation/labels/timing match the existing behaviour from before this branch's changes.

If the combat overlay now renders as two halves or shows BoxMesh cubes: somewhere in production code the new flags are being set. Search `force_box_fallback` and `set_strip_rect` outside the tuner to find the culprit — they should appear only in `dice_roll_overlay.gd` (definition) and `test_dice_tuner.gd` (caller).

- [ ] **Step 3: No commit (verification only)**

If anything regressed, fix the offending code before declaring the branch ready. If everything checks out, this task is complete and the feature is ready for review.

---

## Self-Review Notes (kept inline for reviewer context)

- **Spec coverage:**
  - Spec §2 (overlay `force_box_fallback`) → Task 1 Steps 1–2.
  - Spec §2 (overlay `set_strip_rect`) → Task 1 Step 3.
  - Spec §3 (two overlays, layout helper) → Task 2 Steps 1–3.
  - Spec §3 (fan-out roll/re-roll, signal) → Task 2 Step 4.
  - Spec §3 (spinbox sync — Camera/Material/Lighting/Animation/Scene) → Task 3 Steps 1–5.
  - Spec §4 (layout math, half-and-half) → Task 2 Step 2 + Task 3 Step 5.
  - Spec testing (manual visual) → Task 2 Step 6, Task 3 Step 7.
  - Spec risks (production regression) → Task 4.
- **Placeholder scan:** No TBDs, no "add appropriate X", no untested test stubs. Every code step shows the exact code.
- **Type/method consistency:** `force_box_fallback` and `set_strip_rect` are spelled identically in spec, Task 1, Task 2, and Task 4. `_overlay_mesh` and `_overlay_box` names used consistently across Tasks 2 and 3.
