// seed 工具：从旧数据源生成权威种子 JSON（server/internal/static/seed_data/）
// 与数据库 seed SQL（server/db/init/seed_*.sql，每表一个文件）。
//
// 用法（在 server/ 目录运行）：go run ./cmd/seed
// 输入：data/*.json、data/*.CSV（地图）、data/*.csv（阵型）、internal/static/seed_data/texts.json（由 extract_texts.py 生成）
// 输出：internal/static/seed_data/{generals,cities,countries,weapons,chapters,maps,formations}.json
//       db/init/002_schema.sql、db/init/seed_*.sql（8 个，每表一个）
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strconv"
	"strings"

	"3k-server/internal/static"
)

// dataDir 旧数据源目录（server/data）
// seedDir 权威种子 JSON 输出目录（server/internal/static/seed_data）
// sqlDir  SQL 输出目录（server/db/init）

func main() {
	dataDir := "data"
	seedDir := filepath.Join("internal", "static", "seed_data")
	sqlDir := filepath.Join("db", "init")

	if err := os.MkdirAll(seedDir, 0o755); err != nil {
		fatal("创建 seed 目录失败: %v", err)
	}
	if err := os.MkdirAll(sqlDir, 0o755); err != nil {
		fatal("创建 SQL 目录失败: %v", err)
	}

	// 1. 拷贝/规范化 5 个实体 JSON
	copyJSON(dataDir, seedDir, "GeneralData.json", "generals.json", &[]static.GeneralRow{})
	copyJSON(dataDir, seedDir, "CityData.json", "cities.json", &[]static.CityRow{})
	copyJSON(dataDir, seedDir, "CountryData.json", "countries.json", &[]static.CountryRow{})
	copyJSON(dataDir, seedDir, "WeaponData.json", "weapons.json", &[]static.WeaponRow{})
	copyJSON(dataDir, seedDir, "ChapterData.json", "chapters.json", &[]static.ChapterRow{})

	// 2. 地图/阵型 CSV → JSON
	maps := readMaps(dataDir)
	formations := readFormations(dataDir)
	writeJSON(seedDir, "maps.json", maps)
	writeJSON(seedDir, "formations.json", formations)

	// 3. texts.json 应已由 extract_texts.py 生成
	if _, err := os.Stat(filepath.Join(seedDir, "texts.json")); err != nil {
		fatal("texts.json 不存在，请先运行: python3 server/tools/extract_texts.py scripts/data/text_library.gd server/internal/static/seed_data/texts.json")
	}

	// 4. 生成 seed SQL（每表一个文件，从 seed JSON 读取）
	writeSeedSQL(seedDir, sqlDir, "seed_game_generals.sql", "game_generals", "generals.json", &[]static.GeneralRow{})
	writeSeedSQL(seedDir, sqlDir, "seed_game_cities.sql", "game_cities", "cities.json", &[]static.CityRow{})
	writeSeedSQL(seedDir, sqlDir, "seed_game_countries.sql", "game_countries", "countries.json", &[]static.CountryRow{})
	writeSeedSQL(seedDir, sqlDir, "seed_game_weapons.sql", "game_weapons", "weapons.json", &[]static.WeaponRow{})
	writeSeedSQL(seedDir, sqlDir, "seed_game_chapters.sql", "game_chapters", "chapters.json", &[]static.ChapterRow{})
	writeSeedSQL(seedDir, sqlDir, "seed_game_maps.sql", "game_maps", "maps.json", &maps)
	writeSeedSQL(seedDir, sqlDir, "seed_game_formations.sql", "game_formations", "formations.json", &formations)
	writeTextsSQL(seedDir, sqlDir)

	// 5. 建表 schema
	writeSchema(sqlDir)

	fmt.Println("seed 生成完成")
	fmt.Println("  seed JSON:", seedDir)
	fmt.Println("  seed SQL :", sqlDir)
}

// copyJSON 读旧 JSON → 反序列化到模型 → 规范化写回（字段与模型对齐）。
// out 是 *[]static.XxxRow 的指针，用于反序列化目标类型。
func copyJSON(dataDir, seedDir, src, dst string, out interface{}) {
	raw, err := os.ReadFile(filepath.Join(dataDir, src))
	if err != nil {
		fatal("读取 %s 失败: %v", src, err)
	}
	if err := json.Unmarshal(raw, out); err != nil {
		fatal("解析 %s 失败: %v", src, err)
	}
	writeJSON(seedDir, dst, out)
	fmt.Printf("  生成 %s (%d 条)\n", dst, reflect.ValueOf(out).Elem().Len())
}

// writeJSON 写 JSON 文件（2 空格缩进，中文不转义）
func writeJSON(dir, name string, v interface{}) {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		fatal("序列化 %s 失败: %v", name, err)
	}
	if err := os.WriteFile(filepath.Join(dir, name), data, 0o644); err != nil {
		fatal("写入 %s 失败: %v", name, err)
	}
}

// readMaps 读 data/*.CSV（48 张战争地图，19×32）
func readMaps(dataDir string) []static.MapRow {
	var rows []static.MapRow
	files, _ := filepath.Glob(filepath.Join(dataDir, "*.CSV"))
	sort.Strings(files)
	for _, f := range files {
		name := filepath.Base(f)
		id, err := strconv.Atoi(strings.TrimSuffix(name, ".CSV"))
		if err != nil {
			continue
		}
		rows = append(rows, static.MapRow{CityId: id, Grid: readCSV(f)})
	}
	return rows
}

