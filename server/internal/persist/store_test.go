package persist

import (
	"testing"
)

// TestNewSaveStore 验证创建存档目录
func TestNewSaveStore(t *testing.T) {
	dir := t.TempDir()
	s, err := NewSaveStore(dir)
	if err != nil {
		t.Fatalf("创建存档目录失败: %v", err)
	}
	if s.Dir != dir {
		t.Errorf("存档目录应为 %s，实际 %s", dir, s.Dir)
	}
}

// TestSaveLoad 验证保存与读取往返一致
func TestSaveLoad(t *testing.T) {
	dir := t.TempDir()
	s, err := NewSaveStore(dir)
	if err != nil {
		t.Fatalf("创建存档目录失败: %v", err)
	}
	snapshot := []byte(`{"years":251,"month":3,"kingName":"test"}`)
	if err := s.Save("player1", "slot1", snapshot); err != nil {
		t.Fatalf("保存失败: %v", err)
	}
	loaded, err := s.Load("player1", "slot1")
	if err != nil {
		t.Fatalf("读取失败: %v", err)
	}
	if string(loaded) != string(snapshot) {
		t.Errorf("读档内容不一致:\n存: %s\n读: %s", snapshot, loaded)
	}
	// 读取不存在的存档报错
	if _, err := s.Load("player1", "missing"); err == nil {
		t.Error("读取不存在存档应报错")
	}
}

// TestList 验证列出存档元信息
func TestList(t *testing.T) {
	dir := t.TempDir()
	s, err := NewSaveStore(dir)
	if err != nil {
		t.Fatalf("创建存档目录失败: %v", err)
	}
	if err := s.Save("player1", "slot1", []byte(`{"years":251,"month":3}`)); err != nil {
		t.Fatalf("保存失败: %v", err)
	}
	if err := s.Save("player1", "slot2", []byte(`{"years":252,"month":6}`)); err != nil {
		t.Fatalf("保存失败: %v", err)
	}
	// 非 JSON 文件应被跳过
	if err := s.Save("player1", "bad", []byte("not json")); err != nil {
		t.Fatalf("保存失败: %v", err)
	}
	list := s.List("player1")
	if len(list) != 2 {
		t.Fatalf("应有2个有效存档，实际 %d", len(list))
	}
	foundSlot1, foundSlot2 := false, false
	for _, item := range list {
		switch item["saveId"] {
		case "slot1.json":
			if item["years"] != float64(251) || item["month"] != float64(3) {
				t.Errorf("slot1 元信息错误: %v", item)
			}
			foundSlot1 = true
		case "slot2.json":
			if item["years"] != float64(252) {
				t.Errorf("slot2 年份错误: %v", item)
			}
			foundSlot2 = true
		}
	}
	if !foundSlot1 || !foundSlot2 {
		t.Errorf("应列出 slot1 与 slot2，实际 %v", list)
	}
	// 不存在的玩家返回空
	if v := s.List("nobody"); v != nil {
		t.Errorf("不存在玩家应返回 nil，实际 %v", v)
	}
}
