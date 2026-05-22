# Dice Tuner — Parallel Comparison Rows

**Date:** 2026-05-16
**Status:** Approved (design)
**Scope:** Debug/dev tooling only — no production runtime impact

## Purpose

When iterating on dice rendering (materials, lighting, decal labels, animation timing), it is currently impossible to see the `.glb` mesh path and the `MeshInstance3D` + `BoxMesh` fallback path side by side. Differences are spotted only by toggling files on/off and re-running.

This spec adds a side-by-side **visual debugging fixture** to the `test_dice_tuner` scene: two parallel rows of 4 dice each, animated in sync, rendered under identical conditions, differing only in their mesh source.

## Goals

- See both render paths simultaneously, animating in sync, under identical camera/lighting/material.
- Drive both rigs from the existing tuner controls with a single change per parameter.
- Avoid any change to the production combat scene's use of `DiceRollOverlay`.

## Non-Goals

- Per-rig independent tuning (would require a target selector UI — out of scope).
- Static "look at the meshes" reference (the user wants to debug under animation).
- Adding new render paths beyond the two that already exist.

## Architecture

Two independent `DiceRollOverlay` instances live inside the tuner scene. Each owns its own `SubViewportContainer`, `SubViewport`, `Camera3D`, lights, and `WorldEnvironment`. The tuner positions them by calling a new `set_strip_rect(rect: Rect2)` method on each — top half for the mesh rig, bottom half for the BoxMesh rig.

The BoxMesh rig sets a new `force_box_fallback: bool = true` flag, which makes `_load_visual()` skip the `.glb` lookup and always return a `MeshInstance3D` with a `BoxMesh`.

The tuner's `_do_roll()` and `_do_reroll()` fan their calls out to both overlays. All spinbox callbacks apply their value to both rigs (sync mode — Option α).

```
test_dice_tuner.tscn
└── TestDiceTuner (Control, script = test_dice_tuner.gd)
    ├── ColorRect (background)
    ├── DiceRollOverlay #1   ← mesh path (.glb)
    │   └── SubViewportContainer (top half of lower strip)
    │       └── SubViewport
    │           ├── Camera3D
    │           ├── DirectionalLight3D × 2
    │           ├── WorldEnvironment
    │           └── Node3D[] (4 dice — .glb-loaded)
    ├── DiceRollOverlay #2   ← BoxMesh path (force_box_fallback=true)
    │   └── SubViewportContainer (bottom half of lower strip)
    │       └── SubViewport
    │           ├── Camera3D
    │           ├── DirectionalLight3D × 2
    │           ├── WorldEnvironment
    │           └── Node3D[] (4 dice — MeshInstance3D + BoxMesh)
    └── PanelContainer (existing tuner UI)
```

## Components

### `DiceRollOverlay` (modified)

Two additions, both inert in production:

1. **`force_box_fallback: bool = false`**
   When `true`, `_load_visual(sides, body_id)` does not check `res://assets/dice/meshes/d{sides}.glb`. It always returns a freshly constructed `MeshInstance3D` whose `mesh` is a `BoxMesh` of size `Vector3(0.9, 0.9, 0.9)` (matching the current fallback code at `dice_roll_overlay.gd:286-291`), with the same `StandardMaterial3D` applied via `material_override`.

2. **`set_strip_rect(rect: Rect2)`**
   Repositions and resizes the overlay's viewport region. Sets `_vp_container.position = rect.position`, `_vp_container.size = rect.size`, and `_viewport.size = Vector2i(int(rect.size.x), int(rect.size.y))`. Safe to call after `_ready()`. Replaces the screen-bottom anchoring when invoked.

   The existing `resize_strip(new_height)` is left intact — it still works for the production single-rig case. `set_strip_rect()` is the more general primitive the tuner needs.

No other public surface changes. `start_roll()`, `trigger_reroll()`, `refresh_materials()`, `refresh_lighting()`, `camera`, `sun_light`, `fill_light`, `world_environment` keep their current signatures.

### `test_dice_tuner.gd` (rewritten layout, same UX shape)

- `_overlay_mesh: DiceRollOverlay` — default flags, occupies top half of strip area.
- `_overlay_box:  DiceRollOverlay` — `force_box_fallback = true`, occupies bottom half.
- A helper `_layout_strip(strip_h: float)` computes the two `Rect2`s and calls `set_strip_rect()` on each overlay.
- Tuner's `PanelContainer` anchor (currently anchored above the full-strip height) is updated to use the combined strip height.

