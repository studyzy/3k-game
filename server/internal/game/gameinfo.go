package game

// GameState 全局状态机枚举，对应 GDScript GameInfo.GameState
type GameState int

const (
	GameStateNONE          GameState = 0
	GameStateGAME_START    GameState = 1
	GameStatePLAYING       GameState = 2
	GameStatePLAYER_TURN   GameState = 3
	GameStateAI_TURN       GameState = 4
	GameStateGAME_OVER     GameState = 5
	GameStateGAME_WIN      GameState = 6
	GameStateINHERIT       GameState = 7
	GameStateTRUCE         GameState = 8
	GameStateBRIBE         GameState = 9
	GameStatePLAYER_VS_AI  GameState = 10
	GameStateAI_VS_PLAYER  GameState = 11
	GameStateOCCUPY        GameState = 12
	GameStateAI_ATTACK     GameState = 13
	GameStateAI_WIN        GameState = 14
	GameStateAI_LOSE       GameState = 15
	GameStateTAX           GameState = 16
	GameStateHARVEST       GameState = 17
	GameStateREBEL         GameState = 18
	GameStateDROUGHT       GameState = 19
	GameStateFLOOD         GameState = 20
	GameStatePLAGUE        GameState = 21
	GameStateLOCUST_PLAGUE GameState = 22
	GameStateTURMOIL       GameState = 23
	GameStatePLUNDER       GameState = 24
)

// TaskType 玩家命令/任务类型，对应 GDScript GameInfo.TaskType（精确按原枚举序）
type TaskType int

const (
	TaskNONE           TaskType = 0
	TaskMOVE           TaskType = 1
	TaskMOVE_DENY      TaskType = 2
	TaskOVER_MOVE      TaskType = 3
	TaskMOVE_PREFECT   TaskType = 4
	TaskATTACK         TaskType = 5
	TaskATTACK_DENY    TaskType = 6
	TaskOVER_ATTACK    TaskType = 7
	TaskCONSCRIPT      TaskType = 8
	TaskASSIGN         TaskType = 9
	TaskTRANSPORT      TaskType = 10
	TaskTRANSPORT_DENY TaskType = 11
	TaskEND            TaskType = 12
	TaskSEARCH         TaskType = 13
	TaskSEARCH_MONEY   TaskType = 14
	TaskSEARCH_FOOD    TaskType = 15
	TaskSEARCH_TREASURE TaskType = 16
	TaskSEARCH_GENERAL TaskType = 17
	TaskSEARCH_NOTHING TaskType = 18
	TaskEMPLOY         TaskType = 19
	TaskEMPLOY_SUCCESS TaskType = 20
	TaskEMPLOY_DENY    TaskType = 21
	TaskEMPLOY_NOTHING TaskType = 22
	TaskOVER_EMPLOY    TaskType = 23
	TaskREWARD         TaskType = 24
	TaskREWARD_DENY    TaskType = 25
	TaskAPPOINT        TaskType = 26
	TaskAPPOINT_DENY   TaskType = 27
	TaskLACK           TaskType = 28
	TaskRECLAIM        TaskType = 29
	TaskOVER_RECLAIM   TaskType = 30
	TaskMERCANTILE     TaskType = 31
	TaskOVER_MERCANTILE TaskType = 32
	TaskTAME           TaskType = 33
	TaskOVER_TAME      TaskType = 34
	TaskPATROL         TaskType = 35
	TaskOVER_PATROL    TaskType = 36
	TaskTRUCE          TaskType = 37
	TaskOVER_TRUCE     TaskType = 38
	TaskTRUCE_SELECT   TaskType = 39
	TaskALIENATE       TaskType = 40
	TaskINTELLIGENCE   TaskType = 41
	TaskBRIBE          TaskType = 42
	TaskSHOP           TaskType = 43
	TaskLACK_SHOP      TaskType = 44
	TaskSMITHY         TaskType = 45
	TaskLACK_SMITHY    TaskType = 46
	TaskSCHOOL         TaskType = 47
	TaskLACK_SCHOOL    TaskType = 48
	TaskSCHOOL_DENY    TaskType = 49
	TaskHOSPITAL       TaskType = 50
	TaskLACK_HOSPITAL  TaskType = 51
	TaskHOSPITAL_DENY  TaskType = 52
	TaskINHERIT        TaskType = 53
	TaskSELF_BUILD     TaskType = 54
	TaskSELF_REMOVE    TaskType = 55
	TaskSAVE           TaskType = 56
	TaskLOAD           TaskType = 57
	TaskSETTINGS       TaskType = 58
	TaskEXIT           TaskType = 59
)

// GameInfoState 权威游戏状态，对应 GDScript GameInfo 单例
type GameInfoState struct {
	Years int `json:"years"`
	Month int `json:"month"`

	CurTurnIndex            int       `json:"curTurnIndex"`
	CurTurnCountryId        int       `json:"curTurnCountryId"`
	CurTurnCountryOrderNum  int       `json:"curTurnCountryOrderNum"`
	PlayerCountryId         int       `json:"playerCountryId"`
	PlayerOrderNum          int       `json:"playerOrderNum"`
	Difficult               int       `json:"difficult"`
	AttackCount             int       `json:"attackCount"`
	PlayingState            GameState `json:"playingState"`

	TargetCountryId int `json:"targetCountryId"`
	DoCityId        int `json:"doCityId"`
	TargetCityId    int `json:"targetCityId"`
	Task            TaskType `json:"task"`

	TargetGeneralIds   []int `json:"targetGeneralIds"`
	OptionalGeneralIds []int `json:"optionalGeneralIds"`
	DoGeneralIds       []int `json:"doGeneralIds"`

	ShowInfo string `json:"showInfo"`
}

// Reset 重置为初始状态（对应 reset_game_state）
func (g *GameInfoState) Reset() {
	g.Years = 251
	g.Month = 1
	g.CurTurnIndex = -1
	g.CurTurnCountryId = 0
	g.CurTurnCountryOrderNum = 0
	g.PlayerCountryId = 0
	g.PlayerOrderNum = 0
	g.Difficult = 0
	g.AttackCount = 0
	g.PlayingState = GameStateNONE
	g.TargetCountryId = 0
	g.DoCityId = 0
	g.TargetCityId = 0
	g.Task = TaskNONE
	g.TargetGeneralIds = nil
	g.OptionalGeneralIds = nil
	g.DoGeneralIds = nil
	g.ShowInfo = ""
}

// GetPlayerOrderNum 获取玩家命令数量（对应 get_player_order_num）
func (g *GameInfoState) GetPlayerOrderNum(w *World) int {
	c := w.Country(g.PlayerCountryId)
	if c == nil {
		return 3
	}
	cityNum := c.GetHaveCityNum()
	switch {
	case cityNum < 3:
		return 3
	case cityNum <= 4:
		return 4
	case cityNum <= 7:
		return 6
	case cityNum <= 10:
		return 7
	default:
		return 8
	}
}

// SubPlayerOrder 减少玩家命令，减到0返回true表示回合结束（对应 sub_player_order）
func (g *GameInfoState) SubPlayerOrder() bool {
	if g.PlayerOrderNum < 0 || g.PlayerOrderNum > 8 {
		g.PlayerOrderNum = 0
		return false
	}
	if g.PlayerOrderNum > 0 {
		g.PlayerOrderNum--
		if g.PlayerOrderNum == 0 {
			return true
		}
	}
	return false
}