// readFormations 读 data/*.csv（16 个阵型，7×16）
func readFormations(dataDir string) []static.FormationRow {
	var rows []static.FormationRow
	files, _ := filepath.Glob(filepath.Join(dataDir, "*.csv"))
	sort.Strings(files)
	for _, f := range files {
		name := strings.TrimSuffix(filepath.Base(f), ".csv")
		rows = append(rows, static.FormationRow{Name: name, Grid: readCSV(f)})
	}
	return rows
}

// readCSV 读 CSV 为 int 二维数组
func readCSV(path string) [][]int {
	data, err := os.ReadFile(path)
	if err != nil {
		fatal("读取 %s 失败: %v", path, err)
	}
	var grid [][]int
	for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		var row []int
		for _, cell := range strings.Split(line, ",") {
			v, err := strconv.Atoi(strings.TrimSpace(cell))
			if err != nil {
				fatal("解析 %s 的 CSV 失败: %v", path, err)
			}
			row = append(row, v)
		}
		grid = append(grid, row)
	}
	return grid
}

// writeSeedSQL 从 seed JSON 读取数据，生成单表 seed SQL（列名从 gorm tag 反射读取）
func writeSeedSQL(seedDir, sqlDir, file, table, seedFile string, out interface{}) {
	raw, err := os.ReadFile(filepath.Join(seedDir, seedFile))
	if err != nil {
		fatal("读取 %s 失败: %v", seedFile, err)
	}
	if err := json.Unmarshal(raw, out); err != nil {
		fatal("解析 %s 失败: %v", seedFile, err)
	}
	rows := reflect.ValueOf(out).Elem()
	sql := buildInsert(table, rows)
	if err := os.WriteFile(filepath.Join(sqlDir, file), []byte(sql), 0o644); err != nil {
		fatal("写入 %s 失败: %v", file, err)
	}
	fmt.Printf("  生成 %s (%d 条)\n", file, rows.Len())
}

// buildInsert 用反射把结构体 slice 转成 INSERT 语句（列名读 gorm column tag）
func buildInsert(table string, rows reflect.Value) string {
	elemType := rows.Type().Elem()
	var cols []string
	var fields []reflect.StructField
	for i := 0; i < elemType.NumField(); i++ {
		f := elemType.Field(i)
		col := gormColumn(f.Tag.Get("gorm"))
		if col == "" {
			continue
		}
		cols = append(cols, col)
		fields = append(fields, f)
	}

	var b strings.Builder
	b.WriteString("-- " + table + " 静态种子数据\n")
	b.WriteString("INSERT INTO " + table + " (" + strings.Join(cols, ", ") + ") VALUES\n")
	for r := 0; r < rows.Len(); r++ {
		if r > 0 {
			b.WriteString(",\n")
		}
		row := rows.Index(r)
		b.WriteString("  (")
		for i, f := range fields {
			if i > 0 {
				b.WriteString(", ")
			}
			b.WriteString(sqlLiteral(row.Field(i), f.Type))
		}
		b.WriteString(")")
	}
	b.WriteString(";\n")
	return b.String()
}

// gormColumn 从 gorm tag 提取 column 名
func gormColumn(tag string) string {
	for _, part := range strings.Split(tag, ";") {
		if strings.HasPrefix(part, "column:") {
			return strings.TrimPrefix(part, "column:")
		}
	}
	return ""
}

// sqlLiteral 把字段值转成 SQL 字面量
func sqlLiteral(v reflect.Value, t reflect.Type) string {
	// 数组/slice → JSON 字符串
	switch t.Kind() {
	case reflect.Slice, reflect.Array:
		data, _ := json.Marshal(v.Interface())
		return quote(string(data))
	case reflect.String:
		return quote(v.String())
	case reflect.Bool:
		if v.Bool() {
			return "1"
		}
		return "0"
	default:
		return fmt.Sprintf("%v", v.Interface())
	}
}

// quote SQL 单引号转义
func quote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}

// writeTextsSQL 生成 game_texts 表 seed SQL（每行 k/v 一列）
func writeTextsSQL(seedDir, sqlDir string) {
	raw, err := os.ReadFile(filepath.Join(seedDir, "texts.json"))
	if err != nil {
		fatal("读取 texts.json 失败: %v", err)
	}
	var m map[string]interface{}
	if err := json.Unmarshal(raw, &m); err != nil {
		fatal("解析 texts.json 失败: %v", err)
	}
	// 键排序保证输出稳定
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var b strings.Builder
	b.WriteString("-- game_texts 静态种子数据\n")
	b.WriteString("INSERT INTO game_texts (k, v) VALUES\n")
	for i, k := range keys {
		v, _ := json.Marshal(m[k])
		if i > 0 {
			b.WriteString(",\n")
		}
		b.WriteString("  (" + quote(k) + ", " + quote(string(v)) + ")")
	}
	b.WriteString(";\n")

	file := "seed_game_texts.sql"
	if err := os.WriteFile(filepath.Join(sqlDir, file), []byte(b.String()), 0o644); err != nil {
		fatal("写入 %s 失败: %v", file, err)
	}
	fmt.Printf("  生成 %s (%d 条)\n", file, len(keys))
}

// writeSchema 生成 002_schema.sql（建 8 个静态数据表，MySQL 语法）
func writeSchema(sqlDir string) {
	schema := `-- 静态游戏数据表（武将/城池/势力/武器/章节/地图/阵型/文案）
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
`
	if err := os.WriteFile(filepath.Join(sqlDir, "002_schema.sql"), []byte(schema), 0o644); err != nil {
		fatal("写入 002_schema.sql 失败: %v", err)
	}
	fmt.Println("  生成 002_schema.sql")
}

func fatal(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "seed: "+format+"\n", args...)
	os.Exit(1)
}
