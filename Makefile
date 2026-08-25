# 霸王的大陆 - Godot 纯 UI 客户端
# 用法: make [run|check|test|help]
#
# 客户端逻辑测试：Godot 侧用 gdUnit4（addons/gdUnit4/），网络层对接独立
# Go MockServer（server/cmd/mockserver/），回放预设 HTTP + WS 推送。

GODOT ?= godot
PROJECT := --path .

.PHONY: run
run: ## 运行客户端（需先启动服务器）
	$(GODOT) $(PROJECT)

.PHONY: check
check: ## headless 校验工程（导入资源、检查脚本错误）
	$(GODOT) --headless --editor $(PROJECT) --quit

.PHONY: build-mock
build-mock: ## 编译 MockServer 二进制
	cd server && make build && GOROOT=/usr/local/go GOTOOLCHAIN=local go build -o bin/3k-mockserver ./cmd/mockserver

.PHONY: test
test: ## 跑 Godot 客户端单元测试（需先 build-mock；内部自动起 MockServer）
	bash scripts/run_client_tests.sh

.PHONY: help
help: ## 显示帮助
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
