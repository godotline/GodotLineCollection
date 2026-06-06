# PCK Integrity Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Verify PCK file integrity via MD5 hash before loading, re-downloading on cache corruption.

**Architecture:** Extend `PCKDownloader._filename_map` to support Dictionary entries with `filename`+`md5`. Add MD5 computation in `LevelManager` using `HashingContext`. Every `_start_level()` call verifies integrity before loading.

**Tech Stack:** Godot 4.6 GDScript, HashingContext (built-in), GAS ConfigService

---

### Task 1: Add `_resolve_filename()` and `get_md5()` to PCKDownloader

**Files:**
- Modify: `Scripts/PCKDownloader.gd`

- [ ] **Step 1: Add `_resolve_filename()` helper and `get_md5()` method**

Insert after the `download_completed` signal (line 17):

```gdscript
## Resolve the filename from _filename_map entry, supporting both
## String (legacy) and Dictionary (with "filename" key) formats.
static func _resolve_filename(entry) -> String:
	if entry is String:
		return entry
	if entry is Dictionary:
		return entry.get("filename", "")
	return ""
```

And add `get_md5()` after `get_url()` (after line 123):

```gdscript
func get_md5(save_id: String) -> String:
	"""
	Look up the expected MD5 hash for a given save_id from the remote config.
	Returns empty string if not available (integrity check skipped).
	"""
	var entry = _filename_map.get(save_id)
	if entry is Dictionary:
		return entry.get("md5", "")
	return ""
```

- [ ] **Step 2: Refactor `get_url()` to use `_resolve_filename()`**

Replace the current body of `get_url()` (lines 104-123) with:

```gdscript
func get_url(save_id: String) -> String:
	"""
	Look up the full download URL for a given save_id by concatenating
	the current source's base_url with the level's filename.
	Returns empty string if not found or no source selected.
	"""
	if _sources.is_empty() or _current_source_index >= _sources.size():
		return ""
	var entry = _filename_map.get(save_id)
	var filename := _resolve_filename(entry)
	if filename.is_empty():
		return ""
	var source: Dictionary = _sources[_current_source_index]
	var base: String = source.get("base_url", "")
	if base.is_empty():
		return ""
	# Ensure base_url ends with /
	if not base.ends_with("/"):
		base += "/"
	return base + filename
```

- [ ] **Step 3: Commit**

```bash
git add Scripts/PCKDownloader.gd
git commit -m "feat(pck): support Dictionary entries in _filename_map with MD5"
```

---

### Task 2: Add MD5 computation helper in LevelManager

**Files:**
- Modify: `Scripts/LevelManager.gd`

- [ ] **Step 1: Add `_compute_file_md5()` static method**

Insert after `_disconnect_download_signals()` (after line 827):

```gdscript
## Compute MD5 hex digest of a file at the given absolute path.
## Uses HashingContext with 64KB chunked reading.
## Returns empty string on error.
static func _compute_file_md5(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("PCK MD5: failed to open ", path)
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	while file.get_position() < file.get_length():
		ctx.update(file.get_buffer(1 << 16))  # 64 KB chunks
	var hash_bytes := ctx.finish()
	file.close()
	var hex := PackedStringArray()
	for b in hash_bytes:
		hex.append("%02x" % b)
	return "".join(hex)


## Verify PCK file integrity against remote configuration.
## Returns true if: no MD5 configured (skip), or MD5 matches.
## Returns false if MD5 is configured but doesn't match.
func _verify_pck_integrity(pck_path: String, save_id: String) -> bool:
	var expected_md5 := PCKDownloader.instance.get_md5(save_id)
	if expected_md5.is_empty():
		return true  # No remote MD5 configured, skip check
	
	var global_path := pck_path if pck_path.is_absolute_path() else ProjectSettings.globalize_path(pck_path)
	if not FileAccess.file_exists(global_path):
		return false
	
	var actual_md5 := _compute_file_md5(global_path)
	if actual_md5.is_empty():
		return false
	
	var match := actual_md5.to_lower() == expected_md5.to_lower()
	if not match:
		print("[LevelManager] Integrity check FAILED for %s: expected %s, got %s" % [save_id, expected_md5, actual_md5])
	return match
```

- [ ] **Step 2: Commit**

```bash
git add Scripts/LevelManager.gd
git commit -m "feat(level): add MD5 computation and integrity check helpers"
```

---

### Task 3: Rewrite `_start_level()` with integrity checks

**Files:**
- Modify: `Scripts/LevelManager.gd`

