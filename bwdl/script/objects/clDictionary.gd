extends Resource
class_name DictionaryInfo

var _dic: Dictionary;

func _init(dic: Dictionary) -> void :
	_dic = dic;

func get_value(key):
	if _dic.has(key):
		return _dic[key];
	return null;
	
func set_value(key, value):
	_dic[key] = value;

func keys():
	return _dic.keys();

func values():
	return _dic.values();
