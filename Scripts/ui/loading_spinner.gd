extends Control

## 加载旋转点动画
## 绘制一个圆圈轮廓 + 沿圆周旋转的小圆点

var _angle: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_angle += delta * 2.0
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2
	var radius: float = min(size.x, size.y) / 2 - 4.0

	# 圆圈轮廓
	draw_arc(center, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.3), 2.0)

	# 旋转的小圆点
	var dot_pos: Vector2 = center + Vector2(cos(_angle), sin(_angle)) * radius
	draw_circle(dot_pos, 4.0, Color(1, 1, 1, 0.9))
