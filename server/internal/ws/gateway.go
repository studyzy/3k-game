package ws

import (
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

// Handler 处理单条 C2S 请求，返回要推送的响应列表。
type Handler func(s *Session, env *Envelope) ([]PushMsg, error)

// PushMsg 一条待推送消息
type PushMsg struct {
	Op   int
	Body interface{}
}

// Gateway 处理 WebSocket 连接的读循环
type Gateway struct {
	Upgrader websocket.Upgrader
	// ResolveSession 根据握手参数找到 Session
	ResolveSession func(w http.ResponseWriter, r *http.Request) (*Session, error)
	// Handle 命令处理器
	Handle Handler
}

// ServeWS 升级连接并启动读循环
func (g *Gateway) ServeWS(w http.ResponseWriter, r *http.Request) {
	sess, err := g.ResolveSession(w, r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}
	conn, err := g.Upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("websocket upgrade error: %v", err)
		return
	}
	defer conn.Close()
	sess.Bind(conn)

	for {
		var env Envelope
		if err := conn.ReadJSON(&env); err != nil {
			break
		}
		if env.Type != "req" {
			continue
		}
		msgs, err := g.Handle(sess, &env)
		if err != nil {
			log.Printf("handle op %d error: %v", env.Op, err)
			continue
		}
		for _, m := range msgs {
			if err := sess.Push(m.Op, m.Body); err != nil {
				break
			}
		}
	}
}
