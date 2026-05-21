# Dice Roll Physics

This document describes the ballistic physics model used by `DiceRollOverlay` (`game/scripts/combat/dice_roll_overlay.gd`) to animate dice during the combat roll. The implementation favors physical plausibility over deterministic visuals — the rolled gameplay value is communicated via the digit label, not by forcing the mesh to land on the matching face.

## 1. Purpose

The overlay is a 3D dice tray rendered into a `SubViewport` strip at the bottom of the screen. When `start_roll(roll_data)` is called the dice are launched, tumble through the air, bounce, settle, and emit `roll_complete`. The motion is integrated per-frame in `_process(delta)` instead of being baked into a fixed tween chain, so the same simulation handles arbitrary `gravity`, `restitution`, and bounce counts without re-authoring the timeline.

## 2. Physics Model

The simulation treats each die as a point mass under gravity with a single conserved angular-momentum vector, plus a coefficient-of-restitution collision against a flat ground plane at `y = 0`.

### 2.1 Tunables

All exposed via the dice tuner (`res://scenes/test_dice_tuner.tscn`).

| Property            | Default | Role                                                                                                   |
|---------------------|---------|--------------------------------------------------------------------------------------------------------|
| `float_height`      | `3.7`   | Target apex of the initial throw, in world units.                                                      |
| `gravity`           | `120.0` | Downward acceleration in world units/s². Game gravity, not Earth's 9.8 — chosen for visual snappiness. |
| `spin_rotations`    | `5.5`   | Target turns the die completes during the first airborne arc (randomized ±30% per die).                |
| `stagger_delay`     | `0.08`  | Per-die start offset so dice launch in sequence rather than as a wall.                                 |
| `restitution`       | `0.55`  | Coefficient of restitution `e`. Vertical velocity after impact is `-e · vy_in`.                        |
| `angular_damping`   | `0.6`   | Fraction of angular speed retained per bounce.                                                         |
| `max_bounces`       | `4`     | Hard cap; the die settles even if it could mathematically bounce again.                                |
| `min_bounce_height` | `0.05`  | Predicted-next-apex floor (world units). Below this we settle instead of bouncing.                     |
| `settle_duration`   | `0.1`   | SLERP time from the chaotic basis at the final landing into a random face-up basis.                    |

### 2.2 Initial Conditions (`_kick_die`)

When a die's stagger countdown reaches zero:

- Initial upward velocity: `v0 = sqrt(2 · gravity · float_height)`. This is the closed-form kinematic solution that makes the die's apex equal `float_height` exactly (`v² = u² − 2gh`, with `v = 0` at apex).
- Angular-momentum axis: a uniformly random unit vector via the Marsaglia method (`_random_unit_vector`). Real rigid-body free-fall rotates around a single axis; previous versions used three independent Euler-axis tweens, which is non-physical.
- Angular speed: `spin = 2π · spin_rotations · randf(0.7, 1.3) / airtime` rad/s, where `airtime = 2·v0/gravity` (time-of-flight for the first arc). This produces roughly `spin_rotations` turns during the first arc, with per-die randomization so dice don't tumble in lockstep.
- Final landing basis: `_landing_rotation_for_entry` returns a uniformly random face-up orientation. The face that ends up on top is **not** correlated with `rolled_value` — visual outcome and gameplay outcome are intentionally decoupled.

### 2.3 Integration Loop (`_step_die`)

Each frame, for each active die:

```
vy   ← vy − gravity · delta
y    ← y + vy · delta
basis ← basis.rotated(axis, spin · delta)
```

The die's `Node3D.transform.basis` is replaced with the updated `basis`, and `position.y` is set from `y`.

### 2.4 Ground Contact

When `y ≤ 0` and `vy < 0`:

1. Compute the rebound velocity: `vy' = −vy · restitution`.
2. Compute the predicted next apex: `h' = vy'² / (2 · gravity)`.
3. If `bounce_index ≥ max_bounces` or `h' < min_bounce_height`, transition to settle (§2.5).
4. Otherwise, increment `bounce_index`, set `vy ← vy'`, and apply `spin ← spin · angular_damping`. The die immediately enters the next airborne arc.

Successive apex heights form a geometric sequence `float_height · e^(2n)`. With `e = 0.55`, bounce 1 ≈ 30%, bounce 2 ≈ 9%, bounce 3 ≈ 3% of the original height — the `min_bounce_height` test usually ends the chain around bounce 3 or 4.

### 2.5 Settle

The settle phase blends the chaotic in-flight basis into the chosen face-up basis so the die doesn't snap. Over `settle_duration`:

```
basis ← settle_from.slerp(final_basis, t)
```

with `t` clamped to `[0, 1]`. At `t = 1` the die is marked finished, `_show_label` is called (digit Decal for non-textured meshes), and the global pending counter decrements. When it reaches zero the overlay emits `roll_complete`.

## 3. Sources

The model is grounded in standard rigid-body physics literature and the following game-development references that inspired specific numeric choices:

- [Crafting a Dice Roller with Three.js and Cannon-es — Codrops](https://tympanus.net/codrops/2023/01/25/crafting-a-dice-roller-with-three-js-and-cannon-es/) — game gravity ≈ 50, restitution = 0.3, sleep-on-stable, random initial rotation, off-center impulse for natural angular velocity.
- [Rolling 3D dice with simulated physics in Unity — Funkyton](https://funkyton.com/rolling-virtual-dice-with-physics/) — tuning approach for Unity Rigidbody dice; emphasizes iterative material tuning over canonical values.
- [Help me achieve more realism with my dice? — Bullet Physics Forum](https://pybullet.org/Bullet/phpBB3/viewtopic.php?t=7901) — discussion of restitution, damping, and gravity scaling for 16 mm dice.
- [Coefficient of Restitution as a Fluctuating Quantity (arXiv:1104.0049)](https://arxiv.org/pdf/1104.0049) — confirms that `e` is velocity-dependent in reality; we approximate with a constant.
- [StaticHex/dicesim — GitHub](https://github.com/StaticHex/dicesim) — reference physics implementation including center-of-mass offset effects.

## 4. Trade-offs and Non-Goals

- **Determinism vs. realism.** The simulation is deliberately non-deterministic. The gameplay roll result (`rolled_value` from the combat engine) is conveyed through the digit Decal / textured face that is rendered separately. A previous iteration forced d6 dice to land on the matching face via a `_D6_FACE_UP_DIRS` table; that table now lives only in the runtime test (`game/tests/test_dice_roll_overlay_runtime.gd`) as an assertion helper.
- **Single-axis spin.** A real die thrown with both spin and torque-applying impacts will precess and change its angular-momentum direction. We do not model collision torque; the spin axis is fixed at launch and only its magnitude damps on impact. This is visually indistinguishable for the short duration the dice are in flight and avoids needing an inertia tensor.
- **Flat ground only.** Dice never collide with each other or with strip edges. They share a 1-D vertical phase space; their X positions come from `_spread_x` and stay constant.
- **No air drag.** `vy` only loses energy on impact, not during flight. With sub-second arcs this is imperceptible.

## 5. Where to Tune

- Live tuning: `docker compose up --build dice-tuner` → `http://localhost:6082/vnc.html`. The **Animation** column exposes Gravity, Spin Rot, Stagger, Restitut, Ang Damp, Max Bnce, and Settle.
- Code defaults: top of `game/scripts/combat/dice_roll_overlay.gd`, §2.1 of this document.
- Tests: `game/tests/test_dice_roll_overlay_runtime.gd` asserts that each landing places one cube face at world UP and that successive landings vary.
