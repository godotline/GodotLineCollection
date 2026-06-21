class_name EnergySystem
extends Node

var energy: int = 10
var _label: Label = null
var _watch_ad_btn: Button = null
var _info_label: Label = null

signal watch_ad_requested()

const SAVE_PATH := "user://energy.save"

func _init(header: HBoxContainer, info_label: Label) -> void:
	header.add_child(self)
	_info_label = info_label
	_load()
	_create_ui(header)

func _load() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file != null:
		energy = file.get_32()
		file.close()
	else:
		energy = 10
		_save()

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_32(energy)
		file.close()

func consume() -> bool:
	if energy <= 0:
		return false
	energy -= 1
	_save()
	_update_display()
	return true

func add(amount: int) -> void:
	energy += amount
	_save()
	_update_display()

func _update_display() -> void:
	if _label:
		_label.text = "💎 %d" % energy

func _create_ui(header: HBoxContainer) -> void:
	_label = Label.new()
	_label.text = "💎 %d" % energy
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	_label.add_theme_font_size_override("font_size", 15)
	header.add_child(_label)
	header.move_child(_label, 4)

	_watch_ad_btn = Button.new()
	_watch_ad_btn.text = "🎬 看广告"
	_watch_ad_btn.tooltip_text = "观看广告获得10个代币"
	_watch_ad_btn.custom_minimum_size = Vector2(100, 0)
	var ad_style := StyleBoxFlat.new()
	ad_style.bg_color = Color(0.95, 0.25, 0.15, 0.95)
	ad_style.corner_radius_top_left = 20
	ad_style.corner_radius_top_right = 20
	ad_style.corner_radius_bottom_right = 20
	ad_style.corner_radius_bottom_left = 20
	ad_style.border_width_left = 2
	ad_style.border_width_top = 2
	ad_style.border_width_right = 2
	ad_style.border_width_bottom = 2
	ad_style.border_color = Color(1.0, 0.5, 0.2, 0.8)
	var ad_hover := ad_style.duplicate()
	ad_hover.bg_color = Color(1.0, 0.35, 0.2, 1.0)
	ad_hover.border_color = Color(1.0, 0.7, 0.4, 1.0)
	_watch_ad_btn.add_theme_stylebox_override("normal", ad_style)
	_watch_ad_btn.add_theme_stylebox_override("hover", ad_hover)
	_watch_ad_btn.add_theme_stylebox_override("pressed", ad_hover)
	_watch_ad_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_watch_ad_btn.add_theme_font_size_override("font_size", 13)
	_watch_ad_btn.pressed.connect(_on_watch_ad_pressed)
	header.add_child(_watch_ad_btn)
	header.move_child(_watch_ad_btn, 5)

	_start_pulse(_watch_ad_btn)

func _on_watch_ad_pressed() -> void:
	watch_ad_requested.emit()

func _start_pulse(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	var tw := create_tween()
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.8)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.8)
	var tw2 := create_tween()
	tw2.set_loops()
	tw2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(btn, "modulate:a", 0.85, 0.8)
	tw2.tween_property(btn, "modulate:a", 1.0, 0.8)
