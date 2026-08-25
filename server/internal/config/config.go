package config

import (
	"net"
	"os"
	"strconv"
	"strings"

	"github.com/zeromicro/go-zero/rest"
)

// Config 服务器配置。
// 开发期 InMemory 默认 true（不依赖 DB）；接入 MySQL 时通过环境变量 3k_DSN 传入连接串。
type Config struct {
	rest.RestConf
	DataSource string `json:",optional"` // MySQL gorm DSN（如 root:root@tcp(127.0.0.1:3306)/3k?charset=utf8mb4&parseTime=True）
	SQLitePath string `json:",optional"` // SQLite 静态数据文件路径（DataSource 为空时使用）
	// 开发期无 redis/mysql 时置 true，存档用内存态
	InMemory bool `json:",default=true"`
}

// env 取环境变量，不存在给默认值。
func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// envBool 取布尔环境变量。
func envBool(key string, def bool) bool {
	if v := os.Getenv(key); v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			return b
		}
	}
	return def
}

// envInt 取整型环境变量。
func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

// splitHostPort 切分 "host:port"。
// 返回 host（缺省时 ""）、port。解析失败返回 ok=false。
func splitHostPort(addr string) (host string, port int, ok bool) {
	host, portStr, err := net.SplitHostPort(addr)
	if err != nil {
		return "", 0, false
	}
	p, err := strconv.Atoi(portStr)
	if err != nil {
		return "", 0, false
	}
	if host == "" {
		host = "0.0.0.0"
	}
	_ = strings.HasPrefix(host, "::") // 兼容 IPv6 形式
	return host, p, true
}

// Default 返回默认配置（可被环境变量覆盖）。
//
// 环境变量：
//
//	3k_DSN          MySQL/gorm DSN，非空则 InMemory=false 且静态数据走 MySQL
//	3K_IN_MEMORY    true/false，显式指定是否内存态（默认据 DSN 是否设置）
//	3K_LISTEN      server 监听地址 host:port（默认 0.0.0.0:8080）
//	3K_SQLITE_PATH  SQLite 静态数据文件路径（默认 data/3k.db）
func Default() Config {
	var c Config
	c.Host = "0.0.0.0"
	c.Port = 8080
	c.SQLitePath = env("3K_SQLITE_PATH", "data/3k.db")

	dsn := env("3k_DSN", "")
	c.DataSource = dsn
	if v := os.Getenv("3K_IN_MEMORY"); v != "" {
		c.InMemory = envBool("3K_IN_MEMORY", true)
	} else {
		c.InMemory = dsn == ""
	}

	_ = envInt // 预留：常用整型环境变量
	// 覆盖监听地址：3K_LISTEN=127.0.0.1:9090 或 :9090
	if addr := env("3K_LISTEN", ""); addr != "" {
		if host, port, ok := splitHostPort(addr); ok {
			c.Host = host
			c.Port = port
		}
	}
	return c
}