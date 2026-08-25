package game

import "3k-server/internal/game/entities"

// Texts 文案与数值表（对应 scripts/data/text_library.gd）。
// json tag 与 seed_data/texts.json 的键一致（GDScript 常量名）。
type Texts struct {
	GeneralGrade       []string   `json:"GENERAL_GRADE"`
	TaskName           [][]string `json:"TASK_NAME"`
	SkillsName         [][]string `json:"SKILLS_NAME"`
	SkillNames         []string   `json:"skill_names"`
	DoThingsResultInfo [][]string `json:"do_things_result_info"`
	PlanName           []string   `json:"PLAN_NAME"`
	PlanExplain        []string   `json:"PLAN_EXPLAIN"`
	PlanResult         []string   `json:"PLAN_RESULT"`
	TacticNames        []string   `json:"TACTIC_NAMES"`
	TacticExplain      []string   `json:"TACTIC_EXPLAIN"`
	SoloInfo           []string   `json:"SOLO_INFO"`
	TopInf             []float64  `json:"TOP_INF"`
	CaiProportion      [][][]int  `json:"CAI_PROPORTION"`
	HJ                 []float64  `json:"HJ"`
	GameScript         []string   `json:"GAME_SCRIPT"`
	GameFail           string     `json:"GAME_FAIL"`
}

// SearchResultTexts 返回搜索结果文案（对应 do_things_result_info[6]）
func (t *Texts) SearchResultTexts() []string {
	return t.DoThingsResultInfo[6]
}

// PhaseDiff 计算相性差（对应 GeneralListCache.get_phase_difference / get_d_phase）
func (w *World) PhaseDiff(a, b *entities.General) int {
	if a == nil || b == nil {
		return 0
	}
	d := a.Phase - b.Phase
	if d < 0 {
		d = -d
	}
	if d > 74 {
		d = 149 - d
	}
	return d
}
