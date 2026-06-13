## PopupToast.gd — Autoload 单例
## 全局文字弹窗系统：屏幕右上角，Tween 从右侧滑入
## 用法: PopupToast.show("文字内容", 2.0)
extends Node

const FONT_SIZE := 16
const PANEL_BG := Color(0, 0, 0, 0.75)
const PANEL_BORDER := Color(1, 1, 1, 0.3)
const TEXT_COLOR := Color(1, 1, 1, 1)
const CORNER_RADIUS := 8
const MAX_TOASTS := 5

var _canvas_layer: CanvasLayer
var _active_toasts: Array[Node] = []


func _ready() -> void:
	# 创建 CanvasLayer 承载所有 toast
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "PopupToastLayer"
	_canvas_layer.layer = 128  # 最顶层
	add_child(_canvas_layer)


## 显示一条 toast 文字
## message: 要显示的文字
## duration: 停留时间（秒），默认 2.0
func show(message: String, duration: float = 2.0) -> void:
	var toast := _create_toast(message)
	_canvas_layer.add_child(toast)
	_active_toasts.append(toast)

	# 限制最大 toast 数量
	while _active_toasts.size() > MAX_TOASTS:
		_remove_toast(_active_toasts[0])

	# 等待一帧让 panel 完成 sizing，然后从右侧滑入
	await get_tree().process_frame
	if not is_instance_valid(toast):
		return
	_animate_in(toast, duration)


func _create_toast(message: String) -> PanelContainer:
	var panel := PanelContainer.new()

	# 样式
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = PANEL_BORDER
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = 0  # 右边贴边，不圆角
	style.corner_radius_bottom_right = 0
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	# 文字
	var label := Label.new()
	label.text = message
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)

	# 先放到屏幕外，避免在 _animate_in 之前的短暂一帧出现在左上角
	panel.position.x = 99999
	return panel


func _animate_in(panel: PanelContainer, duration: float) -> void:
	var viewport_w := get_viewport().get_visible_rect().size.x

	# 计算 y 偏移（panel 此时已经在 _active_toasts 中，取其索引）
	var idx := _active_toasts.find(panel)
	var y_offset := _calc_y_offset(idx) if idx >= 0 else _get_next_y_offset()

	# 目标位置：面板右边缘贴屏幕右边缘
	var target_x := viewport_w - panel.size.x
	# 起始位置：屏幕右侧外
	panel.position = Vector2(viewport_w + 50, y_offset)

	# 入场动画：从右侧滑入
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "position:x", target_x, 0.3)

	# 停留 + 退场
	tween.tween_interval(duration)
	tween.tween_callback(_begin_exit.bind(panel))


func _begin_exit(panel) -> void:
	var viewport_w := get_viewport().get_visible_rect().size.x
	# 滑出到屏幕右侧外
	var target_x := viewport_w + 50

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "position:x", target_x, 0.3)
	tween.tween_callback(_remove_toast.bind(panel))


## 移除 toast 并重新排列其余
## 注意：参数不写类型，避免 tween_callback 的类型转换报错
func _remove_toast(toast) -> void:
	_active_toasts.erase(toast)
	if is_instance_valid(toast):
		toast.queue_free()
	_reposition_toasts()


func _reposition_toasts() -> void:
	# 移除后，其他 toast 上移填补空位
	for i in range(_active_toasts.size()):
		var toast = _active_toasts[i]
		if is_instance_valid(toast):
			var tween := create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(toast, "position:y", _calc_y_offset(i), 0.2)


func _get_next_y_offset() -> float:
	return _calc_y_offset(_active_toasts.size())


func _calc_y_offset(index: int) -> float:
	const MARGIN_TOP := 10.0
	const SPACING := 8.0
	# 估算每个 toast 高度
	const EST_TOAST_HEIGHT := 40.0
	return MARGIN_TOP + index * (EST_TOAST_HEIGHT + SPACING)


## 快捷方法：显示调试 toast（仅在调试构建中显示）
func debug(message: String, duration: float = 2.0) -> void:
	if OS.is_debug_build():
		show("[DEBUG] " + message, duration)
