class_name Alliance
extends RefCounted
## 同盟关系

var countryId: int = 0
var months: int = 0

func _init(p_countryId: int = 0, p_months: int = 0) -> void:
	countryId = p_countryId
	months = p_months
