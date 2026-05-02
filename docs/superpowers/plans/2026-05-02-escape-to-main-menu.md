# Escape To Main Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Press Escape on any screen to return to the start menu (with a confirmation dialog mid-run, an instant return on the run-complete screen, and a quit-confirmation on the start menu).

**Architecture:** All changes live in `game/scripts/app_root.gd`. A new `_current_screen_kind` field is set as the first line of each `_show_*` method. A pure `_dispatch_escape_for_screen(kind)` function maps the screen kind to a behavior token; `_unhandled_input` calls it and acts on the token. A reusable Godot `ConfirmationDialog`, parented to the existing `HUD` `CanvasLayer`, handles both prompts. The pure dispatch function is unit-tested headlessly; the dialog and input wiring are verified by running the game.

**Tech Stack:** Godot 4.3-stable, GDScript, the project's existing `tests/test_runner.gd` headless harness (run via `make test` or `godot --headless --path game -s res://tests/test_runner.gd`).

**Spec:** [`docs/superpowers/specs/2026-05-02-escape-to-main-menu-design.md`](../specs/2026-05-02-escape-to-main-menu-design.md)

---

## File Structure

- **Modify** `game/scripts/app_root.gd` — add `_current_screen_kind`, `_confirm_dialog`, `_confirm_callback` fields; add `_unhandled_input`, `_handle_escape`, `_dispatch_escape_for_screen`, `_show_confirm`, `_on_confirm_dialog_confirmed`, `_on_quit_confirmed`, `_on_return_to_menu_confirmed` methods; set `_current_screen_kind` in each existing `_show_*` method.
- **Create** `game/tests/test_escape_to_main_menu.gd` — headless unit test of `_dispatch_escape_for_screen`.
- **Modify** `game/tests/test_runner.gd` — register the new test path in `TEST_SCRIPT_PATHS`.

