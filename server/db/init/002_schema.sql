-- 静态游戏数据表（武将/城池/势力/武器/章节/地图/阵型/文案）
-- 由 make seed 生成；生产 MySQL docker init 时随 001_schema.sql 之后执行。

CREATE TABLE IF NOT EXISTS game_generals (
    general_id   INT          NOT NULL,
    general_name VARCHAR(64)  NOT NULL,
    debut_year   INT          NOT NULL,
    debut_city   INT          NOT NULL,
    phase        INT          NOT NULL,
    status       INT          NOT NULL,
    level        INT          NOT NULL,
    army         TEXT         NOT NULL COMMENT 'JSON: 平/山/水适性',
    health       INT          NOT NULL,
    lead         INT          NOT NULL,
    force        INT          NOT NULL,
    wisdom       INT          NOT NULL,
    govern       INT          NOT NULL,
    charm        INT          NOT NULL,
    loyalty      INT          NOT NULL,
    arm          INT          NOT NULL,
    armor        INT          NOT NULL,
    soldiers     INT          NOT NULL,
    follow_who   INT          NOT NULL,
    experience   INT          NOT NULL,
    skills       TEXT         NOT NULL COMMENT 'JSON: 特技位掩码',
    PRIMARY KEY (general_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='武将静态表';

CREATE TABLE IF NOT EXISTS game_cities (
    city_id           INT          NOT NULL,
    city_name         VARCHAR(64)  NOT NULL,
    owner_id          INT          NOT NULL,
    prefect_id        INT          NOT NULL,
    rule              INT          NOT NULL,
    money             INT          NOT NULL,
    grain             INT          NOT NULL,
    treasures         INT          NOT NULL,
    agriculture       INT          NOT NULL,
    commerce          INT          NOT NULL,
    population        INT          NOT NULL,
    prevention        INT          NOT NULL,
    reserve_soldiers  INT          NOT NULL,
    city_school       TINYINT(1)   NOT NULL,
    city_grain_shop   TINYINT(1)   NOT NULL,
    city_hospital     TINYINT(1)   NOT NULL,
    city_weapon_shop  INT          NOT NULL,
    war_weapon_shop   INT          NOT NULL,
    connect_city_id   TEXT         NOT NULL COMMENT 'JSON: 相邻城池',
    map_position      TEXT         NOT NULL COMMENT 'JSON: 大地图坐标',
    PRIMARY KEY (city_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='城池静态表';

CREATE TABLE IF NOT EXISTS game_countries (
    country_id       INT         NOT NULL,
    country_king_id  INT         NOT NULL,
    country_color    VARCHAR(32) NOT NULL,
    can_be_choose    TINYINT(1)  NOT NULL,
    inheritors       TEXT        NOT NULL COMMENT 'JSON: 继承人武将id',
    PRIMARY KEY (country_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='势力静态表';

CREATE TABLE IF NOT EXISTS game_weapons (
    weapon_id    INT         NOT NULL,
    weapon_name  VARCHAR(64) NOT NULL,
    price        INT         NOT NULL,
    property     INT         NOT NULL,
    weight       INT         NOT NULL,
    kind         INT         NOT NULL,
    is_unique    TINYINT(1)  NOT NULL,
    smithy       INT         NOT NULL,
    PRIMARY KEY (weapon_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='武器静态表';

CREATE TABLE IF NOT EXISTS game_chapters (
    year         INT          NOT NULL,
    title        VARCHAR(64)  NOT NULL,
    introduction TEXT         NOT NULL,
    PRIMARY KEY (year)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='剧本章节静态表';

CREATE TABLE IF NOT EXISTS game_maps (
    city_id INT  NOT NULL,
    grid    TEXT NOT NULL COMMENT 'JSON: 19x32 战争地图',
    PRIMARY KEY (city_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='战争地图静态表';

CREATE TABLE IF NOT EXISTS game_formations (
    name VARCHAR(16) NOT NULL,
    grid TEXT        NOT NULL COMMENT 'JSON: 7x16 阵型',
    PRIMARY KEY (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='阵型静态表';

CREATE TABLE IF NOT EXISTS game_texts (
    k VARCHAR(64) NOT NULL,
    v TEXT        NOT NULL COMMENT 'JSON: 文案/数值表值',
    PRIMARY KEY (k)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='文案与数值表静态数据';
