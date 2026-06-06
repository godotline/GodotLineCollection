# Async Level Loading with Loading Screen

**Date**: 2026-06-06
**Status**: Draft
**Author**: Claude (via brainstorming)

## Overview

Add an animated loading screen to the level loading flow in GodotLineCollection, providing visual feedback during PCK integrity verification, PCK loading, and scene loading phases. The loading screen consists of two distinct UI states that transition as loading progresses.

## Motivation

The current level loading flow freezes the main thread during:
1. PCK file MD5 integrity verification (reads entire file in 64KB chunks)
2. `ProjectSettings.load_resource_pack()` (synchronous Godot API)
3. Scene loading via `change_scene_to_file()` (synchronous scene loading)

Users see no visual feedback during these blocking operations, leading to a perception of the app being frozen or crashed.

## Design

### UI Components

Two distinct overlay UIs, both added as direct children of the `LevelManager` root `Control` node in `LevelManager.tscn`. Both are hidden by default.

#### VerificationUI (校验界面)

```
VerificationUI (ColorRect, #000000 @ 65% alpha)
  anchors_preset = FULL_RECT
  mouse_filter = MOUSE_FILTER_STOP    ← blocks clicks during loading
  
  └── CenterContainer
      anchors_preset = CENTER
      
      └── VBoxContainer
          theme/separation = 12
          
          ├── Spinner (Control, custom_minimum_size = 64×64)
          │   Custom _draw() rendering:
          │   - Circle outline: draw_arc(center, radius=28, 0, TAU, 32, white@30%, width=2)
          │   - Rotating dot: draw_circle(position on circumference, radius=4, white@90%)
          │   _process(delta): _angle += delta * 2.0 → queue_redraw()
          │
          └── Label ("正在校验关卡")
              font_size = 18
              font_color = white@90%
              horizontal_alignment = CENTER
```

- Spinner rotation speed: 2.0 rad/s (~3.1 seconds per full rotation)
- Shown at the very start of `_start_level()`, before any blocking work

#### LoadingUI (加载界面)

```
LoadingUI (ColorRect, #000000)
  anchors_preset = FULL_RECT
  mouse_filter = MOUSE_FILTER_STOP    ← blocks clicks during loading
  
  └── CoverTexture (TextureRect)
      layout_mode = 1
      anchors_preset = FULL_RECT
      expand_mode = EXPAND_IGNORE_SIZE
      stretch_mode = STRETCH_KEEP_ASPECT_COVERED
      
  └── NameLabel (Label)
      layout_mode = 1
      anchors_preset = BOTTOM_LEFT
      offset_left = 20
      offset_bottom = -20
      font_size = 22
      font_color = white@100%
```

- Covers the full screen with the level's cover art (from `MenuLevelData.cover`)
- Level name displayed at bottom-left
- No spinner needed — the cover art is visually interesting enough
- Fades out with a 0.5s alpha tween when loading completes

### Flow State Machine

```
[Idle] → [Verifying] → [Loading] → [Ready] → [Switched]
```

| State | Visible UI | Work Being Done |
|-------|-----------|-----------------|
| Idle | Normal LevelManager | Nothing |
| Verifying | VerificationUI (spinner + "正在校验关卡") | Background thread MD5 checksum |
| Loading | LoadingUI (cover + name) | `load_resource_pack()` + threaded scene load |
| Ready | Fade out LoadingUI (0.5s tween) | Scene ready to switch |
| Switched | (Game scene) | `change_scene_to_packed()` |

### Asynchronous MD5 Verification

The existing `_compute_file_md5()` is moved to a background `Thread` to avoid blocking the main thread.

```gdscript
var _verify_thread: Thread
var _verify_result: Dictionary = {}  # { "ok": bool, "md5": String }
var _verify_busy: bool = false

func _start_verify(pck_path: String, expected_md5: String) -> void:
    _verify_busy = true
    _verify_thread = Thread.new()
    _verify_thread.start(_verify_worker.bind(pck_path, expected_md5))

func _verify_worker(pck_path: String, expected_md5: String) -> Dictionary:
    var actual_md5 = _compute_file_md5(pck_path)  # same algorithm, now on BG thread
    var ok = expected_md5.is_empty() or actual_md5.to_lower() == expected_md5.to_lower()
    return { "ok": ok, "md5": actual_md5, "pck_path": pck_path }

func _poll_verify() -> void:
    if not _verify_busy:
        return
    if _verify_thread.is_alive():
        return  # still working, check next frame
    _verify_busy = false
    _verify_result = _verify_thread.wait_to_finish()
    _verify_thread = null
    # Continue loading flow based on result
```

