extends Control

@onready var level_title: Label = $Margin/VBox/Info/LevelTitle
@onready var author_label: Label = $Margin/VBox/Info/AuthorLabel
@onready var preview_clip: Control = $Margin/VBox/Preview/PreviewRow/PreviewClip
@onready var left_arrow: Button = $Margin/VBox/Preview/PreviewRow/LeftArrow
@onready var right_arrow: Button = $Margin/VBox/Preview/PreviewRow/RightArrow
@onready var user_capsule: PanelContainer = $Margin/VBox/Header/UserCapsule
@onready var avatar_rect: TextureRect = $Margin/VBox/Header/UserCapsule/HBox/AvatarRect
@onready var name_label: Label = $Margin/VBox/Header/UserCapsule/HBox/NameLabel
@onready var info_button: Button = $Margin/VBox/Info/Actions/InfoButton
@onready var counter_label: Label = $Margin/VBox/Preview/CounterLabel
@onready var info_label: Label = $Margin/VBox/Bottom/InfoLabel
@onready var info_container: VBoxContainer = $Margin/VBox/Info

var levels: Array[MenuLevelData] = []
var current_index: int = 0
var loaded_pcks: Array[String] = []
var _music_player: AudioStreamPlayer
var _music_tween: Tween
var _current_music_data: MenuLevelData
var _music_loop_timer: float = 0.0
var _is_music_fading: bool = false
var _animating: bool = false
var _default_avatar: ImageTexture
var _detail_popup: AcceptDialog
var _import_dialog: FileDialog
var _source_popup: AcceptDialog
var _pending_download_data: MenuLevelData = null
var _pending_download_key: String = ""

@onready var refresh_btn: Button = $Margin/VBox/Header/RefreshBtn
@onready var import_btn: Button = $Margin/VBox/Header/ImportBtn
@onready var settings_btn: Button = $Margin/VBox/Header/SettingsBtn
@onready var source_label: Label = $Margin/VBox/Header/SourceLabel

enum ViewMode { CARD, LIST }
var _current_mode: ViewMode = ViewMode.CARD
@onready var view_toggle_btn: Button = $Margin/VBox/Header/ViewToggleBtn

var _list_view: ScrollContainer
var _list_container: VBoxContainer

var _slide_wrap: Control
var _panel: PanelContainer
var _texture: TextureRect

const LEVEL_LIST_PATH := "res://pck_levels/level_list.tres"
const SLIDE_DUR := 0.3
const FLY_IN_DUR := 0.5

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	_create_panels()
	_create_list_view()
	_scan_levels()
	_update_display()
	_update_user_display()
	
	UserManager.user_info_updated.connect(_update_user_display)
	
	_apply_pending_cloud_data()
	_apply_circle_avatar(avatar_rect)
	_create_import_dialog()
	# Ensure PCKDownloader singleton is initialized before any access
	PCKDownloader.ensure_instance()
	# Hide source button until remote URLs are loaded
	_update_source_label()
	# Pre-fetch remote level URLs from GAS config (non-blocking)
	_fetch_remote_urls()


func _apply_pending_cloud_data() -> void:
	var pending_json: String = CloudArchiveService.get_pending_cloud_json()
	if pending_json.is_empty():
		return
	print("[LevelManager] applying pending cloud data: ", pending_json.substr(0, 200))
	var parsed: JSON = JSON.new()
	if parsed.parse(pending_json) == OK and parsed.data is Dictionary:
		apply_save_data(parsed.data)


func _fetch_remote_urls() -> void:
	await PCKDownloader.instance.fetch_level_urls()
	print("[LevelManager] Remote level URLs loaded: ", PCKDownloader.instance.get_level_count())
	# Restore settings button state if download sources are available
	if PCKDownloader.instance.has_sources():
		_update_source_label()


