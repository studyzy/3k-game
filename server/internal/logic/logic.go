package logic

import (
	"errors"
	"fmt"
	"time"

	"3k-server/internal/svc"
	"3k-server/internal/ws"
)

// Logic 游戏 HTTP 业务逻辑层（go-zero logic）
// 封装登录/建局/存读档等一次性动作，供 handler 层调用。
type Logic struct {
	svcCtx *svc.ServiceContext
}

// New 创建 Logic
func New(svcCtx *svc.ServiceContext) *Logic {
	return &Logic{svcCtx: svcCtx}
}

// Login 登录。
// MySQL 模式下查询/建立 users 表并签发 token；内存态（未接 DB）返回 mock token 兼容旧开发流程。
func (l *Logic) Login(playerId string) (token string, err error) {
	if playerId == "" {
		playerId = "p1"
	}
	if l.svcCtx.Auth == nil {
		return "mock-token-" + playerId, nil
	}
	return l.svcCtx.Auth.Login(playerId)
}

// CreateGame 创建新局，返回 sessionId + 全量快照
func (l *Logic) CreateGame(playerId string) (sessionId string, snapshot map[string]interface{}, err error) {
	if playerId == "" {
		playerId = "p1"
	}
	seed := time.Now().UnixNano()
	sess, err := l.svcCtx.CreateGame(playerId, seed)
	if err != nil {
		return "", nil, err
	}
	return sess.ID, sess.World.ToSnapshot(sess.ID, sess.Version), nil
}

// SaveGame 保存当前局到服务器
func (l *Logic) SaveGame(playerId, sessionId, saveId string) error {
	if playerId == "" || sessionId == "" || saveId == "" {
		return errors.New("missing params")
	}
	sess, err := l.svcCtx.GetSession(sessionId)
	if err != nil {
		return err
	}
	return l.svcCtx.SaveGame(sess, saveId)
}

// LoadGame 读取存档，返回新 sessionId + 全量快照
func (l *Logic) LoadGame(playerId, saveId string) (sessionId string, snapshot map[string]interface{}, err error) {
	if playerId == "" || saveId == "" {
		return "", nil, errors.New("missing params")
	}
	sess, err := l.svcCtx.LoadGame(playerId, saveId)
	if err != nil {
		return "", nil, err
	}
	return sess.ID, sess.World.ToSnapshot(sess.ID, sess.Version), nil
}

// Static 返回全量静态渲染数据（武将/城池/势力/武器/章节/地图/阵型/文案）。
func (l *Logic) Static() (map[string]any, error) {
	return l.svcCtx.Static.AllStatic()
}

// ResolveSession 从 WebSocket 握手参数解析 Session。
// 有 sessionId 时直接取；否则 MySQL 模式下校验 token 后按 playerId 建局，内存态按 playerId 建局。
func (l *Logic) ResolveSession(sessionId, playerId, token string) (*ws.Session, error) {
	if sessionId != "" {
		sess, err := l.svcCtx.GetSession(sessionId)
		if err != nil {
			return nil, err
		}
		return sess, nil
	}
	if playerId == "" {
		playerId = "p1"
	}
	// MySQL 模式：token 与 playerId 必须匹配
	if l.svcCtx.Auth != nil {
		uid := l.svcCtx.Auth.VerifyToken(token)
		if uid == "" || uid != playerId {
			return nil, fmt.Errorf("invalid token")
		}
	}
	seed := time.Now().UnixNano()
	sess, err := l.svcCtx.CreateGame(playerId, seed)
	if err != nil {
		return nil, fmt.Errorf("create game: %w", err)
	}
	return sess, nil
}
