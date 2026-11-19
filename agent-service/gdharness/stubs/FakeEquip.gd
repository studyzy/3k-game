extends Reference
var _name = ""
var _brief = ""

func _init(n = "", b = ""):
	_name = n
	_brief = b

func name(): return _name
func get_attrs_brief(): return _brief
