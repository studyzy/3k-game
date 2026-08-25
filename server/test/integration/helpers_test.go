package integration

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

// baseURL 测试服务器根地址（TestMain 中通过环境变量注入）
const (
	envBaseURL = "INT_TEST_BASE_URL"
	defaultURL = "http://127.0.0.1:18080"
)

// client 简单 HTTP 客户端（POST form + 解析 JSON）
type client struct {
	hc *http.Client
}

func newClient() *client {
	return &client{hc: &http.Client{Timeout: 10 * time.Second}}
}

// postForm 发送 application/x-www-form-urlencoded POST，解析 JSON 到 out。
func (c *client) postForm(u string, data map[string]string, out interface{}) error {
	vals := make(url.Values)
	for k, v := range data {
		vals.Set(k, v)
	}
	req, err := http.NewRequest(http.MethodPost, u, strings.NewReader(vals.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := c.hc.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
	}
	return json.Unmarshal(body, out)
}

// wsConnect 建立 WebSocket 连接（带 sessionId/playerId/token 查询参数）。
func wsConnect(t *testing.T, query map[string]string) *websocket.Conn {
	t.Helper()
	addr := strings.TrimPrefix(baseURL(), "http://") // 127.0.0.1:PORT
	u := url.URL{Scheme: "ws", Host: addr, Path: "/game/ws"}
	q := u.Query()
	for k, v := range query {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()
	conn, _, err := websocket.DefaultDialer.Dial(u.String(), nil)
	if err != nil {
		t.Fatalf("WS 连接失败: %v", err)
	}
	t.Cleanup(func() { conn.Close() })
	return conn
}

// rawDial 建立 WebSocket 连接但不断言成功，返回连接与错误（供鉴权测试用）。
func rawDial(t *testing.T, query map[string]string) (*websocket.Conn, *http.Response, error) {
	t.Helper()
	addr := strings.TrimPrefix(baseURL(), "http://")
	u := url.URL{Scheme: "ws", Host: addr, Path: "/game/ws"}
	q := u.Query()
	for k, v := range query {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()
	return websocket.DefaultDialer.Dial(u.String(), nil)
}

// writeReq 发送一条 C2S 请求信封。
func writeReq(t *testing.T, conn *websocket.Conn, seq int64, op int, body interface{}) {
	t.Helper()
	env := map[string]interface{}{"v": 1, "type": "req", "seq": seq, "op": op}
	if body != nil {
		env["body"] = body
	}
	if err := conn.WriteJSON(env); err != nil {
		t.Fatalf("写入 WS 失败: %v", err)
	}
}

// readPush 读取一条 S2C 推送，返回 op 与 body（body 为原始 JSON 以便断言）。
func readPush(t *testing.T, conn *websocket.Conn, timeout time.Duration) (int, map[string]interface{}) {
	t.Helper()
	if timeout == 0 {
		timeout = 5 * time.Second
	}
	_ = conn.SetReadDeadline(time.Now().Add(timeout))
	var env struct {
		Op   int             `json:"op"`
		Type string          `json:"type"`
		Body json.RawMessage `json:"body,omitempty"`
	}
	if err := conn.ReadJSON(&env); err != nil {
		t.Fatalf("读取 WS 推送失败: %v", err)
	}
	body := map[string]interface{}{}
	if len(env.Body) > 0 {
		_ = json.Unmarshal(env.Body, &body)
	}
	return env.Op, body
}

// baseURL 测试根地址
func baseURL() string {
	if v := env("INT_TEST_BASE_URL", ""); v != "" {
		return v
	}
	return defaultURL
}

// env 取环境变量，不存在给默认值。
func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}