func _on_view_toggle_pressed() -> void:
	if _animating:
		return
	
	_current_mode = ViewMode.LIST if _current_mode == ViewMode.CARD else ViewMode.CARD
	
	if _current_mode == ViewMode.LIST:
		_update_list()
		_slide_wrap.visible = false
		_list_view.visible = true
		left_arrow.visible = false
		right_arrow.visible = false
		counter_label.visible = false
	else:
		_slide_wrap.visible = true
		_list_view.visible = false
		left_arrow.visible = levels.size() > 1
		right_arrow.visible = levels.size() > 1
		counter_label.visible = true
		_update_display()


func _update_list() -> void:
	# 清空现有列表
	for child in _list_container.get_children():
		child.queue_free()
	
	var style := _make_panel_style()
	style.set_content_margin_all(8)
	
	for i in range(levels.size()):
		var data := levels[i]
		var btn := Button.new()
		var title_text: String = "  %d. %s" % [i + 1, data.title if data.title != "" else "未命名关卡"]
		var sid: String = data.save_id
		if not sid.is_empty():
			var prog: Dictionary = ProgressStore.get_level(sid)
			var stars: int = prog.get("stars", 0)
			var pct: int = prog.get("best_percent", 0)
			var star_str: String = ""
			for j in range(3):
				star_str += "★" if j < stars else "☆"
			title_text += "  %s %d%%" % [star_str, pct]
		btn.text = title_text
		btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size.y = 44
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# 样式
		btn.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = Color(0.15, 0.15, 0.22, 0.9)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		
		btn.pressed.connect(_on_list_item_selected.bind(i))
		_list_container.add_child(btn)


func _on_list_item_selected(index: int) -> void:
	current_index = index
	_update_display()
	_start_level()


func _on_left_arrow() -> void:
	if levels.size() <= 1 or _animating:
		return
	_animate_switch(-1)


func _on_right_arrow() -> void:
	if levels.size() <= 1 or _animating:
		return
	_animate_switch(1)


func _animate_switch(direction: int) -> void:
	_animating = true
	
	# 1. 淡出当前内容
	var tw_out := create_tween()
	tw_out.set_parallel(true)
	tw_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tw_out.tween_property(_panel, "modulate:a", 0.0, SLIDE_DUR)
	tw_out.tween_property(info_container, "modulate:a", 0.0, SLIDE_DUR * 0.6)
	
	await tw_out.finished
	
	# 2. 更新内容
	current_index = (current_index + direction + levels.size()) % levels.size()
	_update_display()
	
	# 3. 准备淡入
	_panel.modulate.a = 0.0
	info_container.modulate.a = 0.0
	
	# 4. 淡入新内容
	var tw_in := create_tween()
	tw_in.set_parallel(true)
	tw_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tw_in.tween_property(_panel, "modulate:a", 1.0, FLY_IN_DUR)
	tw_in.tween_property(info_container, "modulate:a", 1.0, FLY_IN_DUR * 0.6)
	
	await tw_in.finished
	
	_animating = false


func _on_panel_gui_input(event: InputEvent) -> void:
	if levels.is_empty() or _animating:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start_level()


func _start_level() -> void:
	# Block level start if a download is already in progress
	if _pending_download_data != null:
		info_label.text = "正在下载中，请稍候..."
		return

	var data: MenuLevelData = levels[current_index]
	var key: String = data.resource_path if data.resource_path != "" else data.title

	# Already loaded — jump straight to the scene
	if key in loaded_pcks:
		var scene: String = data.scene_path
		if scene.is_empty():
			info_label.text = "未配置场景路径"
			return
		get_tree().change_scene_to_file(scene)
		return

	# Determine how to obtain the PCK (local file vs remote download)
	var local_exists := not data.pck_path.is_empty() and FileAccess.file_exists(ProjectSettings.globalize_path(data.pck_path))
	var remote_url := PCKDownloader.instance.get_url(data.save_id)

	if local_exists:
		if not _load_pck(data.pck_path, key):
			return
	elif not remote_url.is_empty():
		# Remote URL available — try cache first, otherwise download
		if PCKDownloader.instance.is_cached(data.save_id):
			if not _load_pck(PCKDownloader.instance.get_cached_path(data.save_id), key):
				return
		else:
			_start_remote_download(data, key)
			return
	else:
		info_label.text = "未配置PCK文件"
		return

	var scene: String = data.scene_path
	if scene.is_empty():
		info_label.text = "未配置场景路径"
		return
	get_tree().change_scene_to_file(scene)


