# 霸王的大陆（三国志2 复刻版）- Godot 3.x 反编译工程
# 用法: make [setup|import|run|edit|check|clean|help]
#
# 说明：
#   - setup 安装依赖环境（下载 Godot 编辑器，macOS）
#   - import headless 导入资源（生成 .import/.godot 缓存，仓库不追踪导入产物）
#   - run   运行游戏主场景（运行前自动导入资源）
#   - edit  打开 Godot 编辑器
#   - check headless 校验工程（检查脚本语法）
#   - clean 清理导入缓存（下次运行会自动重新导入）

# Godot 版本（3.x LTS 最终版）
GODOT_VERSION ?= 3.6.3

# 本地 Godot 编辑器（setup 安装位置）
GODOT_APP = Godot_$(GODOT_VERSION).app
GODOT_BIN = $(GODOT_APP)/Contents/MacOS/Godot

# Godot 下载地址（macOS universal）
GODOT_URL = https://github.com/godotengine/godot/releases/download/$(GODOT_VERSION)-stable/Godot_v$(GODOT_VERSION)-stable_osx.universal.zip

# Godot 可执行文件：优先本地 app，其次 PATH 中的 godot（其它平台），最后回退本地路径
GODOT ?= $(shell if [ -x "$(GODOT_BIN)" ]; then printf '%s' "$(GODOT_BIN)"; \
          else command -v godot 2>/dev/null || printf '%s' "$(GODOT_BIN)"; fi)

# 反编译工程目录
PROJECT ?= bwdl

.PHONY: setup
setup: ## 安装依赖环境（下载并解压 Godot 编辑器）
	@if [ -x "$(GODOT_BIN)" ]; then \
		echo "Godot $(GODOT_VERSION) 已安装: $(GODOT_BIN)"; \
	else \
		echo "==> 下载 Godot $(GODOT_VERSION) ..."; \
		curl -L -o /tmp/godot.zip "$(GODOT_URL)" && \
		unzip -q -o /tmp/godot.zip -d /tmp/godot_setup && \
		rm -rf "$(GODOT_APP)" && \
		mv /tmp/godot_setup/Godot.app "$(GODOT_APP)" && \
		rm -rf /tmp/godot.zip /tmp/godot_setup && \
		xattr -dr com.apple.quarantine "$(GODOT_APP)" 2>/dev/null || true; \
		echo "==> Godot $(GODOT_VERSION) 安装完成: $(GODOT_BIN)"; \
	fi

# Godot 3.x 无 --import 参数，headless 导入通过后台运行编辑器、等待 .stex 数量稳定后结束
.PHONY: import
import: ## headless 导入资源（生成 .import/.godot 缓存）
	@if [ -d "$(PROJECT)/.import" ] && [ "$$(find $(PROJECT)/.import -name '*.stex' 2>/dev/null | wc -l | tr -d ' ')" != "0" ]; then \
		echo "==> 资源已导入，跳过"; \
	else \
		echo "==> 导入资源..."; \
		$(GODOT) --headless --path $(PROJECT) --editor > /tmp/godot_import.log 2>&1 & \
		pid=$$!; prev=0; i=0; \
		while [ $$i -lt 120 ]; do \
			cur=$$(find $(PROJECT)/.import -name '*.stex' 2>/dev/null | wc -l | tr -d ' '); \
			if [ "$$cur" != "0" ] && [ "$$cur" = "$$prev" ]; then break; fi; \
			prev=$$cur; i=$$((i+1)); sleep 1; \
		done; \
		kill $$pid 2>/dev/null; wait $$pid 2>/dev/null; \
		echo "==> 导入完成 ($$cur 个纹理)"; \
	fi

.PHONY: run
run: import ## 运行游戏（主场景，运行前自动导入资源）
	"$(GODOT)" --path $(PROJECT)

.PHONY: edit
edit: ## 打开 Godot 编辑器
	"$(GODOT)" --path $(PROJECT) --editor

.PHONY: check
check: ## headless 校验工程（检查脚本语法）
	"$(GODOT)" --headless --path $(PROJECT) --editor --quit

.PHONY: clean
clean: ## 清理导入缓存与编辑器缓存（下次运行会自动重新导入）
	rm -rf "$(PROJECT)/.import" "$(PROJECT)/.godot"

.PHONY: help
help: ## 显示帮助
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
