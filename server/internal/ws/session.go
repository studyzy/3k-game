package ws

import (
	"encoding/json"
	"sync"

	"github.com/gorilla/websocket"

	"3k-server/internal/game"
)

// Session 一个玩家的游戏会话，持有唯一权威 WorldState。
// 单 goroutine 串行处理命令，保证 RNG 顺序确定性。
type Session struct {
	ID            string
	PlayerId      string
	World         *game.World
	Version       int

	conn *websocket.Conn
	mu   sync.Mutex
}

// NewSession 创建会话
func NewSession(id, playerId string, w *game.World) *Session {
	return &Session{ID: id, PlayerId: playerId, World: w}
}

// Bind 绑定 WebSocket 连接
func (s *Session) Bind(conn *websocket.Conn) {
	s.mu.Lock()
	s.conn = conn
	s.mu.Unlock()
}

// Push 向客户端推送消息
func (s *Session) Push(op int, body interface{}) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.conn == nil {
		return nil
	}
	env := Envelope{V: 1, Type: "push", Op: op}
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return err
		}
		env.Body = b
	}
	return s.conn.WriteJSON(env)
}

// PushRaw 直接推送序列化 body
func (s *Session) PushRaw(op int, raw json.RawMessage) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.conn == nil {
		return nil
	}
	return s.conn.WriteJSON(Envelope{V: 1, Type: "push", Op: op, Body: raw})
}
