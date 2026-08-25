# 霸王的大陆（三国志2 复刻版）- Godot 3.5.3 反编译工程
# 用法: make [run|edit|check|clean|help]
#
# 说明：
#   - run   运行游戏主场景
#   - edit  打开 Godot 3.5.3 编辑器
#   - check headless 校验工程（导入资源 + 检查脚本语法）
#   - clean 清理导入缓存（下次打开会自动重新导入）

# Godot 3.5.3 可执行文件（本仓库自带 macOS 版；其它平台请自行指定，如 GODOT=godot353）
GODOT ?= Godot_3.5.3.app/Contents/MacOS/Godot

# 反编译工程目录
PROJECT ?= bwdl

.PHONY: run
run: ## 运行游戏（主场景）
	"$(GODOT)" --path $(PROJECT)

.PHONY: edit
edit: ## 打开 Godot 3.5.3 编辑器
	"$(GODOT)" --path $(PROJECT) --editor

.PHONY: check
check: ## headless 校验工程（导入资源、检查脚本错误）
	"$(GODOT)" --headless --path $(PROJECT) --editor --quit

.PHONY: clean
clean: ## 清理导入缓存与编辑器缓存（下次打开会自动重新导入）
	rm -rf "$(PROJECT)/.import" "$(PROJECT)/.godot"

.PHONY: help
help: ## 显示帮助
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
