# LevelManager Preview Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure PreviewRow from HBoxContainer to Control-based overlay layout, placing navigation arrows on top of the preview image.

**Architecture:** PreviewRow becomes a Control container. PreviewClip fills it via PRESET_FULL_RECT. LeftArrow/RightArrow anchor to left/right edges and center vertically, overlaid on PreviewClip with semi-transparent pill backgrounds.

**Tech Stack:** Godot 4.6, GDScript, .tscn scene format

---

### Task 1: Restructure PreviewRow and arrows in LevelManager.tscn

**Files:**
- Modify: `Scenes/LevelManager.tscn`

- [ ] **Step 1: Change PreviewRow from HBoxContainer to Control**

Find the `PreviewRow` node (currently `type="HBoxContainer"`) and change it to a plain `Control`:

```
[node name="PreviewRow" type="Control" parent="Margin/VBox/Preview" unique_id=1486908314]
layout_mode = 2
size_flags_vertical = 3
```

Remove the `alignment = 1` line since Control doesn't have that property.

- [ ] **Step 2: Re-anchor PreviewClip to fill PreviewRow**

Change PreviewClip to use PRESET_FULL_RECT anchors:

```
[node name="PreviewClip" type="Control" parent="Margin/VBox/Preview/PreviewRow" unique_id=45754166]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
```

Remove the `size_flags_horizontal = 3` and `size_flags_stretch_ratio = 5.0` lines — they're HBoxContainer-specific and not needed for anchored positioning.

- [ ] **Step 3: Re-anchor LeftArrow to left-center with overlay style**

Replace the entire LeftArrow node block:

Old:
```
[node name="LeftArrow" type="Button" parent="Margin/VBox/Preview/PreviewRow" unique_id=1121263468]
custom_minimum_size = Vector2(50, 50)
layout_mode = 2
size_flags_vertical = 4
theme_override_colors/font_color = Color(1, 1, 1, 0.45)
theme_override_colors/font_hover_color = Color(1, 1, 1, 0.8)
theme_override_font_sizes/font_size = 28
theme_override_styles/normal = SubResource("StyleBoxFlat_ArrowBtn")
theme_override_styles/pressed = SubResource("StyleBoxFlat_ArrowBtn")
theme_override_styles/hover = SubResource("StyleBoxFlat_ArrowBtn")
action_mode = 0
text = "<"
```

New:
```
[node name="LeftArrow" type="Button" parent="Margin/VBox/Preview/PreviewRow" unique_id=1121263468]
custom_minimum_size = Vector2(44, 60)
layout_mode = 1
anchors_preset = 6
anchor_left = 0.02
anchor_right = 0.0
anchor_top = 0.5
anchor_bottom = 0.5
offset_left = 4.0
offset_top = -30.0
offset_right = 48.0
offset_bottom = 30.0
grow_horizontal = 0
grow_vertical = 4
theme_override_colors/font_color = Color(1, 1, 1, 0.9)
theme_override_colors/font_hover_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 22
theme_override_styles/normal = SubResource("StyleBoxFlat_ArrowOverlay")
theme_override_styles/pressed = SubResource("StyleBoxFlat_ArrowOverlayPressed")
theme_override_styles/hover = SubResource("StyleBoxFlat_ArrowOverlayHover")
action_mode = 0
text = "<"
```

- [ ] **Step 4: Re-anchor RightArrow to right-center with overlay style**

Replace the entire RightArrow node block:

Old:
```
[node name="RightArrow" type="Button" parent="Margin/VBox/Preview/PreviewRow" unique_id=1739859733]
custom_minimum_size = Vector2(50, 50)
layout_mode = 2
size_flags_vertical = 4
theme_override_colors/font_color = Color(1, 1, 1, 0.45)
theme_override_colors/font_hover_color = Color(1, 1, 1, 0.8)
theme_override_font_sizes/font_size = 28
theme_override_styles/normal = SubResource("StyleBoxFlat_ArrowBtn")
theme_override_styles/pressed = SubResource("StyleBoxFlat_ArrowBtn")
theme_override_styles/hover = SubResource("StyleBoxFlat_ArrowBtn")
action_mode = 0
text = ">"
```

New:
```
[node name="RightArrow" type="Button" parent="Margin/VBox/Preview/PreviewRow" unique_id=1739859733]
custom_minimum_size = Vector2(44, 60)
layout_mode = 1
anchors_preset = 10
anchor_left = 1.0
anchor_right = 0.98
anchor_top = 0.5
anchor_bottom = 0.5
offset_left = -48.0
offset_top = -30.0
offset_right = -4.0
offset_bottom = 30.0
grow_horizontal = 3
grow_vertical = 4
theme_override_colors/font_color = Color(1, 1, 1, 0.9)
theme_override_colors/font_hover_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 22
theme_override_styles/normal = SubResource("StyleBoxFlat_ArrowOverlay")
theme_override_styles/pressed = SubResource("StyleBoxFlat_ArrowOverlayPressed")
theme_override_styles/hover = SubResource("StyleBoxFlat_ArrowOverlayHover")
action_mode = 0
text = ">"
```

