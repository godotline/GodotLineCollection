class_name PCKLoader

enum Phase { IDLE, VERIFY_PCK, LOAD_PCK }

var phase: Phase = Phase.IDLE
var _verification_ui: ColorRect
var _info_label: Label
var _load_data: MenuLevelData = null
var _load_key: String = ""
var _load_pck_path: String = ""
var _pending_data: MenuLevelData = null
var _pending_key: String = ""
var _verify_thread: Thread = null
var _verify_busy: bool = false

signal load_ready(level_data: MenuLevelData, scene_path: String)
signal load_failed(message: String)
signal pck_loaded(level_key: String)

func setup(verification_ui: ColorRect, info_label: Label) -> void:
	_verification_ui = verification_ui
	_info_label = info_label

func is_busy() -> bool:
	return phase != Phase.IDLE or _pending_data != null or _verify_busy

func start_level(data: MenuLevelData) -> void:
	if is_busy():
		return

	var key: String = data.resource_path if data.resource_path != "" else data.title

	var pck_path := _resolve_pck_path(data)
	if pck_path.is_empty() and PCKDownloader.instance.is_cached(data.save_id):
		pck_path = PCKDownloader.instance.get_cached_path(data.save_id)

	if pck_path.is_empty():
		var remote_url := PCKDownloader.instance.get_url(data.save_id)
		if not remote_url.is_empty():
			_start_download(data, key)
		else:
			load_failed.emit("未配置PCK文件")
		return

	_start_loading_flow(data, key, pck_path)

func poll_verify() -> void:
	if not _verify_busy:
		return
	if _verify_thread.is_alive():
		return
	_verify_busy = false
	var result: Dictionary = _verify_thread.wait_to_finish()
	_verify_thread = null
	if result.ok:
		_proceed_to_load()
	else:
		_on_verify_failed()

func cleanup() -> void:
	phase = Phase.IDLE
	_load_data = null
	_load_key = ""
	_load_pck_path = ""
	_pending_data = null
	_pending_key = ""
	if _verification_ui:
		_verification_ui.visible = false
	if _verify_busy:
		_verify_busy = false
		if _verify_thread != null:
			_verify_thread.wait_to_finish()
			_verify_thread = null
	_disconnect_download_signals()

func _resolve_pck_path(data: MenuLevelData) -> String:
	var local_path := ProjectSettings.globalize_path(data.pck_path)
	if not data.pck_path.is_empty() and FileAccess.file_exists(local_path):
		return data.pck_path
	return ""

func _load_pck(pck_path: String, level_key: String) -> bool:
	var global_path: String = pck_path if pck_path.is_absolute_path() else ProjectSettings.globalize_path(pck_path)
	if not FileAccess.file_exists(global_path):
		print("[PCKLoader] PCK file does not exist: %s" % global_path)
		_info_label.text = "PCK文件不存在"
		return false
	var success := ProjectSettings.load_resource_pack(global_path)
	if success:
		print('[PCKLoader] loaded PCK "%s" (key: %s)' % [global_path, level_key])
		pck_loaded.emit(level_key)
		return true
	print("[PCKLoader] FAILED to load PCK: %s" % global_path)
	_info_label.text = "PCK加载失败"
	return false

func _start_loading_flow(data: MenuLevelData, key: String, pck_path: String) -> void:
	_load_data = data
	_load_key = key
	_load_pck_path = pck_path
	_verification_ui.visible = true
	var expected_md5 := PCKDownloader.instance.get_md5(data.save_id)
	if expected_md5.is_empty():
		_proceed_to_load()
	else:
		phase = Phase.VERIFY_PCK
		_start_verify(pck_path, expected_md5)

func _start_verify(pck_path: String, expected_md5: String) -> void:
	_verify_busy = true
	_verify_thread = Thread.new()
	_verify_thread.start(_verify_worker.bind(pck_path, expected_md5))

static func _verify_worker(pck_path: String, expected_md5: String) -> Dictionary:
	var actual_md5 := _compute_file_md5(pck_path)
	if actual_md5.is_empty():
		return {"ok": false, "md5": "", "pck_path": pck_path}
	var ok := actual_md5.to_lower() == expected_md5.to_lower()
	return {"ok": ok, "md5": actual_md5, "pck_path": pck_path}

func _on_verify_failed() -> void:
	var data := _load_data
	var remote_url := PCKDownloader.instance.get_url(data.save_id)
	if not remote_url.is_empty():
		var cached_path := PCKDownloader.instance.get_cached_path(data.save_id)
		if not cached_path.is_empty() and FileAccess.file_exists(cached_path):
			DirAccess.remove_absolute(cached_path)
		_cleanup_state()
		_start_download(data, _load_key)
	else:
		print("[PCKLoader] Integrity check failed for %s, no remote URL, loading anyway" % data.save_id)
		_proceed_to_load()

func _proceed_to_load() -> void:
	_verification_ui.visible = false
	phase = Phase.LOAD_PCK
	call_deferred("_perform_pck_load")

func _perform_pck_load() -> void:
	if phase != Phase.LOAD_PCK:
		return
	if not _load_pck(_load_pck_path, _load_key):
		_cleanup_state()
		load_failed.emit("PCK加载失败")
		return

	_verification_ui.visible = false
	var scene_path := _load_data.scene_path
	CustomLoadScreen.pending_cover = _load_data.cover
	CustomLoadScreen.pending_title = _load_data.title
	var data := _load_data
	_cleanup_state()
	load_ready.emit(data, scene_path)

func _cleanup_state() -> void:
	phase = Phase.IDLE
	_load_data = null
	_load_key = ""
	_load_pck_path = ""
	_verification_ui.visible = false
	if _verify_busy:
		_verify_busy = false
		if _verify_thread != null:
			_verify_thread.wait_to_finish()
			_verify_thread = null

func _start_download(data: MenuLevelData, key: String) -> void:
	_pending_data = data
	_pending_key = key
	_info_label.text = "下载中..."
	_connect_download_signals()
	PCKDownloader.instance.download(data.save_id, PCKDownloader.instance.get_url(data.save_id))

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

func _on_download_progress(save_id: String, percent: float) -> void:
	_info_label.text = "下载中... %d%%" % int(percent)

func _on_download_completed(save_id: String, cached_path: String) -> void:
	_disconnect_download_signals()
	var data := _pending_data
	var key := _pending_key
	_pending_data = null
	_pending_key = ""
	if data == null or save_id != data.save_id:
		print("[PCKLoader] Download completed for unexpected save_id: ", save_id)
		return
	_start_loading_flow(data, key, cached_path)

func _on_download_failed(save_id: String, error: String) -> void:
	_disconnect_download_signals()
	_pending_data = null
	_pending_key = ""
	_info_label.text = "下载失败: %s，请在设置中切换下载源后重试" % error

static func _compute_file_md5(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("PCK MD5: failed to open ", path)
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	while file.get_position() < file.get_length():
		ctx.update(file.get_buffer(1 << 16))
	var hash_bytes := ctx.finish()
	file.close()
	var hex := PackedStringArray()
	for b in hash_bytes:
		hex.append("%02x" % b)
	return "".join(hex)
