-- 3k-server 数据库初始化
-- 由 docker-entrypoint-initdb.d 在数据卷首次创建时自动执行。
-- 玩家表 + 存档表 + 登录 token 表。

CREATE TABLE IF NOT EXISTS users (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    player_id     VARCHAR(64)  NOT NULL COMMENT '玩家唯一标识',
    token_hash    VARCHAR(128) NOT NULL DEFAULT '' COMMENT '登录 token 的 SHA-256（明文登录开发期简化）',
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_player_id (player_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='玩家账户表';

CREATE TABLE IF NOT EXISTS saves (
    player_id  VARCHAR(64)  NOT NULL COMMENT '玩家唯一标识',
    save_id    VARCHAR(64)  NOT NULL COMMENT '存档槽位 id',
    data       LONGTEXT     NOT NULL COMMENT 'World.Serialize() 的 JSON 快照',
    updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (player_id, save_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='玩家存档表';

CREATE TABLE IF NOT EXISTS auth_tokens (
    token_hash VARCHAR(64)  NOT NULL COMMENT 'token SHA-256',
    player_id  VARCHAR(64)  NOT NULL COMMENT '关联玩家',
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (token_hash),
    KEY idx_player_id (player_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='登录 token 表（便于失效/多端）';