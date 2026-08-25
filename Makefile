# 霸王的大陆 - Godot 移植版
# 用法: make [run|test|check|test-<name>]

GODOT ?= godot
PROJECT := --path .

# 全部测试场景（不含 test_loop 压力测试，见 test 目标）
TESTS := battle endturn flow grid map plan prebattle scenes war warscene

# 逐场景生成目标: test-battle test-endturn ...
.PHONY: $(addprefix test-,$(TESTS)) test-loop

.PHONY: run
run: ## 运行游戏
	$(GODOT) $(PROJECT)

.PHONY: check
check: ## 校验工程（导入资源、报告缺失/错误）
	$(GODOT) --headless --editor $(PROJECT) --quit

.PHONY: test
test: ## 运行全部常规测试（逐个执行，遇错即停）
	@set -e; for t in $(TESTS); do \
		echo "==> 测试 $$t"; \
		$(GODOT) --headless $(PROJECT) res://scenes/tests/test_$$t.tscn || exit 1; \
	done
	@echo "全部测试通过"

.PHONY: test-loop
test-loop: ## 多回合压力测试（耗时较长）
	$(GODOT) --headless $(PROJECT) res://scenes/tests/test_loop.tscn

# 单场景测试: make test-flow
$(addprefix test-,$(TESTS)): test-%:
	$(GODOT) --headless $(PROJECT) res://scenes/tests/test_$*.tscn

.PHONY: help
help: ## 显示帮助
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
