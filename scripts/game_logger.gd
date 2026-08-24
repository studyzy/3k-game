extends Node
## 游戏日志（autoload: GameLogger，对应 Unity GameLogger）

var _log_path: String = ""
var _log_file: FileAccess = null
var _max_size := 1024 * 1024  # 1MB 轮转
var _size := 0


func _ready() -> void:
	var dir := "user://Logs"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var time_str := Time.get_datetime_string_from_system().replace(":", "-")
	_log_path = "%s/log_%s.txt" % [dir, time_str]
	_log_file = FileAccess.open(_log_path, FileAccess.WRITE)
	log_msg("======== 游戏启动 %s ========" % Time.get_datetime_string_from_system())


func log_msg(msg: String) -> void:
	var line := "[%s] %s\n" % [Time.get_time_string_from_system(), msg]
	print(msg)
	if _log_file != null:
		_log_file.store_string(line)
		_size += line.length()
		if _size > _max_size:
			_rotate()


func log_warn(msg: String) -> void:
	log_msg("[警告] " + msg)


func log_err(msg: String) -> void:
	log_msg("[错误] " + msg)


func get_log_file_path() -> String:
	return _log_path


func close_logger() -> void:
	if _log_file != null:
		_log_file.close()
		_log_file = null


func _rotate() -> void:
	if _log_file != null:
		_log_file.close()
	var old := _log_path.replace(".txt", "_old.txt")
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)
	DirAccess.rename_absolute(_log_path, old)
	_log_file = FileAccess.open(_log_path, FileAccess.WRITE)
	_size = 0
