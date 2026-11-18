# AI Agent 服务部署（战争场景敌方决策）

`agent-service/` 是一个 Node ≥22.19 的服务，提供 `POST /ai/decide`（整侧联合计划）
和 `/ai/health`、`/ai/traces`、`/ai/dashboard`。游戏内「大模型」难度会调用它，
服务不可用/超时/非法返回时游戏自动回退本地 `hard` 规则 AI。

## 部署形态（单机 systemd + Caddy 反代）

```
Browser ──> Caddy (443)
              ├─ /3k/*     → /var/www/3k（静态，wasm/pck 实际走 COS）
              └─ /ai/*     → 127.0.0.1:8060（agent-service）
                              └─ LLM_BASE_URL（本机 ccr 网关 127.0.0.1:3456 → hai hub）
```

游戏用 `window.location.origin + "/ai/decide"` 取地址，所以必须挂在**域名根**的
`/ai/` 下，不能是 `/3k/ai/`。

## 步骤

```bash
cd agent-service
npm install --registry=https://registry.npmmirror.com
cp .env.example .env && chmod 600 .env     # 填 LLM_BASE_URL / LLM_MODEL / LLM_API_KEY / K3G_AGENT_MODE=pi
node --test test/*.test.ts                 # 39 个测试，3 个跳过
```

`tools/web-deploy/k3-agent.service` 是 systemd 单元模板（把 `__PROJECT_ROOT__`
替换成仓库绝对路径后装到 `/etc/systemd/system/`）：

```bash
sudo sed "s#__PROJECT_ROOT__#$PWD/..#" ../tools/web-deploy/k3-agent.service \
  | sudo tee /etc/systemd/system/k3-agent.service
sudo systemctl daemon-reload && sudo systemctl enable --now k3-agent
```

Caddy 侧（`/etc/caddy/acli.d/routes/ai.caddy`）：

```
handle /ai/* {
	reverse_proxy 127.0.0.1:8060 {
		transport http {
			read_timeout 60s
		}
	}
}
```

## 不要把 8060 暴露到公网

node 会监听 `*:8060`。用 systemd 的内核级网络白名单限制成只允许回环：

```ini
# /etc/systemd/system/k3-agent.service.d/net.conf
[Service]
IPAddressAllow=localhost
IPAddressDeny=any
```

这样公网 `:8060` 直接连不通，只有 Caddy（127.0.0.1）能访问，同时 node 仍能连本机
LLM 网关。

## 验证

```bash
curl -s https://<域名>/ai/health            # {"ok":true,"mode":"pi",...}
curl -s -X POST https://<域名>/ai/decide \
  -H 'content-type: application/json' --data-binary @payload.json | jq .plan
```

浏览器里打开 `https://<域名>/ai/dashboard` 可以看每次决策的完整对话与工具调用轨迹。

注意：`/ai/decide` 目前**没有鉴权**，任何知道地址的人都能触发一次 LLM 决策（花 key 额度）。
若要限制，可在 Caddy 加 `header Origin` 校验或给页面发短期 token。