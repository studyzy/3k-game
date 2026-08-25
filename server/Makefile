# 3k-server 构建/运行
#
# ⚠️ 本机环境坑：本机 GOROOT 被错误指向 go1.26.5 模块工具链目录（golang.org/toolchain@v0.0.1-go1.26.5.darwin-arm64），
# 与系统 go1.24.12 冲突，会报 "version does not match go tool version"。
#
# 处理：仅当 `go env GOROOT` 解析到 go 官方安装目录时才允许使用；若解析到模块工具链目录（含 "toolchain" 字样）
# 则回退到 /usr/local/go。CI（setup-go）GOROOT 为官方目录，走正常分支。
GOROOT_RESOLVED := $(shell go env GOROOT)
GOROOT_IS_TOOLCHAIN := $(findstring toolchain,$(GOROOT_RESOLVED))
ifeq ($(GOROOT_IS_TOOLCHAIN),)
GOOROOT_VAL := $(GOROOT_RESOLVED)
else
GOOROOT_VAL := /usr/local/go
endif
GO := GOROOT=$(GOOROOT_VAL) GOTOOLCHAIN=local go

.PHONY: build run tidy vet test build-mockserver db-up db-down integration

# 构建服务器二进制
build:
	$(GO) build -o bin/3k-server ./cmd/server

# 构建 MockServer（客户端测试用）
build-mockserver:
	$(GO) build -o bin/3k-mockserver ./cmd/mockserver

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

# mysql 端口/库可在环境变量覆盖：MYSQL_PORT、MYSQL_DATABASE、MYSQL_USER、MYSQL_PASSWORD
# 启动 docker MySQL（含 db/init/*.sql 首次自动执行）
db-up:
	docker compose up -d db

# 停止 docker MySQL（保留数据卷）
db-down:
	docker compose down

# 端到端集成测试：构建 server → 用 SQLite 临时库（静态数据由内嵌种子 JSON 自动初始化）→
# 启动子进程（默认随机端口 18080）→ go test → 清理临时库。
# 无需 docker MySQL；INT_DB 可覆盖 sqlite 库路径。
INT_PORT ?= 18080
INT_DB ?= $(CURDIR)/data/3k-integration.db
integration: build
	@echo "==> 使用 SQLite 临时库: $(INT_DB)"
	@rm -f "$(INT_DB)" "$(INT_DB)-wal" "$(INT_DB)-shm"
	@echo "==> 启动 server (localhost:$(INT_PORT))"
	@env INT_TEST_PROCESS="$(CURDIR)/bin/3k-server" \
		INT_TEST_BASE_URL="http://127.0.0.1:$(INT_PORT)" \
		INT_TEST_DB="1" \
		3K_LISTEN="127.0.0.1:$(INT_PORT)" \
		3k_DSN="$(INT_DB)" \
		3K_DATA_DIR="$(CURDIR)/data" \
		GOROOT=$(GOOROOT_VAL) GOTOOLCHAIN=local \
		go test ./test/integration -v -count=1; \
		rc=$$?; rm -f "$(INT_DB)" "$(INT_DB)-wal" "$(INT_DB)-shm"; exit $$rc
	@echo "==> 集成测试完成"