func _on_info_button() -> void:
	if levels.is_empty():
		return
	var data: MenuLevelData = levels[current_index]
	_show_detail_popup(data)


func _show_detail_popup(data: MenuLevelData) -> void:
	if _detail_popup:
		_detail_popup.queue_free()

	_detail_popup = AcceptDialog.new()
	_detail_popup.title = "关卡详情"
	_detail_popup.size = Vector2i(500, 300)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	var cover_rect := TextureRect.new()
	cover_rect.custom_minimum_size = Vector2(200, 200)
	cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover_rect.texture = data.cover
	hbox.add_child(cover_rect)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)

	var title_label := Label.new()
	title_label.text = data.title if data.title != "" else "未命名关卡"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	vbox.add_child(title_label)

	var author_label := Label.new()
	author_label.text = "作者: %s" % data.author if not data.author.is_empty() else "作者: 未知"
	author_label.add_theme_font_size_override("font_size", 14)
	author_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7, 1))
	vbox.add_child(author_label)

	var desc_label := Label.new()
	desc_label.text = data.description if not data.description.is_empty() else "暂无描述"
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	hbox.add_child(vbox)
	_detail_popup.add_child(hbox)
	add_child(_detail_popup)
	_detail_popup.popup_centered()


func _on_refresh_button_pressed() -> void:
	_scan_levels()
	current_index = 0
	_update_display()
	info_label.text = "已刷新"


func _on_import_pck_pressed() -> void:
	_import_dialog.popup_centered()


func _on_pck_file_selected(path: String) -> void:
	if path.begins_with("content://"):
		path = _copy_content_uri(path)
		if path.is_empty():
			info_label.text = "无法读取文件"
			return

	var result := _validate_pck(path)
	if result.is_empty():
		info_label.text = "无效PCK：未找到关卡场景"
		return

	var scene_path: String = result["scene_path"]
	var level_name: String = result["name"]

	var success := ProjectSettings.load_resource_pack(path)
	if not success:
		info_label.text = "PCK加载失败"
		return

	loaded_pcks.append(path)
	info_label.text = "正在加载: %s" % level_name
	get_tree().change_scene_to_file(scene_path)


func _copy_content_uri(uri: String) -> String:
	# Copy SAF content:// URI to local cache using Godot's FileAccess
	# (avoids fragile JavaClassWrapper reflection, works on Android 14+)
	var src := FileAccess.open(uri, FileAccess.READ)
	if src == null:
		push_error("SAF: failed to open content URI: %s" % uri)
		return ""

	var cache_dir := ProjectSettings.globalize_path("user://cache/imports")
	DirAccess.make_dir_recursive_absolute(cache_dir)
	var dest := cache_dir.path_join("import_%d.pck" % Time.get_unix_time_from_system())

	var dst := FileAccess.open(dest, FileAccess.WRITE)
	if dst == null:
		push_error("SAF: failed to write cache file: %s" % dest)
		return ""

	# Buffer the copy in chunks to avoid OOM on large PCKs
	var buf: PackedByteArray
	while true:
		buf = src.get_buffer(1 << 16)  # 64 KB chunks
		if buf.is_empty():
			break
		dst.store_buffer(buf)

	src.close()
	dst.close()

	if FileAccess.file_exists(dest):
		print("SAF: copied %s -> %s" % [uri, dest])
		return dest
	push_error("SAF: copy completed but file not found at %s" % dest)
	return ""


func _update_user_display() -> void:
	if UserManager.user_nickname != "" or UserManager.user_email != "":
		name_label.text = UserManager.get_display_name()
		if UserManager.has_avatar():
			avatar_rect.texture = UserManager.get_avatar_texture()
		else:
			avatar_rect.texture = _make_default_avatar()
	else:
		name_label.text = "Guest"
		avatar_rect.texture = _make_default_avatar()


