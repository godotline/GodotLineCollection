class_name EnergySystem
extends Node

var energy: int = 10
var _label: Label = null
var _watch_ad_btn: Button = null

signal watch_ad_requested()

const SAVE_PATH := "user://energy.save"

func _init(label: Label, btn: Button) -> void:
	_label = label
	_watch_ad_btn = btn
	_label.text = "💎 %d" % energy
	_watch_ad_btn.pressed.connect(_on_watch_ad_pressed)
	_load()
	_update_display()
	_start_pulse(_watch_ad_btn)

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
