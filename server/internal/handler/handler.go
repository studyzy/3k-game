package handler

import (
	"net/http"

	"github.com/zeromicro/go-zero/rest/httpx"

	"3k-server/internal/logic"
	"3k-server/internal/svc"
	"3k-server/internal/types"
)

// HTTP 接口处理器层（go-zero handler）
// 所有 handler 只做请求解析 + 调 logic + 写响应，不含业务逻辑。

// LoginHandler 登录
func LoginHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.LoginRequest
		_ = r.ParseForm()
		req.PlayerId = r.FormValue("playerId")

		l := logic.New(svcCtx)
		token, err := l.Login(req.PlayerId)
		if err != nil {
			httpx.Error(w, err)
			return
		}
		httpx.OkJson(w, types.LoginResponse{
			Ok: true, Token: token, PlayerId: req.PlayerId,
		})
	}
}

// NewGameHandler 创建新局
func NewGameHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.NewGameRequest
		_ = r.ParseForm()
		req.PlayerId = r.FormValue("playerId")

		l := logic.New(svcCtx)
		sessionId, snapshot, err := l.CreateGame(req.PlayerId)
		if err != nil {
			httpx.OkJson(w, types.NewGameResponse{Ok: false, Msg: err.Error()})
			return
		}
		httpx.OkJson(w, types.NewGameResponse{Ok: true, SessionId: sessionId, Snapshot: snapshot})
	}
}

// SaveGameHandler 存档
func SaveGameHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.SaveGameRequest
		_ = r.ParseForm()
		req.PlayerId = r.FormValue("playerId")
		req.SessionId = r.FormValue("sessionId")
		req.SaveId = r.FormValue("saveId")

		l := logic.New(svcCtx)
		if err := l.SaveGame(req.PlayerId, req.SessionId, req.SaveId); err != nil {
			httpx.OkJson(w, types.SaveGameResponse{Ok: false, Msg: err.Error()})
			return
		}
		httpx.OkJson(w, types.SaveGameResponse{Ok: true, SaveId: req.SaveId})
	}
}

// StaticHandler 静态数据下发
func StaticHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		l := logic.New(svcCtx)
		data, err := l.Static()
		if err != nil {
			httpx.OkJson(w, types.StaticResponse{Ok: false, Msg: err.Error()})
			return
		}
		httpx.OkJson(w, types.StaticResponse{Ok: true, Data: data})
	}
}

// LoadGameHandler 读档
func LoadGameHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.LoadGameRequest
		_ = r.ParseForm()
		req.PlayerId = r.FormValue("playerId")
		req.SaveId = r.FormValue("saveId")

		l := logic.New(svcCtx)
		sessionId, snapshot, err := l.LoadGame(req.PlayerId, req.SaveId)
		if err != nil {
			httpx.OkJson(w, types.LoadGameResponse{Ok: false, Msg: err.Error()})
			return
		}
		httpx.OkJson(w, types.LoadGameResponse{Ok: true, SessionId: sessionId, Snapshot: snapshot})
	}
}
