package persist

import (
	"encoding/json"
	"errors"
	"strings"
	"time"

	"gorm.io/gorm"
)

// MySQLStore 存档存储（gorm/MySQL 版）。data 字段存 World.Serialize() 的 JSON。
// 表结构见 db/init/001_schema.sql（saves 表）。
type MySQLStore struct {
	db *gorm.DB
}

// SaveRow saves 表行
type SaveRow struct {
	PlayerID  string    `gorm:"column:player_id;size:64;primaryKey"`
	SaveID    string    `gorm:"column:save_id;size:64;primaryKey"`
	Data      string    `gorm:"column:data;type:longtext"`
	UpdatedAt time.Time `gorm:"column:updated_at"`
}

// TableName 表名
func (SaveRow) TableName() string { return "saves" }

// NewMySQLStore 建立 gorm 连接并确保表存在。
// dsn 示例：root:root@tcp(127.0.0.1:3306)/3k?charset=utf8mb4&parseTime=True&loc=Local
func NewMySQLStore(dsn string) (*MySQLStore, error) {
	if strings.TrimSpace(dsn) == "" {
		return nil, errors.New("empty mysql dsn")
	}
	db, err := opensMySQL(dsn)
	if err != nil {
		return nil, err
	}
	if err := db.AutoMigrate(&SaveRow{}); err != nil {
		return nil, err
	}
	return &MySQLStore{db: db}, nil
}

// Save 保存（UPSERT）一局快照
func (m *MySQLStore) Save(playerID, saveID string, snapshot []byte) error {
	row := SaveRow{
		PlayerID: playerID,
		SaveID:   saveID,
		Data:     string(snapshot),
	}
	return m.db.Save(&row).Error
}

// Load 读取一局快照
func (m *MySQLStore) Load(playerID, saveID string) ([]byte, error) {
	var row SaveRow
	if err := m.db.Where("player_id = ? AND save_id = ?", playerID, saveID).First(&row).Error; err != nil {
		return nil, err
	}
	return []byte(row.Data), nil
}

// List 列出玩家所有存档槽描述
func (m *MySQLStore) List(playerID string) []map[string]interface{} {
	var rows []SaveRow
	if err := m.db.Where("player_id = ?", playerID).Find(&rows).Error; err != nil {
		return nil
	}
	var result []map[string]interface{}
	for _, r := range rows {
		var meta map[string]interface{}
		if json.Unmarshal([]byte(r.Data), &meta) == nil {
			result = append(result, map[string]interface{}{
				"saveId": r.SaveID,
				"years":  meta["years"],
				"month":  meta["month"],
			})
		}
	}
	return result
}

// Close 释放连接池
func (m *MySQLStore) Close() error {
	sqlDB, err := m.db.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}