# ==============================================================================
# 头像八帧表情修复 - 单元与集成测试包
#
# 用法（仓库根目录或 tools/avatar_gen 下）:
#   python3 -m unittest discover -s tests -v     # 在 tools/avatar_gen 目录内
#   python3 -m unittest discover -s tools/avatar_gen/tests -t .  # 顶层发现需 -t
#
# 测试不依赖真实游戏资产：全部使用程序合成的 32×40 / 256×40 假头像，
# 保证 headless 可跑、可重复（见 specs/001-fix-avatar-frames/research.md R7）。
# ==============================================================================