- [ ] **Step 1: Replace `_start_level()` body**

Replace the entire `_start_level()` function (lines 534-575) with:

```gdscript
func _start_level() -> void:
	# Block level start if a download is already in progress
	if _pending_download_data != null:
		info_label.text = "正在下载中，请稍候..."
		return
	
	var data: MenuLevelData = levels[current_index]
	var key: String = data.resource_path if data.resource_path != "" else data.title
	
	# Case 1: Local PCK file
	var local_path := ProjectSettings.globalize_path(data.pck_path)
	var local_exists := not data.pck_path.is_empty() and FileAccess.file_exists(local_path)
	if local_exists:
		if _verify_and_load_pck(data.pck_path, key, data.save_id):
			_switch_to_scene(data)
		elif not PCKDownloader.instance.get_url(data.save_id).is_empty():
			# Integrity check failed, remote source available → re-download
			_start_remote_download(data, key)
		else:
			# Integrity check failed, no remote source → try loading anyway
			print("[LevelManager] Local PCK integrity check failed for %s, no remote URL, loading anyway" % data.save_id)
			if _load_pck(data.pck_path, key):
				_switch_to_scene(data)
		return
	
	# Case 2: Cached PCK from remote
	var remote_url := PCKDownloader.instance.get_url(data.save_id)
	if not remote_url.is_empty():
		if PCKDownloader.instance.is_cached(data.save_id):
			var cached_path := PCKDownloader.instance.get_cached_path(data.save_id)
			if _verify_and_load_pck(cached_path, key, data.save_id):
				_switch_to_scene(data)
			else:
				# Cache corrupted, delete and re-download
				print("[LevelManager] Cache integrity failed for %s, re-downloading" % data.save_id)
				DirAccess.remove_absolute(cached_path)
				_start_remote_download(data, key)
		else:
			_start_remote_download(data, key)
		return
	
	# Case 3: No PCK available at all
	info_label.text = "未配置PCK文件"
```

- [ ] **Step 2: Add `_verify_and_load_pck()` and `_switch_to_scene()` helper methods**

Insert after `_load_pck()` (after line 768):

```gdscript
## Verify integrity then load PCK. Returns true if loaded successfully.
func _verify_and_load_pck(pck_path: String, level_key: String, save_id: String) -> bool:
	if not _verify_pck_integrity(pck_path, save_id):
		return false
	if not _load_pck(pck_path, level_key):
		return false
	return true


## Switch to level scene. Returns false if scene_path is empty.
func _switch_to_scene(data: MenuLevelData) -> bool:
	var scene: String = data.scene_path
	if scene.is_empty():
		info_label.text = "未配置场景路径"
		return false
	get_tree().change_scene_to_file(scene)
	return true
```

- [ ] **Step 3: Commit**

```bash
git add Scripts/LevelManager.gd
git commit -m "feat(level): add integrity checks to _start_level() flow"
```

---

### Task 4: Add integrity check in `_on_download_completed()`

**Files:**
- Modify: `Scripts/LevelManager.gd`

- [ ] **Step 1: Replace `_on_download_completed()` body**

Replace the existing `_on_download_completed()` function (lines 783-806) with:

```gdscript
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
	
	# Verify downloaded file integrity
	var expected_md5 := PCKDownloader.instance.get_md5(save_id)
	if not expected_md5.is_empty():
		var actual_md5 := _compute_file_md5(cached_path)
		if actual_md5.to_lower() != expected_md5.to_lower():
			print("[LevelManager] Downloaded PCK integrity check FAILED for %s" % save_id)
			DirAccess.remove_absolute(cached_path)
			info_label.text = "文件完整性校验失败，请联系管理员"
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
```

- [ ] **Step 2: Commit**

```bash
git add Scripts/LevelManager.gd
git commit -m "feat(level): verify MD5 of downloaded PCK before loading"
```

---

### Task 5: Update `_on_pck_file_selected()` to use new flow

**Files:**
- Modify: `Scripts/LevelManager.gd`

This is the import-a-local-PCK-via-FileDialog path. It doesn't go through `_start_level()` and has no save_id to check against. No changes needed — the current flow (validate → load → jump) is correct for local imports.

- [ ] **Step 1: Verify no change needed**

Read `_on_pck_file_selected()` (lines 644-666) — it uses `_validate_pck()` (structure check) and `ProjectSettings.load_resource_pack()` directly, with no MD5 check. This is correct because imported PCKs have no remote config entry.

- [ ] **Step 2: Skip / no changes**

No commit needed for this task.

---
