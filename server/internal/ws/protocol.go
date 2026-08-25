package ws

import "encoding/json"

// 消息信封
type Envelope struct {
	V    int             `json:"v"`
	Type string          `json:"type"` // "req" | "push"
	Seq  int64           `json:"seq"`
	Op   int             `json:"op"`
	Body json.RawMessage `json:"body,omitempty"`
}

// Opcode：C2S 请求（HTTP 之外，局内命令）
const (
	OpSelectKing    = 0x100
	OpSelectGeneral = 0x105
	OpExecuteTask   = 0x106
	OpEndTurn       = 0x107
	OpWarMove       = 0x108
	OpWarEndTurn    = 0x109
	OpWarAction     = 0x10A
	OpBattleSelect  = 0x10B
	OpBattleTactic  = 0x10C
	OpBattleAdvance = 0x10D
	OpPing          = 0x10F
)

// S2C 推送 opcode
const (
	OpWorldSnapshot = 0x200
	OpDelta         = 0x201
	OpTaskResult    = 0x202
	OpTurnResult    = 0x203
	OpMonthResult   = 0x204
	OpWarStart      = 0x205
	OpWarStep       = 0x206
	OpBattleStart   = 0x207
	OpBattleStep    = 0x208
	OpServerEvent   = 0x209
	OpPong          = 0x20F
	OpAuthResult    = 0x210
	OpSaveResult    = 0x211
	OpBattleResult  = 0x212
)

// C2S 补充 opcode
const (
	OpNewGame = 0x101
	OpAttack  = 0x110
)
