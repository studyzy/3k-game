package config

import "github.com/zeromicro/go-zero/rest"

type Config struct {
	rest.RestConf
	DataSource string `json:",optional"` // redis/mysql 地址（开发期可选）
	DataDir    string `json:",optional"`
	// 开发期无 redis/mysql 时置 true，用内存态
	InMemory bool `json:",default=true"`
}
