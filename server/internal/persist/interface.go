package persist

// Store 存档存储接口。SaveStore（JSON 文件）与 MySQLStore（gorm）都实现它。
type Store interface {
	// Save 保存一局快照到指定槽位
	Save(playerID, saveID string, snapshot []byte) error
	// Load 读取一局快照
	Load(playerID, saveID string) ([]byte, error)
	// List 列出玩家所有存档槽描述
	List(playerID string) []map[string]interface{}
	// Close 释放底层连接/资源
	Close() error
}