var _progress_label: Label

func _ensure_progress_label() -> void:
	if _progress_label:
		return
	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 14)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_container.add_child(_progress_label)
	info_container.move_child(_progress_label, 0)


func _make_default_avatar() -> ImageTexture:
	if _default_avatar == null:
		var image := Image.create(28, 28, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.3, 0.3, 0.3, 1))
		_default_avatar = ImageTexture.create_from_image(image)
	return _default_avatar


func _apply_circle_avatar(rect: TextureRect) -> void:
	var shader: Shader = load("res://Scripts/circle_avatar.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		rect.material = mat


func _on_user_capsule_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_tree().change_scene_to_file("res://Scenes/gas_login.tscn")


func _scan_levels() -> void:
	levels.clear()
	if not ResourceLoader.exists(LEVEL_LIST_PATH):
		return
	var list := load(LEVEL_LIST_PATH)
	if list is MenuLevelList:
		levels = list.levels


func _load_pck(pck_path: String, level_key: String) -> bool:
	var global_path: String = pck_path if pck_path.is_absolute_path() else ProjectSettings.globalize_path(pck_path)
	if not FileAccess.file_exists(global_path):
		info_label.text = "PCK文件不存在"
		return false
	var success := ProjectSettings.load_resource_pack(global_path)
	if success:
		loaded_pcks.append(level_key)
		return true
	info_label.text = "PCK加载失败"
	return false


func _start_remote_download(data: MenuLevelData, level_key: String) -> void:
	_connect_download_signals()
	_pending_download_data = data
	_pending_download_key = level_key
	info_label.text = "下载中..."
	PCKDownloader.instance.download(data.save_id, PCKDownloader.instance.get_url(data.save_id))


func _on_download_progress(save_id: String, percent: float) -> void:
	info_label.text = "下载中... %d%%" % int(percent)


func _on_download_completed(save_id: String, cached_path: String) -> void:
	_disconnect_download_signals()
	var data := _pending_download_data
	var key := _pending_download_key
	_pending_download_data = null
	_pending_download_key = ""

	# Validate the completed download matches what we requested
	if data == null or save_id != data.save_id:
		print("[LevelManager] Download completed for unexpected save_id: ", save_id)
		return

	# Load the downloaded PCK
	var success := ProjectSettings.load_resource_pack(cached_path)
	if not success:
		info_label.text = "PCK加载失败"
		return
	loaded_pcks.append(key)

	var scene: String = data.scene_path
	if scene.is_empty():
		info_label.text = "未配置场景路径"
		return
	get_tree().change_scene_to_file(scene)


func _on_download_failed(save_id: String, error: String) -> void:
	_disconnect_download_signals()
	_pending_download_data = null
	_pending_download_key = ""
	info_label.text = "下载失败: %s，请在设置中切换下载源后重试" % error


func _connect_download_signals() -> void:
	if not PCKDownloader.instance.download_progress.is_connected(_on_download_progress):
		PCKDownloader.instance.download_progress.connect(_on_download_progress)
		PCKDownloader.instance.download_completed.connect(_on_download_completed)
		PCKDownloader.instance.download_failed.connect(_on_download_failed)


func _disconnect_download_signals() -> void:
	if PCKDownloader.instance.download_progress.is_connected(_on_download_progress):
		PCKDownloader.instance.download_progress.disconnect(_on_download_progress)
		PCKDownloader.instance.download_completed.disconnect(_on_download_completed)
		PCKDownloader.instance.download_failed.disconnect(_on_download_failed)


func get_save_data() -> Dictionary:
	return {
		"level_progress": ProgressStore.to_dict(),
	}


func apply_save_data(data: Dictionary) -> void:
	print("[LevelManager] apply_save_data called with: ", data)
	if data.has("level_progress"):
		print("[LevelManager] restoring level_progress: ", data["level_progress"])
		ProgressStore.from_dict(data["level_progress"])
	else:
		print("[LevelManager] no level_progress key in data")
	_update_display()
