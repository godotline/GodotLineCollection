# Implementation Plan: Async Level Loading with Loading Screen

## Summary

Add two loading overlay UIs (VerificationUI + LoadingUI) and async loading logic to LevelManager.

## Tasks

### Task 1: Loading Spinner Script
**File**: New `Scripts/ui/loading_spinner.gd`
**Description**: Custom `extends Control` that draws a rotating dot animation via `_draw()`. Used inside VerificationUI.
**Details**:
- `extends Control`
- `var _angle: float = 0.0` in `_ready()`, incremented by `delta * 2.0` in `_process(delta)`
- `_draw()`: draw_arc for circle outline (radius 28, white 30%, width 2), draw_circle for dot (radius 4, white 90%)
- `_process(delta)`: `_angle += delta * 2.0; queue_redraw()`
- `custom_minimum_size = Vector2(64, 64)`
- No signals needed (self-contained animation)

### Task 2: LevelManager.tscn UI Nodes
**File**: `Scenes/LevelManager.tscn`
**Description**: Add VerificationUI and LoadingUI node trees as children of the root `Control` node.
**Details**:

VerificationUI:
- Name: `VerificationUI`, type `ColorRect`, color black 65% alpha (`#000000A6`)
- anchors FULL_RECT, mouse_filter STOP
- Child: `CenterContainer` (CENTER anchor)
  - Child: `VBoxContainer` (separation 12)
    - Child: `Spinner` (type Control, `custom_minimum_size = 64x64`, script = `res://Scripts/ui/loading_spinner.gd`)
    - Child: `Label` ("正在校验关卡", font_size 18, white 90%)
- `visible = false`

LoadingUI:
- Name: `LoadingUI`, type `ColorRect`, color black 100% (`#000000`)
- anchors FULL_RECT, mouse_filter STOP
- Child: `CoverTexture` (type TextureRect, FULL_RECT, EXPAND_IGNORE_SIZE, STRETCH_KEEP_ASPECT_COVERED)
- Child: `NameLabel` (type Label, BOTTOM_LEFT anchor, offset_left 20, offset_bottom -20, font_size 22, white)
- `visible = false`

### Task 3: LevelManager.gd Async Loading Logic
**File**: `Scripts/LevelManager.gd`
**Description**: Add async MD5 verification via Thread, async scene loading via load_threaded_request, UI state management, and error handling.

**New @onready vars**:
- `@onready var _verification_ui: ColorRect = $VerificationUI`
- `@onready var _loading_ui: ColorRect = $LoadingUI`
- `@onready var _cover_texture: TextureRect = $LoadingUI/CoverTexture`
- `@onready var _level_name_label: Label = $LoadingUI/NameLabel`

**New member vars**:
- `var _verify_thread: Thread`
- `var _verify_busy: bool = false`
- `var _scene_loading: bool = false`
- `var _pending_scene_path: String = ""`
- `var _loading_data: MenuLevelData = null`

**New methods**:
- `_start_verify(pck_path, expected_md5, data)`: Create Thread, start `_verify_worker`
- `_verify_worker(pck_path, expected_md5)` (static): Compute MD5, return `{ok, md5, pck_path}`
- `_poll_verify()`: Check thread completion; on done, continue flow
- `_show_verification_ui(data)`: Show VerificationUI (for download flow, data may be null)
- `_show_loading_ui(data)`: Fill cover + name, show LoadingUI
- `_start_async_scene_load(scene_path)`: Call `ResourceLoader.load_threaded_request`, set `_scene_loading = true`
- `_poll_scene_load()`: Check `load_threaded_get_status`, on LOADED → fade + switch, on FAILED → error
- `_on_scene_ready(packed_scene)`: Tween fade out 0.5s → switch

**Modified methods**:
- `_process(delta)`: Add `_poll_verify()` and `_poll_scene_load()` calls (at end, after existing logic)
- `_start_level()`: Restructure to async flow (show VerificationUI → start verify → return)
- `_verify_and_load_pck()`: Call `_start_verify()` instead of inline verify
- `_on_download_completed()`: Call `_show_verification_ui` + `_start_verify()` instead of inline verify+load
- `_switch_to_scene()`: Replace with async version (show LoadingUI → load_resource_pack → async load)

**Error handling**:
- `_on_verify_failed(data)`: If has remote URL → hide UIs, trigger re-download; if no remote → show error on info_label
- `_cleanup_loading()`: Reset all loading state vars, hide UIs
- Thread error fallback: if `Thread.new()` fails, fall back to synchronous verify

**Loading flow (local PCK)**:
```
_start_level()
  → show VerificationUI, start background verify thread
  → _poll_verify() detects thread done
    → if ok: hide VerificationUI, show LoadingUI
      → await process_frame
      → load_resource_pack()
      → _start_async_scene_load(scene_path)
      → _poll_scene_load() detects loaded
        → tween fade out 0.5s
        → change_scene_to_packed(scene)
    → if failed: handle error
```

**Loading flow (download)**:
```
_on_download_completed()
  → show VerificationUI, start background verify (MD5 check of downloaded file)
  → _poll_verify() detects thread done
    → same as local flow from "hide VerificationUI, show LoadingUI" onward
```
