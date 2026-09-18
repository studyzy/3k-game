# 霸王的大陆（三国志2 复刻版）- Godot 3.x 反编译工程
# 用法: make [setup|import|run|edit|check|clean|build|setup-apk|apk|help]
#
# 说明：
#   - setup 安装依赖环境（brew 安装 Godot 3.6，macOS）
#   - import 无窗口导入资源（生成 .import/.godot 缓存，仓库不追踪导入产物）
#   - run   运行游戏主场景（运行前自动导入资源）
#   - edit  打开 Godot 编辑器
#   - check 无窗口校验工程（检查脚本语法）
#   - clean 清理导入缓存（下次运行会自动重新导入）
#   - build 导出 macOS app（运行前自动导入资源）
#   - setup-apk 安装 Android 导出依赖（JDK17 / Android SDK / 导出模板 / keystore）
#   - apk   导出 Android release APK（脚本编译为字节码 + release 签名，导出前自动导入资源）
#
# 注：Godot 3.x 无 --headless 参数（那是 4.x 的），无窗口运行用 --no-window。
#     命令行里的 --no-window 仅对 windows/x11 平台生效；CI 用 linux_headless 版二进制。

# Godot 版本（3.x LTS 最终版，需与系统安装的版本一致）
GODOT_VERSION ?= 3.6.3

# Godot 可执行文件：使用系统 PATH 中的 godot（brew cask godot@3 装于 /Applications/Godot.app），
# 可用 GODOT=... 覆盖为其他路径
GODOT ?= godot

# 反编译工程目录
PROJECT ?= bwdl
# 导入完成标记。放在 .import 目录外：Godot 编辑器扫描会把 .import 内无对应源资源的
# 「孤儿文件」清掉（2026-08-28 踩过，标记被 check/edit 清掉后 import 每次全量变慢）
IMPORT_DONE = $(PROJECT)/.import-complete

# ---- Android 导出相关 ----
# Godot 3.6 导出 Android 需要 JDK 17（不能用更高的 21）
JAVA_HOME_17 ?= /Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
# Android SDK 根目录（Godot 从环境变量 ANDROID_SDK_ROOT 读取）
ANDROID_SDK_ROOT ?= $(HOME)/Library/Android/sdk
# 需要的 SDK 组件版本（与 Godot 3.6 官方工具链一致）
ANDROID_BUILD_TOOLS ?= 34.0.0
ANDROID_PLATFORM ?= android-34
# brew 安装的 cmdline-tools 位置
ANDROID_CMDLINE_TOOLS ?= /opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin
# Godot 导出模板版本目录（Godot 3.x 在 macOS 用 templates/ 而非 export_templates/）
EXPORT_TEMPLATES_DIR ?= $(HOME)/Library/Application Support/Godot/templates/$(GODOT_VERSION).stable
EXPORT_TEMPLATES_URL ?= https://github.com/godotengine/godot/releases/download/$(GODOT_VERSION)-stable/Godot_v$(GODOT_VERSION)-stable_export_templates.tpz
# Godot 3.x 编辑器设置文件（Android SDK / keystore / JDK 路径由此读取，环境变量仅在首次创建时生效）
GODOT_EDITOR_SETTINGS ?= $(HOME)/Library/Application Support/Godot/editor_settings-3.tres
# 正式签名 keystore（release 导出用；文件不入库，请自行备份，丢失后已装用户无法覆盖升级）
# export_presets.cfg 里写的是相对项目目录的路径 .ci-signing/release.keystore，
# 本地用软链指向这里，CI 用 secret 还原到项目内同名位置。用户/密码两边需一致。
RELEASE_KEYSTORE ?= $(HOME)/.android/bwdl-release.keystore
# export_presets.cfg 中 keystore/release 的相对路径基准是项目目录
RELEASE_KEYSTORE_LINK ?= $(PROJECT)/.ci-signing/release.keystore
RELEASE_KEYSTORE_USER ?= bwdl
RELEASE_KEYSTORE_PASS ?= bwdl-release

.PHONY: setup
setup: ## 安装依赖环境（brew 安装 Godot 3.6）
	@if command -v godot >/dev/null 2>&1; then \
		echo "Godot 已安装: $$(command -v godot) ($$(godot --version))"; \
	else \
		echo "==> 未找到 godot，通过 brew 安装 godot@$(GODOT_VERSION) ..."; \
		brew install --cask godot@$(GODOT_VERSION) || \
			{ echo "错误: brew 安装失败，请手动安装 Godot $(GODOT_VERSION)"; exit 1; }; \
		echo "==> Godot $(GODOT_VERSION) 安装完成: $$(command -v godot)"; \
	fi

