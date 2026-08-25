package persist

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// SaveStore 存档存储（开发期用 JSON 文件；将来可换 SQLite/MySQL）
type SaveStore struct {
	Dir string
}

// NewSaveStore 创建存档目录
func NewSaveStore(dir string) (*SaveStore, error) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, err
	}
	return &SaveStore{Dir: dir}, nil
}

// Save 保存一局快照到指定槽位（按 playerId/saveId）
func (s *SaveStore) Save(playerID, saveID string, snapshot []byte) error {
	dir := filepath.Join(s.Dir, playerID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	path := filepath.Join(dir, saveID+".json")
	return os.WriteFile(path, snapshot, 0o644)
}

// Load 读取一局快照
func (s *SaveStore) Load(playerID, saveID string) ([]byte, error) {
	path := s.path(playerID, saveID)
	return os.ReadFile(path)
}

// List 列出玩家所有存档槽描述
func (s *SaveStore) List(playerID string) []map[string]interface{} {
	dir := filepath.Join(s.Dir, playerID)
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var result []map[string]interface{}
	for _, e := range entries {
		data, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			continue
		}
		var meta map[string]interface{}
		if json.Unmarshal(data, &meta) == nil {
			result = append(result, map[string]interface{}{
				"saveId": e.Name(),
				"years":  meta["years"],
				"month":  meta["month"],
			})
		}
	}
	return result
}

func (s *SaveStore) path(playerID, saveID string) string {
	return filepath.Join(s.Dir, playerID, saveID+".json")
}
