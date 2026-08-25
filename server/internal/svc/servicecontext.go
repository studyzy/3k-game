package svc

import (
	"errors"
	"sync"

	"3k-server/internal/config"
	"3k-server/internal/game"
	"3k-server/internal/persist"
	"3k-server/internal/ws"
)

// errSessionNotFound 会话不存在
var errSessionNotFound = errors.New("session not found")

// ServiceContext 全局依赖注入（对应 go-zero svc）
type ServiceContext struct {
	Config   config.Config
	Mu       sync.Mutex
	Sessions map[string]*ws.Session // sessionId -> Session
	Store    *persist.SaveStore     // 存档存储
	// 每个 playerId 可持有多个 session（多局），但通常一个活跃
}

// NewServiceContext 创建服务上下文
func NewServiceContext(c config.Config) *ServiceContext {
	store, _ := persist.NewSaveStore("saves")
	return &ServiceContext{
		Config:   c,
		Sessions: map[string]*ws.Session{},
		Store:    store,
	}
}

// SaveGame 保存当前局到服务器
func (s *ServiceContext) SaveGame(sess *ws.Session, saveID string) error {
	data, err := sess.World.Serialize()
	if err != nil {
		return err
	}
	return s.Store.Save(sess.PlayerId, saveID, data)
}

// LoadGame 加载服务器存档到新 Session（返回 snapshot）
func (s *ServiceContext) LoadGame(playerID, saveID string) (*ws.Session, error) {
	data, err := s.Store.Load(playerID, saveID)
	if err != nil {
		return nil, err
	}
	// 反序列化：从存档恢复 World（保留原有静态表，覆盖动态字段）
	w, err := game.NewWorldFromData(s.Config.DataDir, 0)
	if err != nil {
		return nil, err
	}
	if err := w.Deserialize(data); err != nil {
		return nil, err
	}
	sess := ws.NewSession(playerID+"-load", playerID, w)
	s.Mu.Lock()
	s.Sessions[sess.ID] = sess
	s.Mu.Unlock()
	return sess, nil
}

// CreateGame 创建一局新游戏，返回 sessionId + World
func (s *ServiceContext) CreateGame(playerId string, seed int64) (*ws.Session, error) {
	w, err := game.NewWorldFromData(s.Config.DataDir, seed)
	if err != nil {
		return nil, err
	}
	sess := ws.NewSession(playerId+"-"+seedString(seed), playerId, w)
	s.Mu.Lock()
	s.Sessions[sess.ID] = sess
	s.Mu.Unlock()
	return sess, nil
}

// GetSession 按 sessionId 取会话
func (s *ServiceContext) GetSession(sessionId string) (*ws.Session, error) {
	s.Mu.Lock()
	defer s.Mu.Unlock()
	sess := s.Sessions[sessionId]
	if sess == nil {
		return nil, errSessionNotFound
	}
	return sess, nil
}

func seedString(seed int64) string {
	return string(rune('a' + seed%26)) // 简单会话id后缀
}
