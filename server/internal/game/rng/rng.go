package rng

import (
	"math/rand"
	"sync"
)

// SeededRng 可播种的随机数生成器。
// 每局一个实例，单 goroutine 内顺序调用以保证确定性回放。
type SeededRng struct {
	r    *rand.Rand
	seed int64
	mu   sync.Mutex
}

// NewSeededRng 用 seed 创建 RNG。
func NewSeededRng(seed int64) *SeededRng {
	return &SeededRng{r: rand.New(rand.NewSource(seed)), seed: seed}
}

// Seed 返回初始种子（用于存档/回放）
func (s *SeededRng) Seed() int64 { return s.seed }

// IntN 返回 [0,n) 区间的随机整数，对应 GDScript randi_range(0, n-1)。
func (s *SeededRng) IntN(n int) int {
	if n <= 0 {
		return 0
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.r.Intn(n)
}

// IntRange 返回 [min,max] 区间的随机整数，对应 GDScript randi_range(min, max)。
func (s *SeededRng) IntRange(min, max int) int {
	if max < min {
		min, max = max, min
	}
	if max == min {
		return min
	}
	return min + s.IntN(max-min+1)
}

// Float64 返回 [0,1) 区间的随机浮点数，对应 GDScript randf()。
func (s *SeededRng) Float64() float64 {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.r.Float64()
}

// Chance 返回概率 p（0.0~1.0）是否命中，对应 GDScript randf() < p。
func (s *SeededRng) Chance(p float64) bool {
	if p <= 0 {
		return false
	}
	if p >= 1 {
		return true
	}
	return s.Float64() < p
}

// Shuffle 原地打乱切片，对应 GDScript array.shuffle()。
func (s *SeededRng) Shuffle(n int, swap func(i, j int)) {
	if n <= 1 {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.r.Shuffle(n, swap)
}

// Pick 从切片中随机取一个，返回索引。对应 GDScript array[randi() % array.size()]。
func (s *SeededRng) Pick(size int) int {
	if size <= 0 {
		return -1
	}
	return s.IntN(size)
}
