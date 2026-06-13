## ImGuiDebug.gd — Autoload 单例
## F11 切换 ImGui 显示/隐藏，提供 PopupToast 测试按钮
extends Node

var _visible: bool = true


func _ready() -> void:
	# 监听 F11 按键
	set_process_input(true)

	# 通过 ImGuiGD 单例注册渲染回调（官方方式，兼容 native/C# 两种后端）
	var imgui_gd = Engine.get_singleton("ImGuiGD")
	if imgui_gd and imgui_gd.has_method("Connect"):
		imgui_gd.Connect(_on_imgui_layout)
		print("[ImGuiDebug] 已通过 ImGuiGD.Connect 注册回调，按 F11 切换显示")
	else:
		# 回退：连接 ImGuiRoot.imgui_layout 信号（纯 C# 后端）
		var imgui_root = get_node_or_null("/root/ImGuiRoot")
		if imgui_root and imgui_root.has_signal("imgui_layout"):
			imgui_root.imgui_layout.connect(_on_imgui_layout)
			print("[ImGuiDebug] 已通过信号连接（C# fallback），按 F11 切换显示")
		else:
			push_warning("[ImGuiDebug] 无法连接 ImGui 渲染回调")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		_toggle_visibility()
		# 不消费事件，允许其他节点继续处理
		# get_viewport().set_input_as_handled()


func _toggle_visibility() -> void:
	# 通过 GDExtension 单例切换 ImGui 全局可见性
	var imgui_gd = Engine.get_singleton("ImGuiGD")
	if imgui_gd:
		_visible = not _visible
		imgui_gd.Visible = _visible
		print("[ImGuiDebug] ImGui %s" % ("显示" if _visible else "隐藏"))
	else:
		# 回退：直接查找 ImGuiLayer CanvasLayer 节点
		var imgui_root = get_node_or_null("/root/ImGuiRoot")
		if imgui_root and imgui_root.get_child_count() > 0:
			var layer = imgui_root.get_child(0)
			if layer is CanvasLayer:
				_visible = not _visible
				layer.visible = _visible
				print("[ImGuiDebug] ImGui %s (fallback)" % ("显示" if _visible else "隐藏"))


func _on_imgui_layout() -> void:
	if not _visible:
		return

	if ImGui.Begin("Imgui"):
		if ImGui.Button("Toast"):
			PopupToast.show("Hello, GodotLine!")
			print("[ImGuiDebug] 显示 toast")

		ImGui.SameLine()

		if ImGui.Button("Multi Toast"):
			PopupToast.show("这是一条较长的测试消息")
			PopupToast.show("第二条消息", 3.0)
			print("[ImGuiDebug] 批量显示 toast")

		ImGui.SameLine()

		if ImGui.Button("Show Debug"):
			PopupToast.debug("这是一条调试消息", 4.0)
			print("[ImGuiDebug] 显示调试 toast")

	ImGui.End()
