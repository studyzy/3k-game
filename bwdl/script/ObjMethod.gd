extends Resource
class_name ObjMethod

var method = "";
var obj: Object = null;

func excute():
	obj.call(method);