# Godot 3.x 无 --import 参数，headless 导入通过后台运行编辑器、等待 .stex 数量稳定后结束。
# 坑1（2026-08-28 踩过）：全量导入 3000+ 纹理远超 1 分钟，旧逻辑「1 秒不变即稳定 + 120 秒上限」
# 会中途杀掉编辑器留下半残缓存，run 时 SceneManager 等 Autoload 加载失败报 Nil。
# 坑2（2026-08-28 实验发现）：小变更（如新增1张图）时编辑器「先扫描完才导入」，扫描的几秒里
# stex 计数一直不变，旧阈值 5 秒会在导入开始前误杀编辑器、还误写完成标记，新资源永远导不进来。
# 现改为：连续 30 秒 stex 数不变才视为稳定（须覆盖扫描+导入全程无产出），上限 1 小时；
# 完成后写 .import-complete 标记（在 .import 目录外，防编辑器孤儿清理删掉它），
# 后续 run/build 只看标记，中断过的导入不会被误判为已完成。
.PHONY: import
import: ## headless 导入资源（生成 .import/.godot 缓存）
	@if [ -f "$(IMPORT_DONE)" ]; then \
		echo "==> 资源已导入，跳过"; \
	else \
		echo "==> 导入资源（全量需数分钟，请勿中断）..."; \
		$(GODOT) --no-window --path $(PROJECT) --editor > /tmp/godot_import.log 2>&1 & \
		pid=$$!; prev=-1; stable=0; i=0; done=0; \
		while [ $$i -lt 3600 ]; do \
			kill -0 $$pid 2>/dev/null || { done=1; break; }; \
			cur=$$(find $(PROJECT)/.import -name '*.stex' 2>/dev/null | wc -l | tr -d ' '); \
			if [ "$$cur" != "0" ] && [ "$$cur" = "$$prev" ]; then \
				stable=$$((stable+1)); \
				if [ $$stable -ge 30 ]; then break; fi; \
			else \
				stable=0; \
			fi; \
			prev=$$cur; i=$$((i+1)); sleep 1; \
		done; \
		kill $$pid 2>/dev/null; wait $$pid 2>/dev/null; \
		cur=$$(find $(PROJECT)/.import -name '*.stex' 2>/dev/null | wc -l | tr -d ' '); \
		if [ "$$done" = "1" ] || [ $$i -lt 3600 ]; then \
			touch "$(IMPORT_DONE)"; \
			echo "==> 导入完成 ($$cur 个纹理)"; \
		else \
			echo "==> 导入超时未完成 ($$cur 个纹理)，请重新执行 make import"; \
		fi; \
	fi

.PHONY: run
run: import ## 运行游戏（主场景，运行前自动导入资源）
	"$(GODOT)" --path $(PROJECT)

.PHONY: edit
edit: ## 打开 Godot 编辑器
	"$(GODOT)" --path $(PROJECT) --editor

.PHONY: check
check: ## headless 校验工程（检查脚本语法）
	"$(GODOT)" --no-window --path $(PROJECT) --editor --quit

.PHONY: clean
clean: ## 清理导入缓存与编辑器缓存（下次运行会自动重新导入）
	rm -rf "$(PROJECT)/.import" "$(PROJECT)/.godot"
	rm -f "$(IMPORT_DONE)"

# ---- macOS 导出 ----

.PHONY: build
build: import ## 导出 macOS app（自动导入资源）
	@mkdir -p "$(PROJECT)/build"
	"$(GODOT)" --no-window --path "$(PROJECT)" --export-debug "Mac OSX" "$(abspath $(PROJECT)/build/bwdl.app)"
	@echo "==> app 已生成:"
	@ls -la "$(PROJECT)/build/bwdl.app"

# ---- Android 导出 ----

