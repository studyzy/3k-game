# 全知 AI Agent 敌方决策服务（设计文档 §4.1 / 附录 E）
# 构建：docker build -t 3k-war-agent agent-service/
# 运行：docker run --rm --read-only --tmpfs /tmp -p 8060:8060 \
#         -v "$PWD/bwdl/build/web:/app/web:ro" \
#         -v "$PWD/agent-service/data:/app/data" \
#         -e K3G_AGENT_MODE=mock \
#         --network=none   # 出站白名单由外层网络策略控制；mock/stub 无需外网
#         3k-war-agent
# 注：/app/data 卷存放云存档（/save），必须挂可写卷 —— 根文件系统是只读的，
#     不挂载时写入失败，云存档不可用。
FROM node:24-alpine

WORKDIR /app

# 依赖精确版本来自 package-lock.json；--ignore-scripts 与 Pi 官方安装方式一致
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund && npm cache clean --force

COPY src ./src
COPY dashboard ./dashboard

# 源文件在宿主机可能为 600（仅属主可读），切换非 root 用户前统一放权
RUN chmod -R a+rX /app/src /app/dashboard /app/package.json /app/package-lock.json

ENV NODE_ENV=production \
    PORT=8060 \
    WEB_DIR=/app/web \
    SAVE_DIR=/app/data/saves \
    K3G_AGENT_MODE=mock

# 云存档目录：构建期建好并放权，运行时以只读根文件系统 + 可写卷 /app/data 覆盖
RUN mkdir -p /app/data/saves && chown -R node:node /app/data

# 非 root 运行；只读根文件系统 + 无宿主挂载（web 目录以 ro 挂载）
USER node
EXPOSE 8060

CMD ["node", "src/server.ts"]
