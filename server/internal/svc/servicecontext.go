package svc

import (
	"errors"
	"sync"

	"3k-server/internal/config"
	"3k-server/internal/game"
	"3k-server/internal/persist"
	"3k-server/internal/static"
	"3k-server/internal/ws"
)

// errSessionNotFound 会话不存在
var errSessionNotFound = errors.New("session not found")

// ServiceContext 全局依赖注入（对应 go-zero svc）
type ServiceContext struct {
	Config   config.Config
	Mu       sync.Mutex
	Sessions map[string]*ws.Session // sessionId -> Session
	Store    persist.Store          // 存档存储（JSON 文件或 MySQL）
	Auth     *persist.AuthStore     // 登录鉴权（nil 表示内存态/未接 DB）
	Static   static.Store           // 静态数据存储（MySQL/SQLite/内存）
	// 每个 playerId 可持有多个 session（多局），但通常一个活跃
}

// NewServiceContext 创建服务上下文。
// 静态数据：DataSource 非空走 DB（MySQL/SQLite），否则用 SQLite（SQLitePath），失败回退内存。
// 存档存储：Config.InMemory 为 true（或 DataSource 为空）时用 JSON 文件，否则 DB（MySQL/SQLite）。
func NewServiceContext(c config.Config) *ServiceContext {
	sc := &ServiceContext{
		Config:   c,
		Sessions: map[string]*ws.Session{},
	}
	sc.Static = openStaticStore(c)
	if c.InMemory || c.DataSource == "" {
		store, _ := persist.NewSaveStore("saves")
		sc.Store = store
		// 内存态：Auth 留 nil，logic 用 mock 登录
	} else {
		if store, err := persist.NewMySQLStore(c.DataSource); err == nil {
			sc.Store = store
			sc.Auth, _ = persist.NewAuthStore(c.DataSource)
		}
	}
	if sc.Store == nil {
		// 兜底：Never nil（内存态）
		store, _ := persist.NewSaveStore("saves")
		sc.Store = store
	}
	return sc
}

// openStaticStore 打开静态数据存储：优先 DB，失败回退内存。
func openStaticStore(c config.Config) static.Store {
	dsn := c.DataSource
	if dsn == "" {
		dsn = c.SQLitePath
	}
	if store, err := static.Open(dsn); err == nil {
		return store
	}
	// 回退：内存解析内嵌种子 JSON（数据一致）
	mem, _ := static.NewMemoryStore()
	return mem
}

// Close 释放底层存储连接
func (s *ServiceContext) Close() {
	if s.Static != nil {
		s.Static.Close()
	}
	if s.Store != nil {
		s.Store.Close()
	}
	if s.Auth != nil {
		s.Auth.Close()
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
	w, err := s.newWorld(0)
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
	w, err := s.newWorld(seed)
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

// newWorld 用静态数据存储（DB/内存）构造全新 World。
func (s *ServiceContext) newWorld(seed int64) (*game.World, error) {
	cfg, err := s.Static.Config()
	if err != nil {
		return nil, err
	}
	texts, err := s.Static.Texts()
	if err != nil {
		return nil, err
	}
	return game.NewWorld(cfg, texts, seed), nil
}

func seedString(seed int64) string {
	return string(rune('a' + seed%26)) // 简单会话id后缀
}