.PHONY: setup-apk
setup-apk: ## 安装 Android 导出依赖（JDK17 / Android SDK / 导出模板 / keystore）
	@echo "==> [1/6] 检查 JDK 17 ..."
	@if [ ! -x "$(JAVA_HOME_17)/bin/java" ]; then \
		echo "错误: 未找到 JDK 17，请安装后设置 JAVA_HOME_17（如 brew install --cask temurin@17）"; exit 1; \
	else echo "JDK 17: $(JAVA_HOME_17)"; fi
	@echo "==> [2/6] 检查 Android cmdline-tools ..."
	@if [ ! -x "$(ANDROID_CMDLINE_TOOLS)/sdkmanager" ]; then \
		brew install --cask android-commandlinetools; \
	fi
	@echo "==> [3/6] 安装 SDK 组件并接受许可 ..."
	@mkdir -p "$(ANDROID_SDK_ROOT)"
	@yes | "$(ANDROID_CMDLINE_TOOLS)/sdkmanager" --sdk_root="$(ANDROID_SDK_ROOT)" --licenses > /tmp/sdk_licenses.log 2>&1 || true
	@"$(ANDROID_CMDLINE_TOOLS)/sdkmanager" --sdk_root="$(ANDROID_SDK_ROOT)" \
		"platform-tools" "build-tools;$(ANDROID_BUILD_TOOLS)" "platforms;$(ANDROID_PLATFORM)"
	@echo "==> [4/6] 安装 Godot 导出模板 + 生成 debug keystore ..."
	@if [ ! -f "$(EXPORT_TEMPLATES_DIR)/android_release.apk" ]; then \
		echo "下载导出模板 ..."; \
		mkdir -p "$(EXPORT_TEMPLATES_DIR)"; \
		curl -L -o /tmp/godot_templates.tpz "$(EXPORT_TEMPLATES_URL)" && \
		unzip -q -o /tmp/godot_templates.tpz -d /tmp/godot_templates && \
		cp -R /tmp/godot_templates/templates/* "$(EXPORT_TEMPLATES_DIR)/" && \
		rm -rf /tmp/godot_templates.tpz /tmp/godot_templates; \
	else echo "导出模板已安装: $(EXPORT_TEMPLATES_DIR)"; fi
	@if [ ! -f "$(HOME)/.android/debug.keystore" ]; then \
		echo "生成 debug keystore ..."; \
		mkdir -p "$(HOME)/.android"; \
		"$(JAVA_HOME_17)/bin/keytool" -keyalg RSA -genkeypair -alias androiddebugkey \
			-keypass android -keystore "$(HOME)/.android/debug.keystore" -storepass android \
			-dname "CN=Android Debug,O=Android,C=US" -validity 9999; \
	else echo "debug keystore 已存在: $(HOME)/.android/debug.keystore"; fi
	@echo "==> [5/6] 生成 release keystore 并链接到项目内 ..."
	@if [ ! -f "$(RELEASE_KEYSTORE)" ]; then \
		mkdir -p "$$(dirname "$(RELEASE_KEYSTORE)")"; \
		"$(JAVA_HOME_17)/bin/keytool" -genkeypair -alias "$(RELEASE_KEYSTORE_USER)" \
			-keyalg RSA -keysize 2048 -validity 10000 \
			-keystore "$(RELEASE_KEYSTORE)" -storepass "$(RELEASE_KEYSTORE_PASS)" \
			-keypass "$(RELEASE_KEYSTORE_PASS)" -dname "CN=Bwddl,O=Sgz,C=CN"; \
		echo "已生成: $(RELEASE_KEYSTORE)（请自行备份，丢失后已装用户无法覆盖升级）"; \
	else echo "release keystore 已存在: $(RELEASE_KEYSTORE)"; fi
	@mkdir -p "$$(dirname "$(RELEASE_KEYSTORE_LINK)")"; \
	if [ ! -e "$(RELEASE_KEYSTORE_LINK)" ]; then \
		ln -s "$(RELEASE_KEYSTORE)" "$(RELEASE_KEYSTORE_LINK)"; \
		echo "已链接: $(RELEASE_KEYSTORE_LINK) -> $(RELEASE_KEYSTORE)"; \
	elif [ -L "$(RELEASE_KEYSTORE_LINK)" ]; then \
		echo "链接已存在: $(RELEASE_KEYSTORE_LINK)"; \
	else echo "注意: $(RELEASE_KEYSTORE_LINK) 是实体文件（非软链），将直接使用它"; fi
	@echo "==> [6/6] 配置 Godot 编辑器设置（SDK / keystore / JDK 路径）..."
	@ES="$(GODOT_EDITOR_SETTINGS)"; mkdir -p "$$(dirname "$$ES")"; touch "$$ES"; \
	set_key() { k="$$1"; v="$$2"; \
		if grep -q "^$${k} = " "$$ES" 2>/dev/null; then \
			sed -i '' "s|^$${k} = .*|$${k} = \"$${v}\"|" "$$ES"; \
		else \
			printf '%s = "%s"\n' "$${k}" "$${v}" >> "$$ES"; \
		fi; }; \
	set_key "export/android/android_sdk_path" "$(ANDROID_SDK_ROOT)"; \
	set_key "export/android/debug_keystore" "$(HOME)/.android/debug.keystore"; \
	set_key "export/android/java_sdk_path" "$(JAVA_HOME_17)"; \
	echo "  android_sdk_path = $(ANDROID_SDK_ROOT)"; \
	echo "  debug_keystore   = $(HOME)/.android/debug.keystore"; \
	echo "  java_sdk_path    = $(JAVA_HOME_17)"
	@echo "==> setup-apk 完成"

.PHONY: apk
apk: setup-apk import ## 导出 Android release APK（脚本字节码 + release 签名，自动安装依赖并导入资源）
	@mkdir -p "$(PROJECT)/build"
	JAVA_HOME="$(JAVA_HOME_17)" ANDROID_SDK_ROOT="$(ANDROID_SDK_ROOT)" \
		"$(GODOT)" --no-window --path "$(PROJECT)" --export "Android" "$(abspath $(PROJECT)/build/bwdl.apk)"
	@echo "==> APK 已生成:"
	@ls -la "$(PROJECT)/build/bwdl.apk"

.PHONY: help
help: ## 显示帮助
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
