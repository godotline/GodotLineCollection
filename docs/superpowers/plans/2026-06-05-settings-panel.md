# Settings Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the inline "源" button with a standalone settings scene (`SettingsPanel.tscn`) as a modal overlay, containing download source selection, cache management, and display settings.

**Architecture:** A `SettingsPanel` Control node covers the full screen as a semi-transparent overlay, with a centered PanelContainer containing a fixed title bar (back button + nav icons) and a scrollable content area with three sections. Settings are persisted via `user://settings.cfg`.

**Tech Stack:** Godot 4.6 (GDScript), existing PCKDownloader static singleton

---

### Task 1: Create Scripts/ui/settings_panel.gd

**Files:**
- Create: `Scripts/ui/settings_panel.gd`

- [ ] **Write the settings panel script**

```gdscript
class_name SettingsPanel
extends Control

signal settings_closed()

const SETTINGS_CFG_PATH := "user://settings.cfg"

@onready var _panel: PanelContainer = $Panel
@onready var _scroll: ScrollContainer = $Panel/Margin/VBox/Scroll
@onready var _source_list: VBoxContainer = $Panel/Margin/VBox/Scroll/Content/SourceSection/SourceList
@onready var _source_section: Control = $Panel/Margin/VBox/Scroll/Content/SourceSection
@onready var _cache_section: Control = $Panel/Margin/VBox/Scroll/Content/CacheSection
@onready var _display_section: Control = $Panel/Margin/VBox/Scroll/Content/DisplaySection
@onready var _cache_size_label: Label = $Panel/Margin/VBox/Scroll/Content/CacheSection/CacheSizeLabel
@onready var _cache_count_label: Label = $Panel/Margin/VBox/Scroll/Content/CacheSection/CacheCountLabel
@onready var _clear_btn: Button = $Panel/Margin/VBox/Scroll/Content/CacheSection/ClearBtn
@onready var _view_option: OptionButton = $Panel/Margin/VBox/Scroll/Content/DisplaySection/ViewRow/ViewOption
@onready var _music_toggle: CheckButton = $Panel/Margin/VBox/Scroll/Content/DisplaySection/MusicRow/MusicToggle
@onready var _back_btn: Button = $Panel/Margin/VBox/TitleBar/BackBtn


func _ready() -> void:
	_center_panel()
	_populate_sources()
	_scan_cache()
	_load_display_settings()

	_back_btn.pressed.connect(_on_back_pressed)
	$Panel/Margin/VBox/TitleBar/NavIcons/SourceNav.pressed.connect(_scroll_to_section.bind(_source_section))
	$Panel/Margin/VBox/TitleBar/NavIcons/CacheNav.pressed.connect(_scroll_to_section.bind(_cache_section))
	$Panel/Margin/VBox/TitleBar/NavIcons/DisplayNav.pressed.connect(_scroll_to_section.bind(_display_section))
	_clear_btn.pressed.connect(_on_clear_cache)
	_view_option.item_selected.connect(_on_view_changed)
	_music_toggle.toggled.connect(_on_music_toggled)
	get_viewport().size_changed.connect(_center_panel)


func _center_panel() -> void:
	var viewport_size := get_viewport_rect().size
	var pw := mini(520, viewport_size.x - 80)
	var ph := mini(580, viewport_size.y - 80)
	_panel.position = (viewport_size - Vector2(pw, ph)) / 2.0
	_panel.size = Vector2(pw, ph)


func _populate_sources() -> void:
	if not PCKDownloader.instance.has_sources():
		var label := Label.new()
		label.text = "暂无可用下载源"
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		_source_list.add_child(label)
		return

	var group := ButtonGroup.new()
	var current_idx := PCKDownloader.instance.get_source_index()

	for i in range(PCKDownloader.instance.get_source_count()):
		var radio := CheckButton.new()
		radio.text = PCKDownloader.instance.get_source_name(i)
		radio.button_group = group
		radio.button_pressed = (i == current_idx)
		radio.pressed.connect(_on_source_selected.bind(i))
		_source_list.add_child(radio)


func _on_source_selected(index: int) -> void:
	PCKDownloader.instance.set_source(index)


func _scan_cache() -> void:
	var cache_dir := ProjectSettings.globalize_path("user://pck_cache/")
	if not DirAccess.dir_exists_absolute(cache_dir):
		_cache_size_label.text = "缓存大小: —"
		_cache_count_label.text = "关卡数量: 0"
		_clear_btn.disabled = true
		return

	var dir := DirAccess.open(cache_dir)
	if dir == null:
		_cache_size_label.text = "无法读取缓存目录"
		_cache_count_label.text = ""
		_clear_btn.disabled = true
		return

	var total_size: int = 0
	var count: int = 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != ".." and not dir.current_is_dir():
			var file_path := cache_dir.path_join(file_name)
			total_size += FileAccess.get_file_size(file_path)
			count += 1
		file_name = dir.get_next()
	dir.list_dir_end()

	_cache_size_label.text = "缓存大小: %s" % _format_size(total_size)
	_cache_count_label.text = "关卡数量: %d 个" % count
	_clear_btn.disabled = (count == 0)


func _format_size(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1024 * 1024:
		return "%.1f KB" % (bytes / 1024.0)
	elif bytes < 1024 * 1024 * 1024:
		return "%.1f MB" % (bytes / (1024.0 * 1024.0))
	else:
		return "%.2f GB" % (bytes / (1024.0 * 1024.0 * 1024.0))


func _on_clear_cache() -> void:
	var confirm := AcceptDialog.new()
	confirm.title = "清除缓存"
	confirm.dialog_text = "确定要清除所有缓存文件吗？"
	confirm.size = Vector2i(300, 120)
	add_child(confirm)
	confirm.popup_centered()
	confirm.confirmed.connect(_do_clear_cache)


func _do_clear_cache() -> void:
	var cache_dir := ProjectSettings.globalize_path("user://pck_cache/")
	var dir := DirAccess.open(cache_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != ".." and not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	_scan_cache()


func _load_display_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_CFG_PATH)

	var default_view: String = "card"
	var music_preview: bool = true

	if err == OK:
		default_view = cfg.get_value("display", "default_view", "card")
		music_preview = cfg.get_value("display", "music_preview", true)

	_view_option.selected = 0 if default_view == "card" else 1
	_music_toggle.button_pressed = music_preview


func _on_view_changed(index: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_CFG_PATH)
	cfg.set_value("display", "default_view", "card" if index == 0 else "list")
	cfg.save(SETTINGS_CFG_PATH)


func _on_music_toggled(enabled: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_CFG_PATH)
	cfg.set_value("display", "music_preview", enabled)
	cfg.save(SETTINGS_CFG_PATH)


func _scroll_to_section(section: Control) -> void:
	var target_y := maxf(0, section.position.y - 8)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_scroll, "scroll_vertical", target_y, 0.3)


func _on_back_pressed() -> void:
	settings_closed.emit()
	queue_free()
```

