class_name UnitData
extends RefCounted
## 大地图单位（战争/战略地图上的部队）

enum UnitState { NONE, RETREAT, IDLE, RETIRE, CAPTIVE, DEAD, TRAPPED }

var genID: int = 0
var isPlayer: bool = false
var isCommander: bool = false
var moveBonus: int = 0       # 机动点（≤30）
var trappedDay: int = 0
var isMoved: bool = false
var unitState: int = UnitState.NONE
var arrayPos: Vector2i = Vector2i.ZERO


func get_state_name() -> String:
	match unitState:
		UnitState.NONE: return ""
		UnitState.RETREAT: return "撤退"
		UnitState.IDLE: return "待机"
		UnitState.RETIRE: return "下野"
		UnitState.CAPTIVE: return "被俘"
		UnitState.DEAD: return "阵亡"
		UnitState.TRAPPED: return "被陷"
	return ""
