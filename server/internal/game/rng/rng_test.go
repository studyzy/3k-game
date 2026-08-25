package rng

import "testing"

// TestDeterministic 验证相同 seed 产生相同序列
func TestDeterministic(t *testing.T) {
	r1 := NewSeededRng(42)
	r2 := NewSeededRng(42)
	for i := 0; i < 20; i++ {
		a, b := r1.IntN(1000), r2.IntN(1000)
		if a != b {
			t.Fatalf("第%d次随机不同：%d vs %d（相同 seed 应确定性）", i, a, b)
		}
	}
}

// TestDifferentSeed 验证不同 seed 通常不同
func TestDifferentSeed(t *testing.T) {
	r1 := NewSeededRng(1)
	r2 := NewSeededRng(2)
	same := 0
	for i := 0; i < 20; i++ {
		if r1.IntN(1000) == r2.IntN(1000) {
			same++
		}
	}
	if same >= 20 {
		t.Error("不同 seed 应产生不同序列")
	}
}

// TestIntN 验证边界
func TestIntN(t *testing.T) {
	r := NewSeededRng(7)
	if v := r.IntN(0); v != 0 {
		t.Errorf("IntN(0) 应返回0，实际 %d", v)
	}
	for i := 0; i < 100; i++ {
		v := r.IntN(10)
		if v < 0 || v >= 10 {
			t.Fatalf("IntN(10) 应在 [0,10)，实际 %d", v)
		}
	}
}

// TestIntRange 验证区间与参数交换
func TestIntRange(t *testing.T) {
	r := NewSeededRng(9)
	// 单值
	if v := r.IntRange(5, 5); v != 5 {
		t.Errorf("IntRange(5,5) 应返回5，实际 %d", v)
	}
	// min>max 交换
	if v := r.IntRange(10, 5); v < 5 || v > 10 {
		t.Errorf("IntRange(10,5) 应在 [5,10]，实际 %d", v)
	}
	// 正常区间
	for i := 0; i < 100; i++ {
		v := r.IntRange(1, 3)
		if v < 1 || v > 3 {
			t.Fatalf("IntRange(1,3) 应在 [1,3]，实际 %d", v)
		}
	}
}

// TestChance 验证概率边界
func TestChance(t *testing.T) {
	r := NewSeededRng(11)
	if r.Chance(0) {
		t.Error("Chance(0) 应恒为 false")
	}
	if !r.Chance(1) {
		t.Error("Chance(1) 应恒为 true")
	}
}

// TestPick 验证随机取索引
func TestPick(t *testing.T) {
	r := NewSeededRng(13)
	if v := r.Pick(0); v != -1 {
		t.Errorf("Pick(0) 应返回-1，实际 %d", v)
	}
	for i := 0; i < 100; i++ {
		v := r.Pick(5)
		if v < 0 || v >= 5 {
			t.Fatalf("Pick(5) 应在 [0,5)，实际 %d", v)
		}
	}
}

// TestSeedAccess 验证种子访问
func TestSeedAccess(t *testing.T) {
	r := NewSeededRng(1234)
	if r.Seed() != 1234 {
		t.Errorf("Seed() 应返回1234，实际 %d", r.Seed())
	}
}

// TestFloat64 验证浮点范围
func TestFloat64(t *testing.T) {
	r := NewSeededRng(17)
	for i := 0; i < 100; i++ {
		v := r.Float64()
		if v < 0 || v >= 1 {
			t.Fatalf("Float64 应在 [0,1)，实际 %v", v)
		}
	}
}
