package main

import (
	"flag"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
	"github.com/zeromicro/go-zero/rest"

	"3k-server/internal/config"
	"3k-server/internal/handler"
	"3k-server/internal/logic"
	"3k-server/internal/svc"
	"3k-server/internal/ws"
)

var configFile = flag.String("f", "etc/server.yaml", "config file")

func main() {
	flag.Parse()
	_ = configFile

	c := loadConfig()
	svcCtx := svc.NewServiceContext(c)

	server := rest.MustNewServer(c.RestConf)
	defer server.Stop()

	// 注册 HTTP 接口
	registerHTTPRoutes(server, svcCtx)
	// 注册 WebSocket 游戏网关
	registerWSGateway(server, svcCtx)

	log.Printf("server listening on %s:%d", c.Host, c.Port)
	server.Start()
}

// loadConfig 加载配置（开发期用默认值，不读 yaml）
func loadConfig() config.Config {
	var c config.Config
	c.Host = "0.0.0.0"
	c.Port = 8080
	c.DataDir = "data"
	return c
}

// registerHTTPRoutes 注册 REST 接口
func registerHTTPRoutes(server *rest.Server, svcCtx *svc.ServiceContext) {
	server.AddRoutes([]rest.Route{
		{Method: http.MethodPost, Path: "/auth/login", Handler: handler.LoginHandler(svcCtx)},
		{Method: http.MethodPost, Path: "/game/new", Handler: handler.NewGameHandler(svcCtx)},
		{Method: http.MethodPost, Path: "/game/save", Handler: handler.SaveGameHandler(svcCtx)},
		{Method: http.MethodPost, Path: "/game/load", Handler: handler.LoadGameHandler(svcCtx)},
	})
}

// registerWSGateway 注册 WebSocket 游戏网关
func registerWSGateway(server *rest.Server, svcCtx *svc.ServiceContext) {
	l := logic.New(svcCtx)
	gw := &ws.Gateway{
		Upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true },
		},
		ResolveSession: func(w http.ResponseWriter, r *http.Request) (*ws.Session, error) {
			sessionId := r.URL.Query().Get("sessionId")
			playerId := r.URL.Query().Get("playerId")
			return l.ResolveSession(sessionId, playerId)
		},
		Handle: ws.DefaultHandler,
	}
	server.AddRoute(rest.Route{
		Method:  http.MethodGet,
		Path:    "/game/ws",
		Handler: gw.ServeWS,
	})
}
