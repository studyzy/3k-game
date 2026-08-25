package persist

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"strings"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// 登录鉴权存储（gorm/MySQL 或 SQLite）。表结构见 db/init/001_schema.sql。
// users / auth_tokens 两表。

// openDB 打开 gorm 连接（带通用配置）。
// dsn 含 MySQL 特征（user:pass@tcp(...)）时用 MySQL，否则按 SQLite（文件路径或 :memory:）。
func openDB(dsn string) (*gorm.DB, error) {
	var dialector gorm.Dialector
	if isMySQLDSN(dsn) {
		dialector = mysql.Open(dsn)
	} else {
		dialector = sqlite.Open(dsn)
	}
	return gorm.Open(dialector, &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
}

// isMySQLDSN 依据 DSN 判断是否 MySQL（user:pass@tcp(...) / @unix(...)）。
func isMySQLDSN(dsn string) bool {
	return strings.Contains(dsn, "@tcp(") || strings.Contains(dsn, "@unix(")
}

// UserRow users 表行
type UserRow struct {
	ID        uint      `gorm:"column:id;primaryKey;autoIncrement"`
	PlayerID  string    `gorm:"column:player_id;size:64;uniqueIndex"`
	TokenHash string    `gorm:"column:token_hash;size:128"`
	CreatedAt time.Time `gorm:"column:created_at"`
}

// TableName 表名
func (UserRow) TableName() string { return "users" }

// AuthTokenRow auth_tokens 表行
type AuthTokenRow struct {
	TokenHash string    `gorm:"column:token_hash;size:64;primaryKey"`
	PlayerID  string    `gorm:"column:player_id;size:64;index"`
	CreatedAt time.Time `gorm:"column:created_at"`
}

// TableName 表名
func (AuthTokenRow) TableName() string { return "auth_tokens" }

// AuthStore token 生成与校验
type AuthStore struct {
	db *gorm.DB
}

// NewAuthStore 建立 gorm 连接并确保表存在。
// dsn 支持 MySQL DSN（root:pass@tcp(host:port)/db?...）或 SQLite 文件路径。
func NewAuthStore(dsn string) (*AuthStore, error) {
	if strings.TrimSpace(dsn) == "" {
		return nil, errors.New("empty dsn")
	}
	db, err := openDB(dsn)
	if err != nil {
		return nil, err
	}
	if err := db.AutoMigrate(&UserRow{}, &AuthTokenRow{}); err != nil {
		return nil, err
	}
	return &AuthStore{db: db}, nil
}

// Login 登录：按 playerId 找用户，不存在则建立。返回用户 + 新 token。
// 每次登录签发新 token，旧 token 保留（多端）。
func (a *AuthStore) Login(playerID string) (token string, err error) {
	var u UserRow
	if err := a.db.Where("player_id = ?", playerID).First(&u).Error; err != nil {
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return "", err
		}
		u = UserRow{PlayerID: playerID}
		if err := a.db.Create(&u).Error; err != nil {
			return "", err
		}
	}
	token, tokHash, err := newToken()
	if err != nil {
		return "", err
	}
	row := AuthTokenRow{TokenHash: tokHash, PlayerID: playerID}
	if err := a.db.Create(&row).Error; err != nil {
		return "", err
	}
	return token, nil
}

// VerifyToken 校验 token，返回关联 playerId。无效返回空串。
func (a *AuthStore) VerifyToken(token string) (playerID string) {
	if token == "" {
		return ""
	}
	hash := sha256Hex(token)
	var row AuthTokenRow
	if err := a.db.Where("token_hash = ?", hash).First(&row).Error; err != nil {
		return ""
	}
	return row.PlayerID
}

// Close 释放连接
func (a *AuthStore) Close() error {
	sqlDB, err := a.db.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}

// newToken 生成随机 token 并返回其 SHA-256 摘要（落库存 hash）。
func newToken() (token, hash string, err error) {
	buf := make([]byte, 32)
	if _, err = rand.Read(buf); err != nil {
		return "", "", err
	}
	token = hex.EncodeToString(buf)
	return token, sha256Hex(token), nil
}

func sha256Hex(s string) string {
	sum := sha256.Sum256([]byte(s))
	return hex.EncodeToString(sum[:])
}