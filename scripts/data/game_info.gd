extends Node
## 全局游戏状态（autoload: GameInfo）

enum GameState {
	NONE, GAME_START, PLAYING, PLAYER_TURN, AI_TURN, GAME_OVER, GAME_WIN,
	INHERIT, TRUCE, BRIBE,
	PLAYER_VS_AI, AI_VS_PLAYER, OCCUPY, AI_ATTACK, AI_WIN, AI_LOSE,
	TAX, HARVEST, REBEL,
	DROUGHT, FLOOD, PLAGUE, LOCUST_PLAGUE, TURMOIL, PLUNDER,
}

enum TaskType {
	NONE, MOVE, MOVE_DENY, OVER_MOVE, MOVE_PREFECT, ATTACK, ATTACK_DENY, OVER_ATTACK,
	CONSCRIPT, ASSIGN, TRANSPORT, TRANSPORT_DENY, END, SEARCH, SEARCH_MONEY, SEARCH_FOOD,
	SEARCH_TREASURE, SEARCH_GENERAL, SEARCH_NOTHING, EMPLOY, EMPLOY_SUCCESS, EMPLOY_DENY,
	EMPLOY_NOTHING, OVER_EMPLOY, REWARD, REWARD_DENY, APPOINT, APPOINT_DENY, LACK, RECLAIM,
	OVER_RECLAIM, MERCANTILE, OVER_MERCANTILE, TAME, OVER_TAME, PATROL, OVER_PATROL, TRUCE,
	OVER_TRUCE, TRUCE_SELECT, ALIENATE, INTELLIGENCE, BRIBE, SHOP, LACK_SHOP, SMITHY,
	LACK_SMITHY, SCHOOL, LACK_SCHOOL, SCHOOL_DENY, HOSPITAL, LACK_HOSPITAL, HOSPITAL_DENY,
	INHERIT, SELF_BUILD, SELF_REMOVE, SAVE, LOAD, SETTINGS, EXIT,
}

var month: int = 1
var years: int = 251
var curTurnIndex: int = -1
var curTurnCountryId: int = 0
var curTurnCountryOrderNum: int = 0
var playerCountryId: int = 0
var playerOrderNum: int = 0
var difficult: int = 0
var recordInfo: Array = ["", "", "", ""]
var customGeneralList: Array = []
var chooseGeneralName: String = ""
var chapter: String = ""
var countryDieTips: int = 0
var isWatch: bool = false
var show_info: String = ""

var targetCountryId: int = 0
var attackCount: int = 0
var doCityId: int = 0
var targetCityId: int = 0
var playingState: int = GameState.NONE
var task: int = TaskType.NONE
var targetGeneralIds: Array = []
var optionalGeneralIds: Array = []
var doGeneralIds: Array = []


func reset_game_state() -> void:
	month = 1
	years = 251
	curTurnIndex = -1
	curTurnCountryId = 0
	curTurnCountryOrderNum = 0
	playerCountryId = 0
	playerOrderNum = 0
	difficult = 0
	recordInfo = ["", "", "", ""]
	customGeneralList = []
	chooseGeneralName = ""
	chapter = ""
	countryDieTips = 0
	isWatch = false
	show_info = ""
	targetCountryId = 0
	attackCount = 0
	doCityId = 0
	targetCityId = 0
	playingState = GameState.NONE
	task = TaskType.NONE
	targetGeneralIds = []
	optionalGeneralIds = []
	doGeneralIds = []


## 获取玩家命令数量
func get_player_order_num() -> int:
	var city_num := CountryListCache.get_country_by_country_id(playerCountryId).get_have_city_num()
	if city_num < 3:
		city_num = 3
	elif city_num <= 4:
		city_num = 4
	elif city_num <= 7:
		city_num = 6
	elif city_num <= 10:
		city_num = 7
	elif city_num >= 11:
		city_num = 8
	return city_num


## 减少玩家命令，减到0返回true表示回合结束
func sub_player_order() -> bool:
	if playerOrderNum < 0 or playerOrderNum > 8:
		playerOrderNum = 0
		return false
	if playerOrderNum > 0:
		playerOrderNum -= 1
		if playerOrderNum == 0:
			return true
	return false


func set_general_option(general_ids: Array) -> void:
	optionalGeneralIds = []
	for gid in general_ids:
		optionalGeneralIds.append(gid)


func set_target_general(general_ids) -> void:
	targetGeneralIds = []
	if general_ids is Array:
		for gid in general_ids:
			targetGeneralIds.append(gid)
	else:
		targetGeneralIds.append(general_ids)