Replace single-overlay callbacks with sync fan-out:

| Existing call                                  | New behavior                                              |
| ---------------------------------------------- | --------------------------------------------------------- |
| `_overlay.start_roll(MOCK_ROLLS)`              | both overlays receive `start_roll(MOCK_ROLLS)`            |
| `_overlay.trigger_reroll(die_id, value)`       | both overlays receive `trigger_reroll(die_id, value)`     |
| `_set_cam(mutate)` on `_overlay.camera`        | mutate runs on both `_overlay_mesh.camera` and `_overlay_box.camera` |
| `_overlay.set(prop, v)` + `refresh_materials()` | both overlays get the property set + `refresh_materials()` |
| `_overlay.set(prop, v)` + `refresh_lighting()`  | both overlays get the property set + `refresh_lighting()`  |
| `_overlay.resize_strip(v)`                     | tuner recomputes the two-half layout and calls `set_strip_rect()` on each |
| `_overlay.float_height = v` (etc., scene group) | both overlays receive the value                           |

The `roll_complete` signal: connect to `_overlay_mesh.roll_complete` only. Both rigs use the same animation timing, so they finish together; one connection is enough for the status label.

## Data Flow — Roll All

```
user clicks "Roll All"
  │
  └─► _do_roll()
        ├─► _overlay_mesh.start_roll(MOCK_ROLLS)
        │     └─► 4 dice instantiated via .glb load path
        │           └─► spin + float + decal label tween
        └─► _overlay_box.start_roll(MOCK_ROLLS)
              └─► 4 dice instantiated via BoxMesh fallback
                    └─► spin + float + decal label tween   (same animation params)
```

Both rigs animate independently but with identical timing, so the visual result is two synchronized rows.

## Layout Details

The current tuner reserves the bottom `strip_height` (default 530px) of the window for the overlay. With two rigs:

- Combined strip envelope = `strip_height` (unchanged default).
- Top rig: `Rect2(0, screen.y - strip_height,       screen.x, strip_height / 2)` — the mesh row.
- Bottom rig: `Rect2(0, screen.y - strip_height/2, screen.x, strip_height / 2)` — the BoxMesh row.
- Tuner panel anchor unchanged: it sits above `screen.y - strip_height`.

The `Strip H` spinbox changes the *combined* envelope; both rigs split it.

## Error Handling

- `set_strip_rect()` early-returns if `_vp_container` is null (defensive: `add_child()` triggers `_ready()` synchronously in Godot 4, so the tuner can call `set_strip_rect()` right after `add_child()` — the guard exists only for safety if call order changes).
- `force_box_fallback = true` with a missing material asset still works — `_make_dice_material()` falls back to a plain `StandardMaterial3D` when textures are absent.

## Testing

Manual visual verification — this is a debug fixture, not production logic:

1. Open `test_dice_tuner.tscn`. Two empty viewports stacked vertically; tuner panel above.
2. Click **Roll All**. Both rows animate in sync. Top row shows beveled .glb dice; bottom row shows uniform 0.9³ cubes. Decal labels appear on both.
3. Change **Light → Sun** in the tuner. Both rows brighten/dim identically.
4. Change **Camera → Pitch**. Both rows reorient identically (cameras stay in lockstep).
5. Click **Re-roll d2**. Both row's d2 cube re-animates with the same new value.
6. Change **Strip H**. The combined strip resizes; both halves grow/shrink proportionally.
7. Open the production combat scene and roll dice. Single full-width strip renders unchanged (no regression from new flags).

No automated tests added — the existing GUT suite covers data-level behavior (`test_dice_resolver.gd`, `test_dice_model.gd`); render-path comparison is inherently visual.

## Files Touched

- `game/scripts/combat/dice_roll_overlay.gd` — add `force_box_fallback`, add `set_strip_rect()`, branch in `_load_visual()`.
- `game/scripts/test_dice_tuner.gd` — instantiate two overlays, fan-out callbacks, two-half layout helper.
- `game/scenes/test_dice_tuner.tscn` — unchanged (the scene just attaches the script).

## Risks

- **Two viewports doubles render cost in the tuner.** Tuner is dev-only and runs on developer hardware — acceptable.
- **Decal projection at half-height viewports.** The decal logic in `_show_label()` (`dice_roll_overlay.gd:188-243`) uses world-space `die_visual_scale`, not viewport-space. Independent of viewport size, so should work unchanged.
- **`force_box_fallback` shadowed by future changes to `_load_visual`.** Low risk; the flag check is a single early-branch and is only set by the tuner.