---

### Task 2: Create Scenes/SettingsPanel.tscn

**Files:**
- Create: `Scenes/SettingsPanel.tscn`

- [ ] **Write the SettingsPanel scene file**

```gdscene
[gd_scene format=3]

[ext_resource type="Script" path="res://Scripts/ui/settings_panel.gd" id="1"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_Panel"]
bg_color = Color(0.1, 0.1, 0.16, 0.95)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.3, 0.33, 0.45, 0.5)
corner_radius_top_left = 12
corner_radius_top_right = 12
corner_radius_bottom_right = 12
corner_radius_bottom_left = 12
content_margin_left = 0
content_margin_top = 0
content_margin_right = 0
content_margin_bottom = 0

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_TitleBar"]
bg_color = Color(0.12, 0.12, 0.18, 0.95)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.3, 0.33, 0.45, 0.5)
corner_radius_top_left = 12
corner_radius_top_right = 12
corner_radius_bottom_right = 0
corner_radius_bottom_left = 0

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_Hover"]
bg_color = Color(1, 1, 1, 0.08)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_NavHover"]
bg_color = Color(1, 1, 1, 0.12)
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_right = 6
corner_radius_bottom_left = 6

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_ClearBtn"]
bg_color = Color(0.8, 0.25, 0.25, 0.8)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_right = 8
corner_radius_bottom_left = 8

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_ClearBtnHover"]
bg_color = Color(0.9, 0.3, 0.3, 0.9)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_right = 8
corner_radius_bottom_left = 8

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_Btn"]
bg_color = Color(0.15, 0.15, 0.22, 0.7)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.3, 0.33, 0.45, 0.5)
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_right = 8
corner_radius_bottom_left = 8

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_Separator"]
bg_color = Color(0.25, 0.28, 0.4, 0.4)
corner_radius_top_left = 1
corner_radius_top_right = 1
corner_radius_bottom_right = 1
corner_radius_bottom_left = 1

[node name="SettingsPanel" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("1")

[node name="BG" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.55)
mouse_filter = 1

[node name="Panel" type="PanelContainer" parent="."]
custom_minimum_size = Vector2(420, 0)
layout_mode = 0
theme_override_styles/panel = SubResource("StyleBoxFlat_Panel")

[node name="Margin" type="MarginContainer" parent="Panel"]
layout_mode = 2
theme_override_constants/margin_left = 0
theme_override_constants/margin_top = 0
theme_override_constants/margin_right = 0
theme_override_constants/margin_bottom = 0

[node name="VBox" type="VBoxContainer" parent="Panel/Margin"]
layout_mode = 2
theme_override_constants/separation = 0

[node name="TitleBar" type="PanelContainer" parent="Panel/Margin/VBox"]
custom_minimum_size = Vector2(0, 44)
layout_mode = 2
size_flags_horizontal = 3
theme_override_styles/panel = SubResource("StyleBoxFlat_TitleBar")

[node name="HBox" type="HBoxContainer" parent="Panel/Margin/VBox/TitleBar"]
layout_mode = 2
theme_override_constants/separation = 4

[node name="BackBtn" type="Button" parent="Panel/Margin/VBox/TitleBar/HBox"]
custom_minimum_size = Vector2(72, 0)
layout_mode = 2
size_flags_vertical = 4
theme_override_colors/font_color = Color(1, 1, 1, 0.85)
theme_override_font_sizes/font_size = 14
theme_override_styles/normal = SubResource("StyleBoxFlat_Hover")
theme_override_styles/hover = SubResource("StyleBoxFlat_NavHover")
theme_override_styles/pressed = SubResource("StyleBoxFlat_Hover")
text = "← 返回"

[node name="SpacerL" type="Control" parent="Panel/Margin/VBox/TitleBar/HBox"]
layout_mode = 2
size_flags_horizontal = 3

[node name="Title" type="Label" parent="Panel/Margin/VBox/TitleBar/HBox"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.95)
theme_override_font_sizes/font_size = 16
text = "设置"
horizontal_alignment = 1

[node name="SpacerR" type="Control" parent="Panel/Margin/VBox/TitleBar/HBox"]
layout_mode = 2
size_flags_horizontal = 3

[node name="NavIcons" type="HBoxContainer" parent="Panel/Margin/VBox/TitleBar/HBox"]
layout_mode = 2
theme_override_constants/separation = 2

[node name="SourceNav" type="Button" parent="Panel/Margin/VBox/TitleBar/HBox/NavIcons"]
custom_minimum_size = Vector2(32, 32)
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.6)
theme_override_colors/font_hover_color = Color(1, 1, 1, 0.9)
theme_override_font_sizes/font_size = 14
theme_override_styles/normal = SubResource("StyleBoxFlat_Hover")
theme_override_styles/hover = SubResource("StyleBoxFlat_NavHover")
theme_override_styles/pressed = SubResource("StyleBoxFlat_Hover")
tooltip_text = "下载源"
text = "源"

[node name="CacheNav" type="Button" parent="Panel/Margin/VBox/TitleBar/HBox/NavIcons"]
custom_minimum_size = Vector2(32, 32)
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.6)
theme_override_colors/font_hover_color = Color(1, 1, 1, 0.9)
theme_override_font_sizes/font_size = 14
theme_override_styles/normal = SubResource("StyleBoxFlat_Hover")
theme_override_styles/hover = SubResource("StyleBoxFlat_NavHover")
theme_override_styles/pressed = SubResource("StyleBoxFlat_Hover")
tooltip_text = "缓存管理"
text = "存"

[node name="DisplayNav" type="Button" parent="Panel/Margin/VBox/TitleBar/HBox/NavIcons"]
custom_minimum_size = Vector2(32, 32)
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.6)
theme_override_colors/font_hover_color = Color(1, 1, 1, 0.9)
theme_override_font_sizes/font_size = 14
theme_override_styles/normal = SubResource("StyleBoxFlat_Hover")
theme_override_styles/hover = SubResource("StyleBoxFlat_NavHover")
theme_override_styles/pressed = SubResource("StyleBoxFlat_Hover")
tooltip_text = "显示设置"
text = "显"

[node name="Scroll" type="ScrollContainer" parent="Panel/Margin/VBox"]
layout_mode = 2
size_flags_vertical = 3

[node name="Content" type="VBoxContainer" parent="Panel/Margin/VBox/Scroll"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 0

[node name="SourceSection" type="VBoxContainer" parent="Panel/Margin/VBox/Scroll/Content"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="SectionHeader" type="Label" parent="Panel/Margin/VBox/Scroll/Content/SourceSection"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.95)
theme_override_font_sizes/font_size = 16
text = "下载源"

[node name="SourceList" type="VBoxContainer" parent="Panel/Margin/VBox/Scroll/Content/SourceSection"]
layout_mode = 2
theme_override_constants/separation = 4

[node name="Sep1" type="ColorRect" parent="Panel/Margin/VBox/Scroll/Content"]
custom_minimum_size = Vector2(0, 2)
layout_mode = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_Separator")
color = Color(0.25, 0.28, 0.4, 0.6)

[node name="Sep1Spacer" type="Control" parent="Panel/Margin/VBox/Scroll/Content"]
custom_minimum_size = Vector2(0, 4)
layout_mode = 2

[node name="CacheSection" type="VBoxContainer" parent="Panel/Margin/VBox/Scroll/Content"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="SectionHeader" type="Label" parent="Panel/Margin/VBox/Scroll/Content/CacheSection"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.95)
theme_override_font_sizes/font_size = 16
text = "缓存管理"

[node name="CacheSizeLabel" type="Label" parent="Panel/Margin/VBox/Scroll/Content/CacheSection"]
layout_mode = 2
theme_override_colors/font_color = Color(0.6, 0.62, 0.7, 1)
theme_override_font_sizes/font_size = 13
text = "缓存大小: —"

[node name="CacheCountLabel" type="Label" parent="Panel/Margin/VBox/Scroll/Content/CacheSection"]
layout_mode = 2
theme_override_colors/font_color = Color(0.6, 0.62, 0.7, 1)
theme_override_font_sizes/font_size = 13
text = "关卡数量: —"

[node name="ClearBtn" type="Button" parent="Panel/Margin/VBox/Scroll/Content/CacheSection"]
custom_minimum_size = Vector2(0, 32)
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.9)
theme_override_font_sizes/font_size = 13
theme_override_styles/normal = SubResource("StyleBoxFlat_ClearBtn")
theme_override_styles/hover = SubResource("StyleBoxFlat_ClearBtnHover")
theme_override_styles/pressed = SubResource("StyleBoxFlat_ClearBtn")
text = "清除缓存"

[node name="Sep2" type="ColorRect" parent="Panel/Margin/VBox/Scroll/Content"]
custom_minimum_size = Vector2(0, 2)
layout_mode = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_Separator")
color = Color(0.25, 0.28, 0.4, 0.6)

[node name="Sep2Spacer" type="Control" parent="Panel/Margin/VBox/Scroll/Content"]
custom_minimum_size = Vector2(0, 4)
layout_mode = 2

[node name="DisplaySection" type="VBoxContainer" parent="Panel/Margin/VBox/Scroll/Content"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="SectionHeader" type="Label" parent="Panel/Margin/VBox/Scroll/Content/DisplaySection"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.95)
theme_override_font_sizes/font_size = 16
text = "显示设置"

[node name="ViewRow" type="HBoxContainer" parent="Panel/Margin/VBox/Scroll/Content/DisplaySection"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="ViewLabel" type="Label" parent="Panel/Margin/VBox/Scroll/Content/DisplaySection/ViewRow"]
layout_mode = 2
theme_override_colors/font_color = Color(0.6, 0.62, 0.7, 1)
theme_override_font_sizes/font_size = 14
text = "默认视图"

[node name="ViewOption" type="OptionButton" parent="Panel/Margin/VBox/Scroll/Content/DisplaySection/ViewRow"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_colors/font_color = Color(1, 1, 1, 0.85)
theme_override_font_sizes/font_size = 13
items = Array[Dictionary]([{"id":0,"metadata":{},"text":"卡片视图"},{"id":1,"metadata":{},"text":"列表视图"}])

[node name="MusicRow" type="HBoxContainer" parent="Panel/Margin/VBox/Scroll/Content/DisplaySection"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="MusicLabel" type="Label" parent="Panel/Margin/VBox/Scroll/Content/DisplaySection/MusicRow"]
layout_mode = 2
theme_override_colors/font_color = Color(0.6, 0.62, 0.7, 1)
theme_override_font_sizes/font_size = 14
text = "音乐预览"

[node name="MusicToggle" type="CheckButton" parent="Panel/Margin/VBox/Scroll/Content/DisplaySection/MusicRow"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.85)
theme_override_font_sizes/font_size = 13
text = "开启"

[node name="BottomPad" type="Control" parent="Panel/Margin/VBox/Scroll/Content"]
custom_minimum_size = Vector2(0, 16)
layout_mode = 2
```

