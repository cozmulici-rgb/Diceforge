# Escape To Main Menu — Design

## 1. Problem

The game currently has no global "back out" key. Players who want to leave a screen mid-run must either complete the encounter or close the application. There is no mapping for `ui_cancel` (Escape) anywhere in `game/scripts/` or `game/project.godot`, and no screen controller intercepts it.

The fix is a global Escape handler that returns the player to the start menu from any in-run screen, with a confirmation step to prevent reflex losses, plus a quit confirmation when Escape is pressed on the start menu itself.

## 2. Goals

- Pressing Escape during a run (`exploration`, `combat`, `reward`, `forge`) opens a confirmation dialog. Confirming returns to the start menu via the existing `_show_start_menu()` flow.
- Pressing Escape on the start menu opens a "Quit Diceforge?" confirmation. Confirming calls `get_tree().quit()`.
- Pressing Escape on the progression (run-complete) screen returns to the start menu immediately, with no dialog. The run is already over and there is nothing to lose.
- Pressing Escape while a confirmation dialog is already open closes the dialog (Godot's built-in `ConfirmationDialog` behavior — no extra code).
- Cover the new behavior with deterministic tests in `game/tests/`.

## 3. Non-Goals

- A pause menu, settings panel, or any other Escape-driven UI beyond the two confirmations.
- Per-screen "back" navigation (e.g., reward → exploration). Escape always targets the start menu.
- Saving on Escape. The existing active-run persistence already saves on screen transitions; this design does not add a new save call. The dialog text reflects this honestly: "any unsaved progress in this screen may be lost."
- Onboarding hint UI ("Press Esc to return") in the HUD. Out of scope; can be added later if needed.
- Gamepad mapping changes. `ui_cancel` is Godot's default for Escape and the B button on a gamepad; we use the existing action and accept whatever bindings the engine provides by default.

## 4. Architecture

All changes are confined to two files:

- `game/scripts/app_root.gd` — adds screen-kind tracking, an `_unhandled_input` handler, and a lazy `ConfirmationDialog` helper.
- `game/tests/test_escape_to_main_menu.gd` (new) — covers the behavior matrix.

No changes to:

- Any screen controller (`start_menu_controller.gd`, `forge_screen_controller.gd`, `progression_screen_controller.gd`, `reward_screen_controller.gd`).
- Any scene file under `game/scenes/`. The dialog is created in code and added under the existing `HUD` `CanvasLayer`.
- `game/project.godot`. We rely on the engine's default `ui_cancel` action mapping.

### 4.1 Screen-kind tracking

`app_root.gd` already has six `_show_*` methods (lines 26, 46, 58, 69, 79, 95). Each one will set `_current_screen_kind` to one of:

```
"start_menu" | "exploration" | "combat" | "reward" | "forge" | "progression"
```

The field starts as `""` (no screen) and is set as the first line of each `_show_*` method. `_clear_screen_host()` does **not** reset it — the new screen will overwrite it before any input can fire.

### 4.2 Input handler

```
func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed("ui_cancel"):
        return
    if _confirm_dialog != null and _confirm_dialog.visible:
        return  # let the dialog's own Escape handler close it
    get_viewport().set_input_as_handled()
    _handle_escape()
```

`_unhandled_input` (rather than `_input`) lets any future screen consume Escape first if it ever needs to (e.g., closing a tooltip popup). Today no screen does, so the handler always fires.

### 4.3 Dispatch

```
func _handle_escape() -> void:
    match _current_screen_kind:
        "progression":
            _show_start_menu()
        "start_menu":
            _show_confirm("Quit Diceforge?", "", _on_quit_confirmed)
        "exploration", "combat", "reward", "forge":
            _show_confirm(
                "Return to main menu?",
                "Any unsaved progress in this screen may be lost.",
                _on_return_to_menu_confirmed
            )
        _:
            pass  # transient state, no screen mounted
```

### 4.4 Confirmation dialog helper

A single `ConfirmationDialog` instance is reused. It is added under `$HUD` (the existing `CanvasLayer`) so it overlays every screen. The helper rebinds the `confirmed` signal each time so the same dialog can serve both the quit-prompt and the return-to-menu prompt.

```
var _confirm_dialog: ConfirmationDialog = null
var _confirm_callback: Callable = Callable()

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

Using `ConfirmationDialog` (a built-in `AcceptDialog` subclass) gets us:

- Centered modal positioning via `popup_centered()`.
- OK / Cancel buttons with default focus on Cancel.
- Escape-closes-dialog and Enter-confirms behavior, free.

## 5. Behavior Matrix

| Current screen | Escape result |
|---|---|
| `start_menu` | "Quit Diceforge?" confirm → `get_tree().quit()` |
| `exploration` | "Return to main menu?" confirm → `_show_start_menu()` |
| `combat` | "Return to main menu?" confirm → `_show_start_menu()` |
| `reward` | "Return to main menu?" confirm → `_show_start_menu()` |
| `forge` | "Return to main menu?" confirm → `_show_start_menu()` |
| `progression` | `_show_start_menu()` immediately, no dialog |
| (dialog already open) | Dialog handles Escape, closes itself |

## 6. Testing

`game/tests/test_escape_to_main_menu.gd` covers:

1. Start menu + Escape → confirm dialog visible, title is "Quit Diceforge?".
2. Start menu + Escape + cancel → dialog hidden, still on start menu, no quit.
3. Exploration + Escape → confirm dialog visible.
4. Exploration + Escape + confirm → start menu visible, exploration screen freed.
5. Combat + Escape + confirm → start menu visible.
6. Reward + Escape + confirm → start menu visible.
7. Forge + Escape + confirm → start menu visible.
8. Progression + Escape → start menu visible immediately, no dialog instantiated (or dialog stays hidden).
9. Dialog open + Escape → dialog closes, screen unchanged, no second dialog stacked.

Tests instantiate the `app_root.tscn` scene under a test harness, drive screen state via the existing `_show_*` methods (calling them directly is acceptable for a test seam), synthesize `ui_cancel` via `Input.parse_input_event(...)` or by invoking `_unhandled_input` directly with a constructed `InputEventAction`. The repo's existing tests (e.g., `test_combat_controller.gd`) follow the direct-method-call style; we match that.

The `get_tree().quit()` path is asserted via a callable indirection: the quit handler is exposed as `_on_quit_confirmed` and the test stubs `_confirm_callback` to verify it would be called, without actually quitting the harness.

## 7. Risks

- **Dialog lifetime across screen swaps.** `_clear_screen_host()` only frees `screen_host` children. The dialog lives under `$HUD`, so it survives screen swaps — which is what we want, but it means we must hide it explicitly when returning to the start menu in case the user confirms while it's still showing. `popup_centered()` followed by the `confirmed` signal already hides it; no extra code needed.
- **Stacked input events.** If two Escape events fire in the same frame, the second is suppressed by the `_confirm_dialog.visible` guard.
- **Test harness and `get_tree().quit()`.** Calling `get_tree().quit()` inside a test would terminate the harness. The design routes the quit through `_on_quit_confirmed`, which the test can rebind or assert via the callback path before the actual quit fires.
