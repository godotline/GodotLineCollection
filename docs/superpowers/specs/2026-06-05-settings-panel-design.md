# Settings Panel Design

## Overview

Replace the inline "源" button (which creates a dynamic `AcceptDialog` for download source selection) with a standalone settings scene (`SettingsPanel.tscn`) that opens as a modal overlay. The button text changes from "源" to "设置".

## Layout

```
┌──────────────────────────────────────┐
│  ← 返回     设置     🔧 💾 🎨       │  ← TitleBar (fixed)
├──────────────────────────────────────┤
│                                      │
│  ┌─ 下载源 ───────────────────────┐  │
│  │  ○ 源A                         │  │
│  │  ○ 源B                         │  │
│  │  ○ 源C                         │  │
│  └─────────────────────────────────┘  │
│                                       │
│  ┌─ 缓存管理 ─────────────────────┐  │
│  │  缓存大小: 256 MB              │  │
│  │  关卡数量: 12 个               │  │
│  │  [清除缓存]                    │  │
│  └─────────────────────────────────┘  │
│                                       │
│  ┌─ 显示设置 ─────────────────────┐  │
│  │  默认视图: [卡片 ▼]            │  │
│  │  音乐预览: [开启]              │  │
│  └─────────────────────────────────┘  │
│                                       │
└──────────────────────────────────────┘
```

## Scene Tree

```
SettingsPanel (Control)  — full-screen overlay, anchors FULL_RECT
  ├── BG (ColorRect)  — semi-transparent black (#000 60%), mouse_filter=IGNORE
  └── PanelContainer (居中, 固定宽 520, 最大高 620)
      ├── TitleBar (HBoxContainer, fixed height 44px)
      │   ├── BackBtn (Button, "← 返回")
      │   ├── Spacer (Control, size_flags_horizontal=3)
      │   ├── TitleLabel (Label, "设置", font_size=18)
      │   ├── Spacer (Control, size_flags_horizontal=3)
      │   └── NavIcons (HBoxContainer)
      │       ├── SourceIconBtn (Button, icon/emoji, tooltip="下载源")
      │       ├── CacheIconBtn (Button, icon/emoji, tooltip="缓存管理")
      │       └── DisplayIconBtn (Button, icon/emoji, tooltip="显示设置")
      └── ScrollContainer
          └── ContentVBox (VBoxContainer)
              ├── SourceSection (VBoxContainer)
              │   ├── SectionHeader (Label, "下载源", font_size=16)
              │   └── SourceList (VBoxContainer) — populated at runtime
              ├── HSeparator
              ├── CacheSection (VBoxContainer)
              │   ├── SectionHeader (Label, "缓存管理", font_size=16)
              │   ├── CacheSizeLabel (Label, "缓存大小: —")
              │   ├── CacheCountLabel (Label, "关卡数量: —")
              │   └── ClearCacheBtn (Button, "清除缓存")
              ├── HSeparator
              └── DisplaySection (VBoxContainer)
                  ├── SectionHeader (Label, "显示设置", font_size=16)
                  ├── DefaultViewRow (HBoxContainer)
                  │   ├── Label ("默认视图")
                  │   └── ViewOption (OptionButton) — "卡片视图" / "列表视图"
                  └── MusicPreviewRow (HBoxContainer)
                      ├── Label ("音乐预览")
                      └── MusicToggle (CheckButton)
```

## Script: Scripts/ui/settings_panel.gd

```gdscript
class_name SettingsPanel extends Control

signal source_changed(index: int)
signal settings_closed()

# ... implementation
```

### Key Methods

| Method | Description |
|--------|-------------|
| `_ready()` | Populate source list, scan cache, load saved display settings |
| `_on_back_pressed()` | Emit `settings_closed()`, `queue_free()` |
| `_scroll_to_section(section: Control)` | Animate `ScrollContainer.scroll_vertical` to the section's y position |
| `_populate_sources()` | Read `PCKDownloader.instance`, create radio buttons |
| `_on_source_selected(index)` | Call `PCKDownloader.instance.set_source(index)`, emit `source_changed` |
| `_scan_cache()` | Enumerate `user://pck_cache/`, compute total size |
| `_on_clear_cache()` | Show `AcceptDialog` confirmation, delete files, re-scan |
| `_load_settings()` / `_save_settings()` | Read/write `user://settings.cfg` |

## Settings Persistence: user://settings.cfg

```ini
[display]
default_view = "card"   # "card" | "list"
music_preview = true
```

## File Changes

### New Files
- `Scenes/SettingsPanel.tscn` — settings scene
- `Scripts/ui/settings_panel.gd` — settings script

### Modified Files
- `Scenes/LevelManager.tcsn` — change SettingsBtn text to "设置", update connection
- `Scripts/LevelManager.gd` — replace `_on_settings_pressed()` to instantiate SettingsPanel

### Deleted/Removed Fields
- `_source_popup: AcceptDialog` variable (no longer needed)
- `_update_source_label()` method (button no longer shows source name)

## States

### Loading State
- Source list shows "正在加载..." while `PCKDownloader` hasn't finished `fetch_level_urls()`
- Cache section shows "正在计算..." while scanning

### Empty State
- No sources: Section shows "暂无可用下载源"
- No cache: Cache section shows "暂无缓存"，Clear button disabled

### Error State
- Cache scan fails → show "无法读取缓存目录"
- Settings file corrupt → reset to defaults silently

## Edge Cases
- **No PCKDownloader sources**: Settings still opens; source section shows empty state
- **Cache dir missing**: Treated as empty (0 files)
- **Rapid source switching**: Each selection immediately updates PCKDownloader and the button text
- **Settings opened during download**: Cache still shows accurate usage (excludes current temp file)