Key safety rules:
- The worker thread only accesses `FileAccess` and `HashingContext` (thread-safe)
- `PCKDownloader.instance` and other non-thread-safe singletons are NOT accessed from the worker
- `expected_md5` is passed by value, not by reference to the singleton

### Async Scene Loading

After `load_resource_pack()` succeeds, use Godot 4's threaded resource loading:

```gdscript
ResourceLoader.load_threaded_request(scene_path)
# Poll in _process():
var progress = []
var status = ResourceLoader.load_threaded_get_status(scene_path, progress)
match status:
    ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        # Keep showing LoadingUI (progress[0] has 0-1 range)
        pass
    ResourceLoader.THREAD_LOAD_LOADED:
        var packed_scene = ResourceLoader.load_threaded_get(scene_path)
        _on_scene_ready(packed_scene)
    ResourceLoader.THREAD_LOAD_FAILED:
        info_label.text = "场景加载失败"
```

### Fade-Out Transition

When the scene is ready:

```gdscript
func _on_scene_ready(packed_scene: PackedScene) -> void:
    var tw = create_tween()
    tw.tween_property(_loading_ui, "modulate:a", 0.0, 0.5)
    tw.set_parallel()
    tw.tween_callback(func(): 
        _loading_ui.visible = false
        get_tree().change_scene_to_packed(packed_scene)
    ).set_delay(0.5)
```

### Integration with Existing Flows

#### Local PCK Flow
Previously: `_verify_and_load_pck()` → `_switch_to_scene()`  
Now:
1. Show VerificationUI, start background verify thread
2. On verify done: hide VerificationUI, show LoadingUI, `await process_frame`
3. `load_resource_pack()`, then `load_threaded_request(scene)`
4. Poll in `_process()`, fade out on ready

#### Remote Download + Cache Flow
Previously: Download → verify → `_on_download_completed()` → load → switch  
Now:
1. Show VerificationUI with "正在校验关卡" during post-download MD5 check
2. On verify done: hide VerificationUI, show LoadingUI, continue as local flow
3. Download progress (percentage) still shows via `info_label` or could be integrated into LoadingUI later

#### Import PCK Flow (FileDialog)
The import flow (`_on_pck_file_selected`) is an editor/manual action — it retains its current synchronous behavior for now.

### Thread Safety

| Operation | Thread Safety | Mechanism |
|-----------|--------------|-----------|
| `FileAccess.open/read` | Safe in Godot 4 | Called from worker thread |
| `HashingContext` | Safe in Godot 4 | Called from worker thread |
| `PCKDownloader.instance` | NOT safe | Pass values, not references |
| `ProjectSettings.load_resource_pack()` | Main thread only | Called after verify completes |
| `ResourceLoader.load_threaded_request()` | Safe | Godot manages internally |

### Error Handling

| Failure | Behavior |
|---------|----------|
| MD5 mismatch (has remote) | Hide VerificationUI, show "下载中..." on info_label, auto re-download |
| MD5 mismatch (no remote) | Hide VerificationUI, hide LoadingUI, show warning on info_label |
| PCK load failure | Hide LoadingUI, show "PCK加载失败" on info_label |
| Scene load failure | Hide LoadingUI, show "场景加载失败" on info_label |
| Thread creation failure | Fall back to synchronous verify (current behavior) |

## Files Changed

| File | Change |
|------|--------|
| `Scripts/ui/loading_spinner.gd` | **New** — `extends Control`, `_draw()` + `_process()` spinner animation |
| `Scenes/LevelManager.tscn` | Add VerificationUI nodes, LoadingUI nodes |
| `Scripts/LevelManager.gd` | Add verify-thread logic, async scene loading, UI state management, _process polling |

## Success Criteria

1. Clicking a level immediately shows VerificationUI with rotating spinner
2. After MD5 verify completes, LoadingUI replaces it with full-screen cover art
3. Spinner animation is smooth (no frame drops during verify)
4. LoadingUI cover + name visible throughout PCK load and scene load
5. LoadingUI fades out smoothly (0.5s) before the game scene appears
6. Error cases properly dismiss loading UI and show text feedback
7. No crashes or thread-safety violations across all loading paths
