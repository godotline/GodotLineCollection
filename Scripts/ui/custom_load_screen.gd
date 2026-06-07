## Custom loading screen for LongSceneManager
## 被 LSM 实例化后自动从静态变量读取封面和关卡名
## 提供 fade_in / fade_out 过渡
## 注意: CanvasLayer 自身无 modulate, 通过 fade container 实现全屏淡入淡出

class_name CustomLoadScreen
extends CanvasLayer

static var pending_cover: Texture2D
static var pending_title: String = ""

@onready var cover_texture: TextureRect = $FadeContainer/Margin/VBox/CoverTexture
@onready var name_label: Label = $FadeContainer/Margin/VBox/NameLabel
@onready var spinner: Control = $FadeContainer/Margin/VBox/Spinner
@onready var fade_container: Control = $FadeContainer

func _ready() -> void:
	layer = 1000
	follow_viewport_enabled = true

	cover_texture.texture = pending_cover
	cover_texture.visible = pending_cover != null
	name_label.text = pending_title if pending_title != "" else "未命名关卡"

	# 初始透明
	fade_container.modulate.a = 0.0


func fade_in() -> void:
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(fade_container, "modulate:a", 1.0, 0.25)
	await tw.finished


func fade_out() -> void:
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(fade_container, "modulate:a", 0.0, 0.5)
	await tw.finished