No scene file changes. No `project.godot` changes (we rely on Godot's default `ui_cancel` mapping).

---

## Task 1: TDD the pure escape-dispatch function

**Files:**
- Create: `game/tests/test_escape_to_main_menu.gd`
- Modify: `game/tests/test_runner.gd:5-26` (the `TEST_SCRIPT_PATHS` array)
- Modify: `game/scripts/app_root.gd:14-16` (field declarations) and end-of-file (new method)

- [ ] **Step 1: Write the failing test**

Create `game/tests/test_escape_to_main_menu.gd`:

```gdscript
extends RefCounted

const AppRootScript = preload("res://scripts/app_root.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var app_root = AppRootScript.new()

	var cases := {
		"start_menu": "show_quit_confirm",
		"exploration": "show_return_confirm",
		"combat": "show_return_confirm",
		"reward": "show_return_confirm",
		"forge": "show_return_confirm",
		"progression": "return_to_menu",
		"": "noop",
		"unknown_screen": "noop",
	}

	for kind in cases.keys():
		var expected: String = cases[kind]
		var actual: String = app_root._dispatch_escape_for_screen(kind)
		if actual != expected:
			failures.append(
				"_dispatch_escape_for_screen(\"%s\") expected \"%s\" but got \"%s\""
					% [kind, expected, actual]
			)

	app_root.free()
	return failures
```

- [ ] **Step 2: Register the new test in the test runner**

Edit `game/tests/test_runner.gd`. In the `TEST_SCRIPT_PATHS` array (lines 5-26), add the new path. Insert it after `test_effect_resolver.gd` (line 11):

```gdscript
const TEST_SCRIPT_PATHS := [
	"res://tests/test_clamping.gd",
	"res://tests/test_battle_log.gd",
	"res://tests/test_hook_dispatcher.gd",
	"res://tests/test_status_engine.gd",
	"res://tests/test_dice_resolver.gd",
	"res://tests/test_effect_resolver.gd",
	"res://tests/test_escape_to_main_menu.gd",
	"res://tests/test_enemy_ai.gd",
	# ... rest unchanged
```

- [ ] **Step 3: Run tests to verify the new one fails**

Run:
```bash
make test
```

(Or, if Godot is installed locally: `godot --headless --path game -s res://tests/test_runner.gd`.)

Expected: the run logs `FAIL test_escape_to_main_menu: ...` for each case, because `_dispatch_escape_for_screen` does not yet exist on `AppRootScript`. All other tests should still pass.

- [ ] **Step 4: Add the field and the pure dispatch function**

Edit `game/scripts/app_root.gd`. After the existing `var content_catalog` and `var game_state_coordinator` declarations (near line 16), add:

```gdscript
var _current_screen_kind: String = ""
```

At the end of the file, add:

```gdscript
func _dispatch_escape_for_screen(screen_kind: String) -> String:
	match screen_kind:
		"progression":
			return "return_to_menu"
		"start_menu":
			return "show_quit_confirm"
		"exploration", "combat", "reward", "forge":
			return "show_return_confirm"
		_:
			return "noop"
```

- [ ] **Step 5: Run tests to verify the new one passes**

Run:
```bash
make test
```

Expected: `PASS test_escape_to_main_menu` and the existing test count is otherwise unchanged.

- [ ] **Step 6: Commit**

```bash
git add game/scripts/app_root.gd game/tests/test_escape_to_main_menu.gd game/tests/test_runner.gd
git commit -m "$(cat <<'EOF'
feat(app-root): add pure escape-dispatch function

Maps the active screen kind to one of "show_quit_confirm",
"show_return_confirm", "return_to_menu", or "noop". Wiring to
input events and the confirmation dialog comes in the next commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Wire screen-kind tracking, the input handler, and the dialog

**Files:**
- Modify: `game/scripts/app_root.gd` — set `_current_screen_kind` in each `_show_*` method, add `_unhandled_input`, `_show_confirm`, the two confirm callbacks, the dialog fields.

- [ ] **Step 1: Set `_current_screen_kind` in each `_show_*` method**

Edit `game/scripts/app_root.gd`. Add a `_current_screen_kind = "..."` line as the first statement inside each method:

- `_show_start_menu()` (line 26): `_current_screen_kind = "start_menu"`
- `_show_exploration()` (line 46): `_current_screen_kind = "exploration"`
- `_show_combat()` (line 58): `_current_screen_kind = "combat"`
- `_show_reward_flow()` (line 69): `_current_screen_kind = "reward"`
- `_show_forge_flow()` (line 79): set `_current_screen_kind = "forge"` after the early-return guard at lines 81-84 (do not set the kind if the forge flow is skipped).
- `_show_run_complete()` (line 95): `_current_screen_kind = "progression"`

For example, the start of `_show_start_menu()` becomes:

```gdscript
func _show_start_menu() -> void:
	_current_screen_kind = "start_menu"
	_clear_screen_host()
	hud.clear()

	var start_menu = StartMenuScene.instantiate()
	# ... rest unchanged
```

- [ ] **Step 2: Add the dialog state fields**

Edit `game/scripts/app_root.gd`. Below the existing `var _current_screen_kind` declaration added in Task 1, add:

```gdscript
var _confirm_dialog: ConfirmationDialog = null
var _confirm_callback: Callable = Callable()
```

- [ ] **Step 3: Add the input handler and helpers**

Edit `game/scripts/app_root.gd`. At the end of the file (after `_dispatch_escape_for_screen`), add:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _confirm_dialog != null and _confirm_dialog.visible:
		return  # let the dialog's own Escape handler close it
	get_viewport().set_input_as_handled()
	_handle_escape()


func _handle_escape() -> void:
	match _dispatch_escape_for_screen(_current_screen_kind):
		"return_to_menu":
			_show_start_menu()
		"show_quit_confirm":
			_show_confirm("Quit Facetbound?", "", _on_quit_confirmed)
		"show_return_confirm":
			_show_confirm(
				"Return to main menu?",
				"Any unsaved progress in this screen may be lost.",
				_on_return_to_menu_confirmed
			)
		"noop":
			pass


func _show_confirm(title: String, body: String, callback: Callable) -> void:
	if _confirm_dialog == null:
		_confirm_dialog = ConfirmationDialog.new()
		hud.add_child(_confirm_dialog)
		_confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	_confirm_dialog.title = title
	_confirm_dialog.dialog_text = body
	_confirm_callback = callback
	_confirm_dialog.popup_centered()


func _on_confirm_dialog_confirmed() -> void:
	var cb := _confirm_callback
	_confirm_callback = Callable()
	if cb.is_valid():
		cb.call()


func _on_quit_confirmed() -> void:
	get_tree().quit()


func _on_return_to_menu_confirmed() -> void:
	_show_start_menu()
```

- [ ] **Step 4: Run the full test suite**

Run:
```bash
make test
```

Expected: all tests still pass, including `test_escape_to_main_menu`. No regressions.

- [ ] **Step 5: Run headless validation**

Run:
```bash
make verify
```

Expected: passes with no parse or runtime errors. This catches any GDScript syntax problems in `app_root.gd`.

- [ ] **Step 6: Commit**

```bash
git add game/scripts/app_root.gd
git commit -m "$(cat <<'EOF'
feat(app-root): press Escape to return to main menu

Wires Godot's ui_cancel action through a global handler in
app_root. Confirms before leaving an in-run screen, confirms
before quitting from the start menu, and returns instantly from
the post-run progression screen.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Manual verification

This task has no code changes. It documents the manual play-tests that the unit test cannot cover (dialog rendering, input event delivery, the actual quit call).

**Files:** none

- [ ] **Step 1: Build and launch the game in the browser-viewable Docker session**

Run:
```bash
make gui
```

Then open `http://localhost:6080/vnc.html` in a browser.

- [ ] **Step 2: Verify Escape on the start menu**

1. Wait for the start menu to render.
2. Press Escape.
3. Expected: a "Quit Facetbound?" confirmation dialog appears.
4. Click Cancel. Expected: dialog closes, still on the start menu.
5. Press Escape again. Expected: same dialog reappears.
6. Click OK. Expected: the game window closes.

- [ ] **Step 3: Verify Escape during exploration**

1. Restart the game (`make gui` again if needed).
2. Start a new run from the archetype menu.
3. Wait for the exploration screen.
4. Press Escape.
5. Expected: "Return to main menu?" dialog with the body "Any unsaved progress in this screen may be lost."
6. Click Cancel. Expected: dialog closes, exploration screen still visible.
7. Press Escape again, then click OK. Expected: returns to the start menu, and the "Continue" option reflects the saved active run.

- [ ] **Step 4: Verify Escape during combat, reward, and forge**

For each of the three screens (combat, reward, forge), reach the screen via normal play, press Escape, confirm the same return-to-menu dialog appears, and confirm OK returns to the start menu. (Reward and forge screens require winning a combat encounter.)

- [ ] **Step 5: Verify Escape on the progression (run-complete) screen**

1. Finish a run (or fail one) so the progression summary screen renders.
2. Press Escape.
3. Expected: returns to the start menu immediately. No dialog.

- [ ] **Step 6: Verify the dialog itself swallows Escape**

1. Reach any in-run screen.
2. Press Escape to open the dialog.
3. Press Escape again while the dialog is open.
4. Expected: the dialog closes, and the screen behind it is unchanged. (Godot's `ConfirmationDialog` cancels on Escape; our handler ignores Escape while the dialog is visible.)

- [ ] **Step 7: Document the result**

If any step above fails, file the symptom in the next commit message or open an issue. If everything passes, no commit is needed for this task — the manual verification is logged here in the plan.
