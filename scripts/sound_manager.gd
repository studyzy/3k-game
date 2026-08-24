extends Node
## 声音管理（autoload: SoundManager）

var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var bgm_volume: float = 0.5
var sfx_volume: float = 0.8
var _current_bgm: String = ""


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = linear_to_db(bgm_volume)
	add_child(_bgm_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.volume_db = linear_to_db(sfx_volume)
	add_child(_sfx_player)


func play_bgm(name: String) -> void:
	if _current_bgm == name:
		return
	_current_bgm = name
	var path := "res://assets/audio/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return
	_bgm_player.stream = load(path)
	_bgm_player.play()


func stop_bgm() -> void:
	_bgm_player.stop()
	_current_bgm = ""


func pause_bgm() -> void:
	_bgm_player.stream_paused = true


func resume_bgm() -> void:
	_bgm_player.stream_paused = false


func set_bgm_volume(vol: float) -> void:
	bgm_volume = clampf(vol, 0.0, 1.0)
	_bgm_player.volume_db = linear_to_db(bgm_volume)


func play_ui(name: String) -> void:
	var path := "res://assets/audio/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return
	_sfx_player.stream = load(path)
	_sfx_player.play()
