class_name Weapon
extends RefCounted
## 武器类（含防具，kind==3 为防具）

var weaponID: int = 0
var weaponName: String = ""
var price: int = 0
var property: int = 0      # 属性加成
var weight: int = 0
var kind: int = 0          # 3=防具
var isUnique: bool = false
var smithy: int = 0        # 所在武器铺位掩码


## 单挑时可掉落武器
func can_seized() -> bool:
	return weaponID in [5, 6, 7, 14, 15, 21, 23, 30, 31]


static func from_dict(d: Dictionary) -> Weapon:
	var w := Weapon.new()
	w.weaponID = int(d.get("weaponID", 0))
	w.weaponName = str(d.get("weaponName", ""))
	w.price = int(d.get("price", 0))
	w.property = int(d.get("property", 0))
	w.weight = int(d.get("weight", 0))
	w.kind = int(d.get("kind", 0))
	w.isUnique = bool(d.get("isUnique", false))
	w.smithy = int(d.get("smithy", 0))
	return w


func to_dict() -> Dictionary:
	return {
		"weaponID": weaponID, "weaponName": weaponName, "price": price,
		"property": property, "weight": weight, "kind": kind,
		"isUnique": isUnique, "smithy": smithy,
	}
