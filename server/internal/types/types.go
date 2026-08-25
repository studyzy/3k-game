package types

// HTTP 接口请求/响应 DTO（go-zero types 层）
// 对应 /auth/login /game/new /game/save /game/load

// LoginRequest 登录请求
type LoginRequest struct {
	PlayerId string `form:"playerId"`
}

// LoginResponse 登录响应
type LoginResponse struct {
	Ok       bool   `json:"ok"`
	Token    string `json:"token"`
	PlayerId string `json:"playerId"`
}

// NewGameRequest 创建新局请求
type NewGameRequest struct {
	PlayerId string `json:"playerId"`
}

// NewGameResponse 创建新局响应（含全量快照）
type NewGameResponse struct {
	Ok        bool                   `json:"ok"`
	Msg       string                 `json:"msg,omitempty"`
	SessionId string                 `json:"sessionId"`
	Snapshot  map[string]interface{} `json:"snapshot"`
}

// SaveGameRequest 存档请求
type SaveGameRequest struct {
	PlayerId  string `json:"playerId"`
	SessionId string `json:"sessionId"`
	SaveId    string `json:"saveId"`
}

// SaveGameResponse 存档响应
type SaveGameResponse struct {
	Ok     bool   `json:"ok"`
	Msg    string `json:"msg,omitempty"`
	SaveId string `json:"saveId"`
}

// LoadGameRequest 读档请求
type LoadGameRequest struct {
	PlayerId string `json:"playerId"`
	SaveId   string `json:"saveId"`
}

// LoadGameResponse 读档响应（含全量快照）
type LoadGameResponse struct {
	Ok        bool                   `json:"ok"`
	Msg       string                 `json:"msg,omitempty"`
	SessionId string                 `json:"sessionId"`
	Snapshot  map[string]interface{} `json:"snapshot"`
}

// GenericResponse 通用错误响应
type GenericResponse struct {
	Ok  bool   `json:"ok"`
	Msg string `json:"msg"`
}

// StaticResponse 静态数据响应（全量渲染数据：武将/城池/势力/武器/章节/地图/阵型/文案）
type StaticResponse struct {
	Ok   bool           `json:"ok"`
	Msg  string         `json:"msg,omitempty"`
	Data map[string]any `json:"data"`
}
