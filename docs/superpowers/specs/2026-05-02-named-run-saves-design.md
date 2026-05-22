# Named Run Saves — Design

Date: 2026-05-02
Status: Approved (user confirmed 2026-05-02)

## Summary

Replace the current single-slot run save with a multi-slot system where each
"New Run" creates a separately-stored, auto-named save. Add a "Continue"
popup on the main menu that lists saves and lets the user resume, rename, or
delete each one. Daily Void retains its own per-day slot and is not part of
the named-save list. Saves are auto-deleted when their run ends (victory or
defeat).

## Goals

- Multiple in-progress standard runs can coexist on disk.
- Starting a new run never overwrites another in-progress run.
- The user can resume a specific run by name from a Continue popup.
- The user can rename or delete a save from the same popup.

## Non-Goals

- Run history / completed-run archive. Saves are removed when the run ends.
- Cross-device sync, cloud saves, or import/export of saves.
- Changes to Daily Void mode beyond giving it its own dedicated slot.
- A hard cap on the number of saves.
- Changes to meta progression storage (`meta_state.json` is unaffected).

## User-Facing Behavior

### New Run

- Clicking "New Run" creates a fresh save with a generated `slot_id` and an
  auto-generated `display_name` of the form
  `"<Archetype Name> · YYYY-MM-DD HH:MM"` (system local time).
- No modal is shown. The flow into exploration is unchanged from today.
- A previously in-progress run stays on disk untouched.

### Continue Popup

- The start menu's existing inline "Resume" strip is removed.
- A new "Continue" row in the main menu list opens a centered popup. The row
  is enabled only when at least one resumable save exists.
- The popup lists saves newest-first. Each row shows:
  - Display name
  - Archetype name
  - `Floor N · Room <id>`
  - Last-played relative time (e.g., "3 minutes ago")
- Each row has three actions:
  - **Resume** — closes the popup and starts the run from the saved state.
  - **Rename** — swaps the display-name label for an inline `LineEdit`;
    Enter commits, Escape cancels.
  - **Delete** — opens a small "Delete this save?" confirmation. On confirm,
    the file is removed and the popup refreshes.
- Corrupt saves render in an error tone and expose only a **Delete** action.
- Escape closes the popup. Closing returns focus to the start menu.

### Daily Void

- Daily Void is out of scope for the named-save list.
- Internally, daily runs persist to a dedicated slot id `daily_<YYYY_MM_DD>`
  rather than the previous shared slot.
- Starting a daily run does not affect any named save, and named saves do
  not appear under Daily Void's resume path.
- The Continue popup excludes any slot whose id starts with `daily_`.

### Run End

- On victory completion or defeat, the save for the active run is deleted —
  same semantics as today, just keyed by the run's own `slot_id` instead of
  a shared constant.

## Data Model

### Slot identity

- `slot_id` is stable, internal, and used as the JSON filename:
  `user://diceforge/runs/<slot_id>.json`.
- Generation: `run_<unix>_<archetype_id_short>` where `unix` is the creation
  time in seconds and `archetype_id_short` is the archetype id with `-`
  replaced by `_` and truncated to 16 characters. Collisions are avoided by
  appending an integer suffix if a file already exists.
- Daily Void uses `daily_<YYYY_MM_DD>` as before, formed from the calendar
  day.

### Run state additions

The dictionary persisted by `RunSession.to_dictionary()` gains two fields:

- `slot_id: String` — the slot id this save belongs to. Generated on
  `create_run_session` / `create_daily_void_session`. Required.
- `display_name: String` — user-visible label. Generated on creation, can
  be updated by Rename. Required and non-empty.

`SaveSchema.validate_run_state` is extended to require both fields and to
enforce `display_name` length 1..64 after trimming.

### Slot summary additions

`SaveSlotSummary` (used by `list_run_slots`) gains:

- `display_name: String` — copied from the file when available.

`PersistenceService.list_run_slots()` populates `display_name` from the
parsed payload, falling back to `slot_id` for legacy/corrupt files.

### Migration

- On first launch after this change, if a legacy save exists at slot id
  `active_run` and validates, it is loaded once, given a freshly generated
  `slot_id` and a default `display_name = "Recovered Run · <date>"`,
  re-persisted to the new slot, and the old `active_run.json` file is
  removed. This happens inside `GameStateCoordinator._init` after meta
  state load.
- Invalid legacy `active_run.json` is deleted as today (existing recovery
  message path).

## Components and Files

### Persistence layer (`game/scripts/persistence/`)

- `persistence_service.gd`
  - Generalize `delete_corrupt_run_state(slot_id)` into
    `delete_run_state(slot_id) -> Dictionary`. Keep a thin wrapper with the
    old name for any callers that have not been updated yet (will be removed
    once all call sites move).
  - `list_run_slots()` includes `display_name` in each summary.
- `save_schema.gd`
  - Add `slot_id` and `display_name` to validation.
- `save_slot_summary.gd`
  - Add `display_name` field.

### Core (`game/scripts/core/`)

- `run_session.gd`
  - Add `slot_id` and `display_name` properties; include in
    `to_dictionary()`; read in constructor with safe defaults.