- [ ] **Step 5: Add overlay button style sub-resources**

Add these three new StyleBoxFlat sub-resources before `[node ...]` entries (e.g., after the existing StyleBoxFlat_YellowBtnHover entry at line 68):

```
[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_ArrowOverlay"]
bg_color = Color(0, 0, 0, 0.45)
border_width_left = 0
border_width_top = 0
border_width_right = 0
border_width_bottom = 0
corner_radius_top_left = 22
corner_radius_top_right = 22
corner_radius_bottom_right = 22
corner_radius_bottom_left = 22

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_ArrowOverlayHover"]
bg_color = Color(0, 0, 0, 0.65)
border_width_left = 0
border_width_top = 0
border_width_right = 0
border_width_bottom = 0
corner_radius_top_left = 22
corner_radius_top_right = 22
corner_radius_bottom_right = 22
corner_radius_bottom_left = 22

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_ArrowOverlayPressed"]
bg_color = Color(0, 0, 0, 0.75)
border_width_left = 0
border_width_top = 0
border_width_right = 0
border_width_bottom = 0
corner_radius_top_left = 22
corner_radius_top_right = 22
corner_radius_bottom_right = 22
corner_radius_bottom_left = 22
```

- [ ] **Step 6: Remove the now-unused StyleBoxFlat_ArrowBtn sub-resource** (optional cleanup)

The old `[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_ArrowBtn"]` (transparent bg, corner_radius=30) is no longer referenced by any node. It can be removed for cleanliness, but is harmless as dead code. Leave it for now to minimize diff noise.

### Task 2: Verify script compatibility

**Files:**
- Modify: `Scripts/LevelManager.gd`

- [ ] **Step 1: Verify node paths haven't changed**

The script uses these `@onready` paths:
```gdscript
@onready var preview_clip: Control = $Margin/VBox/Preview/PreviewRow/PreviewClip
@onready var left_arrow: Button = $Margin/VBox/Preview/PreviewRow/LeftArrow
@onready var right_arrow: Button = $Margin/VBox/Preview/PreviewRow/RightArrow
```

All three nodes remain children of `PreviewRow` — only the parent type changed from `HBoxContainer` to `Control`. Paths are correct, no script changes needed.

- [ ] **Step 2: Verify arrow visibility logic**

The `_update_display()` method controls arrow visibility:
```gdscript
left_arrow.visible = (_current_mode == ViewMode.CARD) and (sz > 1)
right_arrow.visible = (_current_mode == ViewMode.CARD) and (sz > 1)
```

This logic is unchanged — the arrows still exist and respond to `.visible`. No code changes needed.

- [ ] **Step 3: Verify _position_panels works with the new layout**

The `_position_panels()` method:
```gdscript
func _position_panels() -> void:
    if preview_clip.size.x < 2:
        return
    _panel.position = Vector2.ZERO
    _panel.size = preview_clip.size
```

PreviewClip still fills its parent via PRESET_FULL_RECT anchors. `_panel` (the preview textur) is positioned relative to PreviewClip. The layout chain is: PreviewClip fills PreviewRow → _panel fills PreviewClip. This works correctly. No changes needed.

- [ ] **Step 4: Verify the tscn changes work correctly**

The `.tscn` change will be committed alongside the plan. Use Godot to verify:
- PreviewRow is now a Control instead of HBoxContainer
- PreviewClip fills PreviewRow
- Arrows are positioned at left/right edges, centered vertically
- Arrows have semi-transparent dark pill background
- CounterLabel still shows below the preview
- Switching between levels works with the new layout
- List view toggle still works (PreviewRow is only used in CARD mode)

### Task 3: Manual testing in Godot

**Files:**
- Test: `Scenes/LevelManager.tscn` (in editor)

- [ ] **Step 1: Open the project in Godot editor**

```bash
godot4.6 -e --path .
```

Expected: Editor opens. Switch to LevelManager.tscn scene. No errors in the scene tree.

- [ ] **Step 2: Verify scene tree structure**

In the editor, select "Margin/VBox/Preview/PreviewRow" — it should be a `Control` node.
- PreviewClip should show anchors expanding to fill PreviewRow
- LeftArrow should be anchored to left-center with semi-transparent background
- RightArrow should be anchored to right-center with semi-transparent background

- [ ] **Step 3: Run the project and test**

```bash
godot4.6 --path .
```

Expected:
- Navigate to level selection
- Preview image displays with arrows floating on left/right edges
- Arrows have dark pill backgrounds visible on any image
- Clicking arrows switches levels correctly
- Arrows hidden when only 1 level
- List view toggle hides arrows (already worked before)
- "详细信息" button area aligns with preview image edges
