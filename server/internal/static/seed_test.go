package static

import (
	"testing"
)

// TestLoadConfigFromSeed 验证内嵌种子解析出的静态配置规模与字段对齐。
func TestLoadConfigFromSeed(t *testing.T) {
	cfg, err := loadConfigFromSeed()
	if err != nil {
		t.Fatalf("loadConfigFromSeed: %v", err)
	}
	if len(cfg.Generals) != 673 {
		t.Errorf("武将数 = %d, 期望 673", len(cfg.Generals))
	}
	if len(cfg.Cities) != 48 {
		t.Errorf("城池数 = %d, 期望 48", len(cfg.Cities))
	}
	if len(cfg.Countries) != 3 {
		t.Errorf("势力数 = %d, 期望 3", len(cfg.Countries))
	}
	if len(cfg.Weapons) != 32 {
		t.Errorf("武器数 = %d, 期望 32", len(cfg.Weapons))
	}
	if len(cfg.Maps) != 48 {
		t.Errorf("地图数 = %d, 期望 48", len(cfg.Maps))
	}
	if len(cfg.Formations) != 16 {
		t.Errorf("阵型数 = %d, 期望 16", len(cfg.Formations))
	}
	// 首张地图 19×32
	if g := cfg.Maps[1]; len(g) != 19 || len(g[0]) != 32 {
		t.Errorf("地图1 维度 = %dx%d, 期望 19x32", len(g), len(g[0]))
	}
	// 首个阵型 7×16
	if f := cfg.Formations["a0"]; len(f) != 7 || len(f[0]) != 16 {
		t.Errorf("阵型 a0 维度 = %dx%d, 期望 7x16", len(f), len(f[0]))
	}
}

// TestLoadTextsFromSeed 验证文案表规模（HJ 500、plan_explain 16、tactic_explain 6、solo_info 17）。
func TestLoadTextsFromSeed(t *testing.T) {
	texts, err := loadTextsFromSeed()
	if err != nil {
		t.Fatalf("loadTextsFromSeed: %v", err)
	}
	if len(texts.HJ) != 500 {
		t.Errorf("HJ 项数 = %d, 期望 500", len(texts.HJ))
	}
	if len(texts.PlanExplain) != 16 {
		t.Errorf("PlanExplain = %d, 期望 16", len(texts.PlanExplain))
	}
	if len(texts.TacticExplain) != 6 {
		t.Errorf("TacticExplain = %d, 期望 6", len(texts.TacticExplain))
	}
	if len(texts.SoloInfo) != 17 {
		t.Errorf("SoloInfo = %d, 期望 17", len(texts.SoloInfo))
	}
	if len(texts.SkillNames) != 50 {
		t.Errorf("SkillNames = %d, 期望 50", len(texts.SkillNames))
	}
	if len(texts.GameFail) == 0 {
		t.Error("GameFail 为空")
	}
}

// TestSQLiteOpen 验证 SQLite :memory: 打开 + AutoSeed + 读取。
func TestSQLiteOpen(t *testing.T) {
	store, err := Open(":memory:")
	if err != nil {
		t.Fatalf("Open(:memory:): %v", err)
	}
	defer store.Close()

	cfg, err := store.Config()
	if err != nil {
		t.Fatalf("Config: %v", err)
	}
	if len(cfg.Generals) != 673 {
		t.Errorf("SQLite 武将数 = %d, 期望 673", len(cfg.Generals))
	}

	texts, err := store.Texts()
	if err != nil {
		t.Fatalf("Texts: %v", err)
	}
	if len(texts.HJ) != 500 {
		t.Errorf("SQLite HJ = %d, 期望 500", len(texts.HJ))
	}

	all, err := store.AllStatic()
	if err != nil {
		t.Fatalf("AllStatic: %v", err)
	}
	if all["generals"] == nil || all["texts"] == nil {
		t.Error("AllStatic 缺少 generals/texts")
	}
}