- `game_state_coordinator.gd`
  - Remove `const ACTIVE_RUN_SLOT := "active_run"` usage as the resume
    target. The active save is referenced via `current_session.slot_id`.
  - `create_run_session(archetype_id)` generates a fresh slot id and
    display name before persisting.
  - `create_daily_void_session(archetype_id, calendar_day)` sets
    `slot_id = "daily_<calendar_day>"` and a daily-style display name.
  - New: `list_resumable_runs() -> Array[Dictionary]` — returns slots whose
    id does not start with `daily_` and that are not corrupt.
  - New: `rename_run(slot_id, new_name) -> Dictionary` — loads, updates
    `display_name` after trim/length check, persists. Returns `{ok: bool,
    error?, summary?}`.
  - New: `delete_run(slot_id) -> Dictionary` — wraps
    `persistence_service.delete_run_state`. Refuses to delete the
    `current_session.slot_id` if a run is in progress.
  - The internal cleanup helper currently named `_clear_active_run_slot()`
    is renamed to `_clear_current_run_slot()` and deletes by
    `current_session.slot_id` rather than the removed constant.
  - `_persist_current_session()` writes to `current_session.slot_id`.
  - One-shot legacy migration helper described above runs from `_init`.

### Start menu (`game/scripts/screens/start_menu_controller.gd` + `.tscn`)

- Remove the inline `ContinueStrip` resume button and its spacer (or keep
  the nodes but stop populating them — implementation chooses the cleanest
  removal).
- Add a "Continue" entry to `MENU_ITEMS` (id `"continue"`, hotkey `R` for
  "Resume" — `C` is taken by Credits). Enabled iff
  `_resumable_summaries.size() > 0`.
- New `signal continue_runs_requested()` — emitted when "Continue" is
  pressed; `app_root` responds by opening the dialog.
- `configure(...)` now takes `resumable_summaries: Array` instead of the
  single `continue_summary` dict; existing callers updated accordingly.
- The summary line stops including the per-run "Resume: floor N · room X"
  text (that information now lives in the popup).

### Continue popup (new)

- `game/scripts/screens/continue_runs_dialog.gd` — extends
  `AcceptDialog` (or `Window`); themed via `DiceforgeTheme`.
- Configured via `configure(summaries: Array)`.
- Emits:
  - `resume_requested(slot_id: String)`
  - `rename_requested(slot_id: String, new_name: String)`
  - `delete_requested(slot_id: String)`
- Handles its own list rebuild on configure; refreshed by the parent after
  any rename or delete.
- A scene file is optional; if a `.tscn` keeps boilerplate down, add
  `game/scenes/screens/continue_runs_dialog.tscn`. Otherwise build the
  layout in code consistent with `start_menu_controller.gd` style.

### App root (`game/scripts/app_root.gd`)

- Connect new start-menu signal `continue_runs_requested` to a handler that
  instantiates the popup, calls `configure(coordinator.list_resumable_runs())`,
  wires its three signals, and adds it as a child of `hud`.
- Resume → existing `_on_continue_requested(slot_id)` path; close popup.
- Rename → calls `coordinator.rename_run(...)`, refreshes popup contents
  via `configure` again.
- Delete → confirmation dialog, then `coordinator.delete_run(...)`, refresh.

## Error Handling and Edge Cases

- **Corrupt save in list**: surfaced as an error-tone row with only Delete.
  Same recovery path as today.
- **Disk write failure on rename**: rename surface returns `{ok: false}`;
  popup keeps the old name and shows an inline error message under the row.
  No partial state — the file is only updated on a successful write.
- **Delete of in-progress run**: refused at the coordinator boundary; the
  Continue popup never lists `current_session.slot_id` while a run is
  active anyway, so this is a defense-in-depth check.
- **Two runs created in the same second with the same archetype**: slot-id
  generation appends `_2`, `_3`, … until the filename is unique.
- **Legacy `active_run.json` migration fails validation**: existing
  recovery message path triggers; the file is deleted; the user sees the
  same "data was reset" toast as today.

## Testing

Add to `game/tests/` following the headless pattern used by neighboring
test scripts.

- **Persistence multi-slot test**
  - Write two distinct run states to two slot ids; assert both files exist
    and `list_run_slots()` returns both with the correct `display_name`.
  - Delete one slot; assert the other still loads cleanly.
- **Rename test**
  - Save a run; call a rename helper that updates `display_name`; reload
    and confirm the new name. Empty / over-length names are rejected.
- **Coordinator new-run isolation test**
  - Create a run for archetype A; capture its slot id. Create a second run
    for archetype B; assert the first slot still exists and contains
    archetype A's session.
- **Run-end auto-delete test**
  - Create a run, simulate `apply_encounter_result(defeat)`, assert the
    save file for that slot id is gone and any other saves are untouched.
- **Daily Void isolation test**
  - Create a named run; create a Daily Void session for today; assert the
    daily slot id starts with `daily_`, the named slot still exists, and
    `list_resumable_runs()` returns the named slot only.
- **Legacy migration test**
  - Seed a `runs/active_run.json` valid file; instantiate the coordinator;
    assert the file has been moved to a new generated slot id and the
    legacy file no longer exists. Invalid legacy file → deleted, no
    exception.

## Out of Scope (Reaffirmed)

- Run history / completed-run archive.
- Cloud sync.
- Daily Void list integration.
- Hard save cap.
- Renaming via a separate modal (kept inline in the popup).
