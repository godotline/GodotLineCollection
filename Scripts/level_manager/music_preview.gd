class_name MusicPreview
extends Node

var player: AudioStreamPlayer
var current_data: MenuLevelData = null
var _tween: Tween = null
var _timer: SceneTreeTimer = null
var _is_fading: bool = false

func _init(parent: Node) -> void:
	parent.add_child(self)
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	parent.add_child(player)

func play(data: MenuLevelData) -> void:
	if data == null or data.music == null:
		stop()
		current_data = null
		return
	if current_data == data and player.playing:
		return

	current_data = data
	player.stream = data.music

	if data.music_start > 0:
		player.play(data.music_start)
	else:
		player.play()

	if data.music_fade_in > 0:
		player.volume_db = -80.0
		_fade_in(data.music_fade_in)
	else:
		player.volume_db = 0.0

	_setup_loop(data)

func stop() -> void:
	if _tween:
		_tween.kill()
	if current_data and current_data.music_fade_out > 0:
		_is_fading = true
		_tween = create_tween()
		_tween.tween_property(player, "volume_db", -80.0, current_data.music_fade_out)
		_tween.tween_callback(_on_fade_out_complete)
	else:
		player.stop()
		_is_fading = false

func _fade_in(duration: float) -> void:
	if _tween:
		_tween.kill()
	_is_fading = false
	_tween = create_tween()
	_tween.tween_property(player, "volume_db", 0.0, duration)

func _on_fade_out_complete() -> void:
	player.stop()
	_is_fading = false

func _setup_loop(data: MenuLevelData) -> void:
	if _timer and _timer.timeout.is_connected(_on_segment_end):
		_timer.timeout.disconnect(_on_segment_end)
	if data.music_duration > 0:
		_timer = create_timer(data.music_duration - data.music_fade_out)
		_timer.timeout.connect(_on_segment_end)

func _on_segment_end() -> void:
	if current_data == null:
		return
	stop()
	await create_timer(current_data.music_fade_out).timeout
	if current_data:
		play(current_data)

func process(delta: float) -> void:
	if current_data and current_data.music_duration <= 0:
		if player.playing and not _is_fading:
			var remaining := player.stream.get_length() - player.get_playback_position()
			if remaining <= current_data.music_fade_out:
				stop()
				await create_timer(current_data.music_fade_out).timeout
				if current_data:
					play(current_data)

static func create_timer(time: float) -> SceneTreeTimer:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.create_timer(time)

func cleanup() -> void:
	if _tween:
		_tween.kill()
	_tween = null
	if _timer:
		if _timer.timeout.is_connected(_on_segment_end):
			_timer.timeout.disconnect(_on_segment_end)
		_timer = null
	if player:
		player.stop()
	current_data = null
	_is_fading = false
