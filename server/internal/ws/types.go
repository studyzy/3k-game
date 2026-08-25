package ws

// Delta 增量更新（S2C_Delta body）
type Delta struct {
	Changed  Changed                `json:"changed"`
	Events   []EventItem            `json:"events"`
	GameInfo map[string]interface{} `json:"gameInfo,omitempty"`
}

// Changed 按实体类型分组的字段级增量
type Changed struct {
	Generals map[string]map[string]interface{} `json:"generals,omitempty"`
	Cities   map[string]map[string]interface{} `json:"cities,omitempty"`
	Countries map[string]map[string]interface{} `json:"countries,omitempty"`
}

// EventItem 结构化事件（文本/提示）
type EventItem struct {
	Type string `json:"type"`
	Msg  string `json:"msg"`
}

// TaskResult S2C_TaskResult body
type TaskResult struct {
	Task         int      `json:"task"`
	Results      []string `json:"results"`
	OrderNum     int      `json:"orderNum"`
	PlayingState int      `json:"playingState"`
}

// TurnResult S2C_TurnResult body
type TurnResult struct {
	Phase   string    `json:"phase"`
	AiLogs  []string  `json:"aiLogs"`
	Deltas  []*Delta  `json:"deltas"`
	OrderNum int      `json:"orderNum"`
	GameOver bool     `json:"gameOver"`
}

// WorldSnapshot S2C_WorldSnapshot body（全量）
type WorldSnapshot struct {
	SessionId       string                 `json:"sessionId"`
	RngSeed         int64                  `json:"rngSeed"`
	SessionVersion  int                    `json:"sessionVersion"`
	GameInfo        map[string]interface{} `json:"gameInfo"`
	Generals        map[string]interface{} `json:"generals"`
	Cities          map[string]interface{} `json:"cities"`
	Countries       map[string]interface{} `json:"countries"`
	Weapons         map[string]interface{} `json:"weapons"`
	CountrySequence []int                  `json:"countrySequence"`
}
