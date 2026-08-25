package integration

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"testing"
	"time"
)

// uniquePlayer 生成唯一 playerId，避免测试间/多次运行存档冲突。
func uniquePlayer() string {
	b := make([]byte, 4)
	_, _ = rand.Read(b)
	return "it_" + hex.EncodeToString(b)
}

// OpSearchTask：搜将（TaskSEARCH=17）。
const OpSearchTask = 17

// TestE2E_HappyPath 核心链路：
// 登录 → 建局 → WS 连（SelectKing）→ 发命令（ExecuteTask）→ 回合（EndTurn）→ 存档 → 读档校验。
func TestE2E_HappyPath(t *testing.T) {
	c := newClient()
	base := baseURL()

	// 1. 登录，得 token + playerId
	playerID := uniquePlayer()
	var login struct {
		Ok       bool   `json:"ok"`
		Token    string `json:"token"`
		PlayerId string `json:"playerId"`
	}
	if err := c.postForm(base+"/auth/login", map[string]string{"playerId": playerID}, &login); err != nil {
		t.Fatalf("登录失败: %v", err)
	}
	if !login.Ok || login.Token == "" {
		t.Fatalf("登录异常: %+v", login)
	}
	token := login.Token

	// 2. 建局，得 sessionId + snapshot
	var ng struct {
		Ok        bool                   `json:"ok"`
		SessionId string                 `json:"sessionId"`
		Snapshot  map[string]interface{} `json:"snapshot"`
	}
	if err := c.postForm(base+"/game/new", map[string]string{"playerId": playerID}, &ng); err != nil {
		t.Fatalf("建局失败: %v", err)
	}
	if !ng.Ok || ng.SessionId == "" || len(ng.Snapshot) == 0 {
		t.Fatalf("建局异常: %+v", ng)
	}
	sessionID := ng.SessionId

	// 3. 连 WebSocket
	ws := wsConnect(t, map[string]string{
		"sessionId": sessionID,
		"playerId":  playerID,
		"token":     token,
	})

	// 4. 选君主 → 收 Delta
	writeReq(t, ws, 1, OpSelectKing, map[string]interface{}{"countryId": optCountry(ng.Snapshot)})
	op, body := readPush(t, ws, 5*time.Second)
	if op != OpDelta {
		t.Fatalf("SelectKing 期望 OpDelta(0x201)，实际 0x%X body=%v", op, body)
	}

	// 5. 发内政命令（TaskSEARCH=17），应收 Delta + TaskResult
	genID := optionGen(ng.Snapshot)
	writeReq(t, ws, 2, OpExecuteTask, map[string]interface{}{
		"task":         OpSearchTask,
		"doCityId":     optionCity(ng.Snapshot),
		"doGeneralIds": []int{genID},
		"inputs":       map[string]interface{}{},
	})
	gotDelta, gotTask := false, false
	for i := 0; i < 4; i++ {
		op, _ = readPush(t, ws, 5*time.Second)
		switch op {
		case OpDelta:
			gotDelta = true
		case OpTaskResult:
			gotTask = true
		}
		if gotDelta && gotTask {
			break
		}
	}
	if !gotDelta || !gotTask {
		t.Fatalf("ExecuteTask 后期望收到 Delta+TaskResult，gotDelta=%v gotTask=%v", gotDelta, gotTask)
	}

	// 6. 回合结束（服务器会推 Delta + TurnResult，逐个消费直到 TurnResult）
	writeReq(t, ws, 3, OpEndTurn, nil)
	gotTurn := false
	for i := 0; i < 4; i++ {
		op, body = readPush(t, ws, 8*time.Second)
		if op == OpTurnResult {
			gotTurn = true
			break
		}
		if i == 3 {
			t.Fatalf("EndTurn 后期望收到 OpTurnResult(0x203)，实际最后是 0x%X body=%v", op, body)
		}
	}
	_ = gotTurn

	// 7. 存档
	var save struct {
		Ok     bool   `json:"ok"`
		SaveId string `json:"saveId"`
	}
	if err := c.postForm(base+"/game/save", map[string]string{
		"playerId": playerID, "sessionId": sessionID, "saveId": "slot1",
	}, &save); err != nil {
		t.Fatalf("存档失败: %v", err)
	}
	if !save.Ok {
		t.Fatalf("存档异常: %+v", save)
	}

	// 8. 读档校验（快照含 gameInfo.years）
	var ld struct {
		Ok        bool                   `json:"ok"`
		SessionId string                 `json:"sessionId"`
		Snapshot  map[string]interface{} `json:"snapshot"`
	}
	if err := c.postForm(base+"/game/load", map[string]string{
		"playerId": playerID, "saveId": "slot1",
	}, &ld); err != nil {
		t.Fatalf("读档失败: %v", err)
	}
	if !ld.Ok || len(ld.Snapshot) == 0 {
		t.Fatalf("读档异常: %+v", ld)
	}
	if gi, ok := ld.Snapshot["gameInfo"].(map[string]interface{}); ok {
		if _, ok := gi["years"]; !ok {
			t.Fatalf("gameInfo 缺少 years: %v", gi)
		}
	} else {
		t.Fatalf("读档快照缺 gameInfo")
	}
}

// optCountry 从快照 country 字典中取一个可选势力 id。
func optCountry(snapshot map[string]interface{}) int {
	cs, _ := snapshot["countries"].(map[string]interface{})
	for _, v := range cs {
		m, ok := v.(map[string]interface{})
		if !ok {
			continue
		}
		if can, _ := m["canBeChoose"].(bool); can {
			if id, ok := m["countryId"].(float64); ok {
				return int(id)
			}
		}
	}
	return 1
}

// optionGen 从快照 generals 字典中取任意一个武将 id。
func optionGen(snapshot map[string]interface{}) int {
	gs, _ := snapshot["generals"].(map[string]interface{})
	for idStr := range gs {
		var id int
		if err := json.Unmarshal([]byte(idStr), &id); err == nil {
			return id
		}
	}
	return 1
}

// optionCity 从快照 cities 字典中取任意一个城池 id。
func optionCity(snapshot map[string]interface{}) int {
	cs, _ := snapshot["cities"].(map[string]interface{})
	for idStr := range cs {
		var id int
		if err := json.Unmarshal([]byte(idStr), &id); err == nil {
			return id
		}
	}
	return 1
}

// TestWS_Auth 校验 WS 握手鉴权：带无效 token 时连接应失败。
// 仅当通过 make integration（接库模式，DB 可为 MySQL/SQLite）运行时 server 启用 token 校验才会拒绝。
func TestWS_Auth(t *testing.T) {
	// 若未在接库模式（INT_TEST_DB=1）下运行，跳过本用例
	if env("INT_TEST_DB", "") != "1" {
		t.Skip("仅接库模式（make integration）校验 token")
	}
	base := baseURL()
	_ = base
	// 直接以无效 token + 新局（无 sessionId）连接，期望握手失败
	conn, resp, err := rawDial(t, map[string]string{"playerId": "bad-player", "token": "invalid-token"})
	if err == nil {
		if conn != nil {
			conn.Close()
		}
		if resp != nil {
			t.Fatalf("无效 token 连接前程: HTTP %d", resp.StatusCode)
		}
		t.Fatalf("无效 token 竟然连接成功")
	}
	_ = resp
}