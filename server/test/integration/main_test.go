package integration

import (
	"context"
	"os"
	"os/exec"
	"testing"
	"time"
)

// 兼容 WebSocket 协议
// OpSelectKing 等常量在 server 侧 ws/protocol.go，这里镜像一份用于测试。
const (
	OpSelectKing   = 0x100
	OpExecuteTask  = 0x106
	OpEndTurn      = 0x107
	OpDelta        = 0x201
	OpTaskResult   = 0x202
	OpTurnResult   = 0x203
)

// TestMain 负责：
//   1. 若可通过环境变量 INT_TEST_PROC 拿到二进制路径，则启动 server 子进程（指向 MySQL）。
//   2. 等待就绪后交由各测试用例执行。
//
// 由 `make integration` 设置：INT_TEST_PROC=<bin/3k-server>、3k_DSN=...、3K_LISTEN=127.0.0.1:PORT。
func TestMain(m *testing.M) {
	proc := os.Getenv("INT_TEST_PROCESS")
	if proc == "" {
		// 兼容旧变量名
		proc = os.Getenv("INT_TEST_PROC")
	}

	if proc == "" {
		// 未配置子进程路径（例如直接 `go test ./test/integration` 且无外部 server）：跳过启动
		os.Exit(m.Run())
	}

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	cmd := exec.CommandContext(ctx, proc)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		panic("启动 server 失败: " + err.Error())
	}
	go func() { done <- cmd.Wait() }()

	// 等待端口就绪（最多 15s）
	waitReady(baseURL(), 15*time.Second)

	code := m.Run()

	cancel() // 终止子进程
	select {
	case <-done:
	case <-time.After(3 * time.Second):
	}
	os.Exit(code)
}

// waitReady 轮询 HTTP 直至 200。
func waitReady(url string, timeout time.Duration) {
	c := newClient()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		resp, err := c.hc.Get(url + "/game/new")
		if err == nil {
			resp.Body.Close()
			return
		}
		time.Sleep(500 * time.Millisecond)
	}
	panic("server 未在超时内就绪: " + url)
}