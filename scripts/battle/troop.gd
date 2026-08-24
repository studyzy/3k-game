class_name TroopData
extends RefCounted
## 战术战斗单位（对应 Unity TroopData）

enum TroopType { CAPTAIN, CAVALRY, ARCHER, INFANTRY }
enum TroopState { FORWARD, IDLE, BACK_WARD, OUTFLANK, EXIT }

var troopType: int = TroopType.INFANTRY
var troopState: int = TroopState.FORWARD
var health: int = 300
var generalID: int = 0
var isPlayer: bool = false
var index: int = 0
var attackPower: int = 0
var defensePower: int = 0
var actBonus: int = 1
var face: int = 0
var arrayPos: Vector2i = Vector2i.ZERO


func is_captain() -> bool:
	return troopType == TroopType.CAPTAIN


## 初始化攻防（对应 TroopData.InitPower）
func init_power(general: General, terrain: int) -> void:
	if is_captain():
		attackPower = general.get_attack_power()
		defensePower = general.get_defend_power()
	else:
		attackPower = (general.lead * 2 + general.force) / 3 + (general.lead + general.force) * (general.level - 1) / 25
		defensePower = (general.lead * 2 + general.wisdom) / 3 + (general.lead + general.wisdom) * (general.level - 1) / 25
		# 技能系数
		if general.has_skill(3, 7):  # 军魂
			attackPower += attackPower / 5
			defensePower += defensePower / 5
		if general.has_skill(3, 8):  # 军神
			attackPower += attackPower / 4
			defensePower += defensePower / 4
		# 兵种修正
		if troopType == TroopType.ARCHER:
			attackPower = attackPower * 2 / 3
			defensePower = defensePower * 4 / 5
		elif troopType == TroopType.INFANTRY:
			attackPower = attackPower * 4 / 5
			defensePower = defensePower * 6 / 5
		# 地形系数
		var tef := _get_tef(terrain, general)
		attackPower = int(attackPower * tef)
		defensePower = int(defensePower * tef)
		# 攻城/守城
		if terrain == 8:
			if general.has_skill(3, 3):  # 攻城
				attackPower += attackPower / 5
			if general.has_skill(3, 4):  # 守城
				defensePower += defensePower / 5
			defensePower += defensePower / 2
		else:
			if general.has_skill(3, 1):  # 奇袭
				attackPower += attackPower / 7
			if general.has_skill(3, 2):  # 铁壁
				defensePower += defensePower / 7


func _get_tef(terrain: int, general: General) -> float:
	# 地形攻防系数：平原/山/水
	var idx := 0
	if terrain == 10 or terrain == 11 or terrain == 12:
		idx = 1
	elif terrain == 9 or terrain == 15:
		idx = 2
	var adapt: int = general.army[idx] if idx < general.army.size() else 0
	return TextLibrary.TOP_INF[clampi(adapt, 0, 3)]


## 初始化行动次数
func init_act_bonus() -> void:
	if troopType == TroopType.CAPTAIN or troopType == TroopType.CAVALRY:
		actBonus = 2
	else:
		actBonus = 1


## 伤害计算（对应 Troop.CalculateDamage）
func calculate_damage() -> int:
	var damage := maxi(attackPower, health / 20)
	if health < 200:
		damage = int(damage * health / 200.0)
	damage = maxi(damage, 1)
	return damage


## 受到伤害（对应 Troop.BattleHurtCalculate）
func battle_hurt_calculate(attacker: TroopData, general: General, defender_general: General, is_captain: bool) -> int:
	var damage := attacker.calculate_damage()
	if attacker.troopType == TroopType.ARCHER and BattleManager._tactic_active("火矢", attacker.isPlayer):
		damage = int(damage * 5 / 3)
	if attacker.troopType == TroopType.ARCHER and BattleManager._tactic_active("连弩", attacker.isPlayer):
		damage = int(damage * 2 / 3)
	# 特技兵圣减半
	if defender_general != null and defender_general.has_skill(3, 9):
		damage /= 2
	# 防御系数
	var def_index := defensePower / 150.0 * TextLibrary.HJ[clampi(defensePower - 1, 0, 499)]
	damage = int(damage / (def_index + 1))
	if is_captain:
		damage /= 3
	damage = maxi(damage, 1)
	damage = mini(damage, health)
	return damage