---

### Task 3: Update LevelManager.gd

**Files:**
- Modify: `Scripts/LevelManager.gd` (lines 28, 69, 89, 106-144)

- [ ] **Remove old source popup variable, update _ready and _fetch_remote_urls**

Delete line 28: `var _source_popup: AcceptDialog`

In `_ready()` (line 69), delete: `_update_source_label()`

In `_fetch_remote_urls()` (lines 88-89), replace the block:
```gdscript
# Old (lines 87-89):
		# Restore settings button state if download sources are available
		if PCKDownloader.instance.has_sources():
			_update_source_label()

# New:
		pass  # Source label no longer shown on button
```

- [ ] **Delete _update_source_label() method**

Delete the entire method (lines 106-112):
```gdscript
func _update_source_label() -> void:
	var name := PCKDownloader.instance.get_source_name(PCKDownloader.instance.get_source_index())
	if name.is_empty():
		settings_btn.text = "源"
	else:
		settings_btn.text = "源:" + name
```

- [ ] **Delete old _on_source_selected() method**

Delete the entire method (lines 141-144):
```gdscript
func _on_source_selected(index: int, popup: AcceptDialog) -> void:
	PCKDownloader.instance.set_source(index)
	_update_source_label()
	popup.queue_free()
```

- [ ] **Replace _on_settings_pressed() to instantiate SettingsPanel**

