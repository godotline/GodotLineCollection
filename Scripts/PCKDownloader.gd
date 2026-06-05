class_name PCKDownloader
extends RefCounted

## Singleton instance — initialized in _init(), used as PCKDownloader.instance
static var instance: PCKDownloader

func _init() -> void:
	instance = self

## Emitted periodically during download with progress percentage (0-100).
signal download_progress(save_id: String, percent: float)
## Emitted when a download finishes successfully.
signal download_completed(save_id: String, cached_path: String)
## Emitted when a download fails for any reason.
signal download_failed(save_id: String, error: String)

## Cached mapping of save_id -> download_url from GAS ConfigService.
var _url_map: Dictionary = {}
## Active HTTPRequest node, null when idle.
var _http: HTTPRequest = null
## The save_id currently being downloaded (empty when idle).
var _downloading_save_id: String = ""
## The absolute destination path for the current download.
var _download_dest: String = ""

const CACHE_DIR: String = "user://pck_cache/"
const DOWNLOAD_TIMEOUT_MS := 120_000


func fetch_level_urls() -> Dictionary:
	"""
	Fetch remote config via ConfigService and cache the level_urls mapping.
	Returns _url_map (empty on failure).
	"""
	_url_map.clear()

	var config_service := ConfigService.new()
	var resp = await config_service.get_config()

	if resp is GASError:
		print("[PCKDownloader] ConfigService returned error: ", resp.message)
		return _url_map

	if not resp.is_success():
		print("[PCKDownloader] Config fetch unsuccessful, code: ", resp.code)
		return _url_map

	var data = resp.data
	if typeof(data) != TYPE_DICTIONARY:
		print("[PCKDownloader] Config data is not a Dictionary")
		return _url_map

	if not data.has("level_urls"):
		print("[PCKDownloader] No level_urls key in config data")
		return _url_map

	var level_urls = data["level_urls"]
	if typeof(level_urls) != TYPE_DICTIONARY:
		print("[PCKDownloader] level_urls is not a Dictionary, got: ", typeof(level_urls))
		return _url_map

	_url_map = level_urls
	print("[PCKDownloader] Loaded %d level URL(s)" % _url_map.size())
	return _url_map


func get_url(save_id: String) -> String:
	"""
	Look up the download URL for a given save_id.
	Returns empty string if not found.
	"""
	return _url_map.get(save_id, "")


func is_cached(save_id: String) -> bool:
	"""
	Check whether the PCK file for save_id exists in the local cache.
	"""
	return FileAccess.file_exists(get_cached_path(save_id))


func get_cached_path(save_id: String) -> String:
	"""
	Return the absolute path where the cached PCK file should be stored.
	The file does not need to exist yet.
	"""
	var cache_dir := ProjectSettings.globalize_path(CACHE_DIR)
	return cache_dir.path_join(save_id + ".pck")


func download(save_id: String, url: String) -> void:
	"""
	Begin downloading a PCK file from url. The download runs asynchronously;
	connect to download_progress / download_completed / download_failed for updates.
	"""
	_do_download(save_id, url)


func cancel_download() -> void:
	"""
	Cancel any in-progress HTTP request and clean up.
	"""
	var http := _http
	_http = null
	_downloading_save_id = ""
	_download_dest = ""
	if http != null and is_instance_valid(http):
		http.cancel_request()
		http.queue_free()
		print("[PCKDownloader] Download cancelled")


func _do_download(save_id: String, url: String) -> void:
	# Cancel any existing download first
	cancel_download()

	# Validate URL
	if url.is_empty() or not (url.begins_with("http://") or url.begins_with("https://")):
		var error_msg := "Invalid download URL: " + url
		print("[PCKDownloader] ", error_msg)
		download_failed.emit(save_id, error_msg)
		return

	_downloading_save_id = save_id
	_download_dest = get_cached_path(save_id)

	# Ensure the cache directory exists
	var cache_dir_global := ProjectSettings.globalize_path(CACHE_DIR)
	if not DirAccess.dir_exists_absolute(cache_dir_global):
		var mk_err := DirAccess.make_dir_recursive_absolute(cache_dir_global)
		if mk_err != OK:
			print("[PCKDownloader] Failed to create cache directory: ", cache_dir_global)
			download_failed.emit(save_id, "Failed to create cache directory")
			_cleanup_download()
			return

	# Create HTTPRequest node
	var http := HTTPRequest.new()
	_http = http

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		print("[PCKDownloader] No SceneTree available")
		download_failed.emit(save_id, "No SceneTree available")
		_cleanup_download()
		return

	tree.root.add_child.call_deferred(http)
	await http.tree_entered

	# Start the GET request
	var req_err := http.request(url, [], HTTPClient.METHOD_GET)
	if req_err != OK:
		print("[PCKDownloader] Failed to start HTTP request: error ", req_err)
		download_failed.emit(save_id, "HTTP request failed to start")
		_cleanup_download()
		return

	print("[PCKDownloader] Downloading %s from %s" % [save_id, url])

	# Connect to request_completed signal to know when the download finishes
	var is_done := false
	var result: Array = []

	http.request_completed.connect(func(_res: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray):
		result = [_res, _code, _headers, _body]
		is_done = true
	)

	# Poll for download progress each frame (with timeout)
	var start_time := Time.get_ticks_msec()
	while not is_done:
		if not is_instance_valid(http):
			return

		# Check for timeout
		if Time.get_ticks_msec() - start_time > DOWNLOAD_TIMEOUT_MS:
			var error_msg := "Download timed out after %d seconds" % (DOWNLOAD_TIMEOUT_MS / 1000)
			print("[PCKDownloader] ", error_msg)
			download_failed.emit(save_id, error_msg)
			_cleanup_download()
			return

		var body_size := http.get_body_size()
		var downloaded := http.get_downloaded_bytes()

		if body_size > 0:
			var percent := clampf(float(downloaded) / float(body_size) * 100.0, 0.0, 100.0)
			download_progress.emit(save_id, percent)

		await tree.process_frame

	if not is_instance_valid(http):
		return

	var result_code: int = result[0]
	var response_code: int = result[1]
	var body_bytes: PackedByteArray = result[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		var error_msg := "Download failed (result=%d, response=%d)" % [result_code, response_code]
		print("[PCKDownloader] ", error_msg)
		download_failed.emit(save_id, error_msg)
		_cleanup_download()
		return

	if response_code != 200:
		var error_msg := "Download failed: HTTP %d" % response_code
		print("[PCKDownloader] ", error_msg)
		download_failed.emit(save_id, error_msg)
		_cleanup_download()
		return

	# Write downloaded bytes to the cache file
	var file := FileAccess.open(_download_dest, FileAccess.WRITE)
	if file == null:
		var error_msg := "Failed to write file: " + _download_dest
		print("[PCKDownloader] ", error_msg)
		download_failed.emit(save_id, error_msg)
		_cleanup_download()
		return

	file.store_buffer(body_bytes)
	file.close()

	print("[PCKDownloader] Download completed: %s -> %s (%d bytes)" % [save_id, _download_dest, body_bytes.size()])
	download_completed.emit(save_id, _download_dest)
	_cleanup_download()


func _cleanup_download() -> void:
	"""
	Free the HTTPRequest node and reset download state.
	Safe to call multiple times.
	"""
	if _http != null and is_instance_valid(_http):
		_http.queue_free()
	_http = null
	_downloading_save_id = ""
	_download_dest = ""
