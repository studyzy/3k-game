package persist

import (
	"os"
	"testing"
)

// 手工探针：仅当 3K_TEST_MYSQL_DSN 设置时运行，验证 MySQL 存取与登录链路。
func TestMySQLProbe(t *testing.T) {
	dsn := os.Getenv("3K_TEST_MYSQL_DSN")
	if dsn == "" {
		t.Skip("未设置 3K_TEST_MYSQL_DSN")
	}
	st, err := NewMySQLStore(dsn)
	if err != nil {
		t.Fatalf("NewMySQLStore: %v", err)
	}
	defer st.Close()
	if err := st.Save("it_probe", "s1", []byte(`{"hello":"world"}`)); err != nil {
		t.Fatalf("Save: %v", err)
	}
	b, err := st.Load("it_probe", "s1")
	if err != nil || string(b) != `{"hello":"world"}` {
		t.Fatalf("Load: %s err=%v", string(b), err)
	}
	t.Log("MySQLStore save/load OK")

	auth, err := NewAuthStore(dsn)
	if err != nil {
		t.Fatalf("NewAuthStore: %v", err)
	}
	defer auth.Close()
	tok, err := auth.Login("probe-user")
	if err != nil {
		t.Fatalf("Login: %v", err)
	}
	if uid := auth.VerifyToken(tok); uid != "probe-user" {
		t.Fatalf("VerifyToken 期望 probe-user，实际 %q", uid)
	}
	t.Log("AuthStore login/verify OK")
}