Replace the entire method (lines 114-138):
```gdscript
func _on_settings_pressed() -> void:
	var panel := preload("res://Scenes/SettingsPanel.tscn").instantiate()
	add_child(panel)
	panel.settings_closed.connect(panel.queue_free)
```

---

### Task 4: Update LevelManager.tscn

**Files:**
- Modify: `Scenes/LevelManager.tscn` (line 159)

- [ ] **Change SettingsBtn text from "源" to "设置"**

Edit line 159:
```gdscene
# Old:
text = "源"

# New:
text = "设置"
```

---

### Task 5: Apply saved display settings in LevelManager

**Files:**
- Modify: `Scripts/LevelManager.gd`

- [ ] **Read display settings on startup and apply them**

In `_ready()`, add after `_update_user_display()` (after line 59):
```gdscript
	_apply_display_settings()
```

Add the new method after `_update_display()` (after line 333):
```gdscript
func _apply_display_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	var default_view: String = cfg.get_value("display", "default_view", "card")
	var music_preview: bool = cfg.get_value("display", "music_preview", true)

	if default_view == "list" and _current_mode == ViewMode.CARD:
		_on_view_toggle_pressed()

	if not music_preview and _music_player.playing:
		_music_player.stop()
		_music_player.stream = null
		_current_music_data = null
```

---

### Task 6: Verify

- [ ] **Check scene loads without errors**

Run: `godot4.6 --path . res://Scenes/LevelManager.tscn`
Expected: Game loads, no errors in output

- [ ] **Check settings button opens panel**

Click "设置" button → Settings panel appears as a modal overlay with:
- [ ] Title bar with "← 返回" and nav icons
- [ ] Scrollable content with three sections
- [ ] Source section shows available sources (or "暂无可用下载源")
- [ ] Cache section shows cache info (or "暂无缓存")
- [ ] Display section shows view option and music toggle

- [ ] **Check back button closes panel**

Click "← 返回" → Panel closes, back to level list

- [ ] **Check nav icons scroll to sections**

Click each nav icon ("源", "存", "显") → Scroll animates smoothly to the corresponding section

- [ ] **Check source selection works**

Select a different source → PCKDownloader switches source, label updates on next panel open

- [ ] **Check cache operations**

- [ ] Cache section shows accurate size and count
- [ ] "清除缓存" button opens confirmation dialog
- [ ] Confirming clears cache and updates display

- [ ] **Check display settings persist**

- [ ] Change default view to "列表视图" → close panel → reopen → setting is preserved
- [ ] Toggle music preview off → close panel → reopen → setting is preserved
