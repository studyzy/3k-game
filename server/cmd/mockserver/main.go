// Mock WebSocket + HTTP server，供 Godot 客户端测试使用。
// 从 JSON 脚本读取预设的 HTTP 响应与 WS 推送序列，只回放，不参与真实游戏逻辑。
package main

import (
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync"

	"github.com/gorilla/websocket"
)

// HTTPFixture 单个 HTTP 路由的预设响应。
type HTTPFixture struct {
	Code int             `json:"code"`
	Body json.RawMessage `json:"body"`
}

// WSPush 一条 WS 推送：收到 onOp 请求后就回放 push 信封。
type WSPush struct {
	OnOp int            `json:"onOp"`
	Push map[string]any `json:"push"`
}

// Case 一个测试用例的完整脚本。
type Case struct {
	HTTP map[string]*HTTPFixture `json:"http"`
	WS   *WSSpec                 `json:"ws"`
}

// WSSpec WS 部分的脚本配置。
type WSSpec struct {
	Responses []WSPush `json:"responses"`
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(*http.Request) bool { return true },
}

type wsHub struct {
	mu    sync.Mutex
	queue []WSPush // 尚未消费的推送脚本
}

// handle 读取客户端 C2S 帧，若匹配预设 onOp 则回放对应 push。
func (h *wsHub) handle(conn *websocket.Conn) {
	for {
		_, data, err := conn.ReadMessage()
		if err != nil {
			log.Printf("ws read error: %v", err)
			return
		}
		var env struct {
			Op int `json:"op"`
		}
		if err := json.Unmarshal(data, &env); err != nil {
			continue
		}
		log.Printf("mockserver received op=%d seq=%s", env.Op, string(data))
		h.mu.Lock()
		for i := range h.queue {
			if h.queue[i].OnOp == env.Op {
				payload, _ := json.Marshal(h.queue[i].Push)
				if werr := conn.WriteMessage(websocket.TextMessage, payload); werr != nil {
					log.Printf("ws write error: %v", werr)
				}
				// 每条 onOp 只回放一次
				h.queue[i].OnOp = -1
			}
		}
		h.mu.Unlock()
	}
}

func main() {
	port := flag.Int("port", 8080, "监听端口")
	file := flag.String("case", "testdata/case_netclient.json", "测试脚本 JSON 路径")
	flag.Parse()

	raw, err := os.ReadFile(*file)
	if err != nil {
		log.Fatalf("读取脚本失败: %v", err)
	}
	var c Case
	if err := json.Unmarshal(raw, &c); err != nil {
		log.Fatalf("解析脚本失败: %v", err)
	}

	mux := http.NewServeMux()
	for path, fx := range c.HTTP {
		path := path
		fx := fx
		mux.HandleFunc(path, func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(fx.Code)
			_, _ = w.Write(fx.Body)
		})
	}

	if c.WS != nil {
		hub := &wsHub{queue: c.WS.Responses}
		mux.HandleFunc("/game/ws", func(w http.ResponseWriter, r *http.Request) {
			conn, err := upgrader.Upgrade(w, r, nil)
			if err != nil {
				log.Printf("upgrade error: %v", err)
				return
			}
			defer conn.Close()
			hub.handle(conn)
		})
	}

	addr := "127.0.0.1:" + strconv.Itoa(*port)
	log.Printf("MockServer 启动: %s, 脚本 %s", addr, *file)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("listen error: %v", err)
	}
}