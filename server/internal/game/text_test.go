package game

import (
	"testing"

	"3k-server/internal/game/entities"
)

// TestNewTexts 验证文案表结构
func TestNewTexts(t *testing.T) {
	texts := newTestTexts(t)
	if len(texts.SkillNames) != 50 {
		t.Errorf("SkillNames 应为50项，实际 %d", len(texts.SkillNames))
	}
	if len(texts.SkillsName) != 5 {
		t.Errorf("SkillsName 应为5组，实际 %d", len(texts.SkillsName))
	}
	if len(texts.PlanName) != 16 {
		t.Errorf("PlanName 应为16项，实际 %d", len(texts.PlanName))
	}
	if len(texts.CaiProportion) != 4 {
		t.Errorf("CaiProportion 应为4地形，实际 %d", len(texts.CaiProportion))
	}
	for _, ter := range texts.CaiProportion {
		if len(ter) != 4 || len(ter[0]) != 3 {
			t.Errorf("CaiProportion 应为4x4x3，实际 %dx%d", len(ter), len(ter[0]))
		}
	}
}

// TestSearchResultTexts 验证搜索结果文案
func TestSearchResultTexts(t *testing.T) {
	texts := newTestTexts(t)
	results := texts.SearchResultTexts()
	if len(results) == 0 {
		t.Fatal("搜索结果文案不应为空")
	}
	for _, r := range results {
		if r == "" {
			t.Error("搜索结果文案不应有空白项")
		}
	}
}

// TestPhaseDiff 验证相性差计算
func TestPhaseDiff(t *testing.T) {
	w := newTestWorld(t)
	a := &entities.General{Phase: 10}
	b := &entities.General{Phase: 20}
	// 正常差 10
	if v := w.PhaseDiff(a, b); v != 10 {
		t.Errorf("相性差应得10，实际 %d", v)
	}
	// 反向也取绝对值
	if v := w.PhaseDiff(b, a); v != 10 {
		t.Errorf("反向相性差应得10，实际 %d", v)
	}
	// 差>74 时环绕：149-d
	c := &entities.General{Phase: 10}
	d := &entities.General{Phase: 100}
	if v := w.PhaseDiff(c, d); v != 149-90 {
		t.Errorf("相性差90应环绕为59，实际 %d", v)
	}
	// nil 返回0
	if v := w.PhaseDiff(nil, b); v != 0 {
		t.Errorf("nil 武将应返回0，实际 %d", v)
	}
}
