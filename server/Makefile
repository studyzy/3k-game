# 3k-server 构建/运行（解决本机 GOROOT 指向 go1.26.5 模块工具链的坑）
# 必须用 GOROOT=/usr/local/go + GOTOOLCHAIN=local，否则 stdlib 版本不匹配。
GO := GOROOT=/usr/local/go GOTOOLCHAIN=local go

.PHONY: build run tidy vet test

# 构建服务器二进制
build:
	$(GO) build -o bin/3k-server ./cmd/server

# 直接运行（开发）
run:
	$(GO) run ./cmd/server

# 整理依赖
tidy:
	$(GO) mod tidy

# 静态检查
vet:
	$(GO) vet ./...

# 运行全部 Go 测试（含游戏逻辑单测）
test:
	$(GO) test ./internal/... -v
