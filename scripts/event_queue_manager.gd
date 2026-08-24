class_name EventQueueManager
extends RefCounted
## 事件串行队列（对应 Unity EventQueueManager）

var _event_queue: Array = []
var _is_running := false


func add_event(event_action: Callable) -> void:
	_event_queue.append(event_action)


func start() -> void:
	if _is_running:
		return
	_is_running = true
	_execute_next()


func _execute_next() -> void:
	if not _event_queue.is_empty():
		var next_event: Callable = _event_queue[0]
		_event_queue.remove_at(0)
		next_event.call(_execute_next)
	else:
		_is_running = false


func clear() -> void:
	_event_queue.clear()
	_is_running = false
