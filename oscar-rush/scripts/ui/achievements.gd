class_name Achievements
extends RefCounted
## 成就（10-18 作者："在图鉴页面第一页加一个成就系统，加一些成就，然后其中有一个成就就是解锁全部图鉴"）。
## 立绘添加会话做的；图鉴书第一册（codex_achievements.gd）显示，解锁时屏幕右上角弹一张小卡（不挡操作）、响一声。
##
## 存档：user://achievements.cfg（[done] id=解锁顺序；[progress] 武器通关、买过的变异）。
##   - 测试设环境变量 SCRAP_ACHIEVE_PATH=别的文件；没设又不是从开始菜单正常开的游戏（Run.real_launch()）就只记在内存里，
##     不写作者的文件（和图鉴 bestiary.gd 一样）。无界面跑、没设路径时也只在内存里。
## 埋点：大部分条件从图鉴（Bestiary 的 count_kill / mark / watch）就能知道，不用动别人的文件：
##   打死最终 Boss（boss_set）= 通关；Boss 第一次进画面 = 开打；马灯回血听 Run.crystal_healed。
##   剩下的在别人的文件里各加了一行：Run.reset_run → on_run_start、商店修马灯 → on_heal、商店买变异 → on_mutation、
##   换上精英掉的武器（weapon_pickup.gd）→ on_weapon_swap。
## 游戏里没有真的彩蛋（"Press DEL to remember" 那行字按了没反应），隐藏成就先用"通关时马灯还有 95% 以上"（结局会多一行 LANTERN 100%）。
## 开发者模式 F8：F5 成就全开、F6 按两下清空。
## 徽章：每个成就一个 16×16 的像素小徽章（draw_badge 用代码画：铜圈、深色底、中间 8×8 图案），没解锁是灰色剪影。

## [id, 名字, 怎么拿（说明）, 图案, 档次 0 铜 1 银 2 金, 隐藏（没拿到时名字和说明都是 ???）]
const LIST := [
	["warm_up", "WARM-UP", "Destroy your first elite.", "valve", 0, false],
	["first_shift", "FIRST SHIFT", "Bring down the Stoker in the boiler room.", "furnace", 0, false],
	["the_end", "THE END", "Finish the game.", "reel", 1, false],
	["low_voltage", "LOW VOLTAGE", "Finish the game on Easy.", "gauge_low", 0, false],
	["rated_power", "RATED POWER", "Finish the game on Normal.", "gauge_mid", 1, false],
	["overclocked", "OVERCLOCKED", "Finish the game on Hard.", "gauge_high", 2, false],
	["no_static", "NO STATIC", "On Hard, beat a boss without the lantern taking a hit.", "screen", 2, false],
	["full_spectrum", "FULL SPECTRUM", "Finish the game with each of the 7 weapons.", "bars", 2, false],
	["tape_library", "TAPE LIBRARY", "Buy 4 different mutations (across runs).", "cassette", 1, false],
	["hot_swap", "HOT SWAP", "Pick up a weapon an elite dropped.", "swap", 0, false],
	["party_line", "PARTY LINE", "Finish the game with two players.", "phones", 1, false],
	["power_saver", "POWER SAVER", "Finish a run without the lantern ever healing.", "bulb", 2, false],
	["scrapyard", "SCRAPYARD", "Scrap 500 enemies in total.", "gear", 1, false],
	["complete_catalogue", "COMPLETE CATALOGUE", "Light up every page of the bestiary.", "book", 2, false],
	["hidden_channel", "HIDDEN CHANNEL", "Finish the game with the lantern at 95% or more.", "eye", 2, true],
]
const SCRAPYARD_KILLS := 500
## 难度：Run.difficulty 0 简单、1 普通、2 困难
const HARD := 2
## 通关时马灯剩多少算"满灯"（和 boss3_room.gd 的 LANTERN 100% 一样）
const PERFECT := 0.95
const TAPE_COUNT := 4
const SAVE_PATH := "user://achievements.cfg"

## 档次的颜色：[亮, 中, 暗]
const TIER_COLORS := [
	[Color8(232, 168, 110), Color8(176, 112, 64), Color8(110, 64, 40)],
	[Color8(222, 226, 232), Color8(150, 156, 170), Color8(86, 90, 104)],
	[Color8(255, 220, 110), Color8(214, 160, 50), Color8(130, 88, 30)],
]
const BADGE_BG := Color8(34, 28, 32)
const LOCKED := [Color8(74, 72, 78), Color8(52, 50, 56), Color8(36, 34, 40)]

## 中间的 8×8 图案：# 用亮色，+ 用中色
const GLYPHS := {
	"valve": ["..####..", ".#++++#.", "#+#..#+#", "#+.##.+#", "#+.##.+#", "#+#..#+#", ".#++++#.", "...##..."],
	"furnace": ["...##...", "..#++#..", ".#++++#.", "########", "#+#..#+#", "#+.##.+#", "#+#++#+#", "########"],
	"reel": ["..####..", ".#+..+#.", "#+.##.+#", "#..##..#", "#+.##.+#", ".#+..+#.", "..####..", "....####"],
	"gauge_low": ["..####..", ".#....#.", "#......#", "#......#", "#+..#..#", "#.++#..#", ".#....#.", "..####.."],
	"gauge_mid": ["..####..", ".#....#.", "#..+...#", "#..+...#", "#..+#..#", "#...#..#", ".#....#.", "..####.."],
	"gauge_high": ["..####..", ".#....#.", "#......#", "#......#", "#...#..#", "#...#++#", ".#....#.", "..####.."],
	"screen": ["########", "#++++++#", "#+....+#", "#+####+#", "#+....+#", "#++++++#", "########", ".##..##."],
	"bars": [], # 七色彩条，单独画
	"cassette": ["########", "#++++++#", "#+#++#+#", "#+.##.+#", "#+#++#+#", "#++++++#", "#..##..#", "########"],
	"swap": ["...#....", "..##....", ".######.", "..##...#", "#...##..", ".######.", "....##..", "....#..."],
	"phones": [".##..##.", "#++##++#", "#+....+#", "........", ".##..##.", "#++##++#", "#+....+#", "........"],
	"bulb": ["..####..", ".#++++#.", "#+....+#", "#+....+#", ".#+..+#.", "..#..#..", "..####..", "...##..."],
	"gear": [".#.##.#.", "########", ".#++++#.", "##+..+##", "##+..+##", ".#++++#.", "########", ".#.##.#."],
	"book": [".######.", "#+++#++#", "#+++#++#", "#+++#++#", "#+++#++#", "#+++#++#", ".######.", "...##..."],
	"eye": ["........", "..####..", ".#++++#.", "#++##++#", "#++##++#", ".#++++#.", "..####..", "........"],
}
const BAR_COLORS := [Color8(220, 220, 220), Color8(230, 220, 70), Color8(80, 210, 220), Color8(80, 200, 80),
	Color8(210, 70, 200), Color8(220, 60, 60), Color8(60, 70, 220)]

static var _loaded := false
static var _path := ""
static var _done := {}          # id: 解锁顺序
static var _weapons := {}       # 用过并通关的武器
static var _mutations := {}     # 买过的变异
## 这一局：马灯回过血没有、Boss 开打时马灯有多少血（看 Boss 第一次进画面时记）
static var _healed := false
static var _boss_hp := {}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var env := OS.get_environment("SCRAP_ACHIEVE_PATH")
	_path = env if env != "" else SAVE_PATH
	if env == "" and DisplayServer.get_name() == "headless":
		_path = ""
		return
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	for k in cfg.get_section_keys("done") if cfg.has_section("done") else []:
		_done[k] = int(cfg.get_value("done", k, 0))
	for k in cfg.get_section_keys("weapons") if cfg.has_section("weapons") else []:
		_weapons[k] = true
	for k in cfg.get_section_keys("mutations") if cfg.has_section("mutations") else []:
		_mutations[k] = true


static func _save() -> void:
	if _path == "":
		return
	# 没设 SCRAP_ACHIEVE_PATH 又不是正常开的游戏（直接开关卡、窗口跑的测试）就不写作者的成就
	if OS.get_environment("SCRAP_ACHIEVE_PATH") == "" and not Run.real_launch():
		return
	var cfg := ConfigFile.new()
	for k in _done:
		cfg.set_value("done", k, _done[k])
	for k in _weapons:
		cfg.set_value("weapons", k, true)
	for k in _mutations:
		cfg.set_value("mutations", k, true)
	cfg.save(_path)


# ---------------------------------------------------------------- 查

static func is_done(id: String) -> bool:
	_load()
	return _done.has(id)


static func count_done() -> int:
	_load()
	return _done.size()


static func info(id: String) -> Array:
	for a in LIST:
		if a[0] == id:
			return a
	return []


## 有进度条的成就：[现在, 目标]；没有进度的返回 []
static func progress(id: String) -> Array:
	_load()
	match id:
		"full_spectrum":
			return [_weapons.size(), WeaponRegistry.ids().size()]
		"tape_library":
			return [mini(_mutations.size(), TAPE_COUNT), TAPE_COUNT]
		"scrapyard":
			return [mini(Bestiary.total_kills(), SCRAPYARD_KILLS), SCRAPYARD_KILLS]
		"complete_catalogue":
			return [Bestiary.seen_count(), Bestiary.total_count()]
	return []


# ---------------------------------------------------------------- 解锁

static func unlock(id: String) -> void:
	_load()
	if _done.has(id) or info(id).is_empty():
		return
	_done[id] = _done.size() + 1
	_save()
	# 弹卡用 load() 调（achievement_toast.gd 里写了 Achievements 类名，两边都写类名会循环引用）
	load("res://scripts/ui/achievement_toast.gd").call("pop", id)


static func unlock_all() -> void:
	_load()
	for a in LIST:
		if not _done.has(a[0]):
			_done[a[0]] = _done.size() + 1
	_save()


static func clear() -> void:
	_load()
	_done.clear()
	_weapons.clear()
	_mutations.clear()
	_save()


# ---------------------------------------------------------------- 事件（一行调用的埋点）

## 新开一局（Run.reset_run）
static func on_run_start() -> void:
	_healed = false
	_boss_hp.clear()
	# 马灯回血（Run.heal_crystal 发 crystal_healed：清场、灯油、发电机……）；商店修马灯不走这里，那边单独调 on_heal
	if not Run.crystal_healed.is_connected(_on_healed):
		Run.crystal_healed.connect(_on_healed)


static func _on_healed(_amount: float) -> void:
	_healed = true


## 商店修马灯
static func on_heal() -> void:
	_healed = true


## 通关（打死最终 Boss 那一下，on_kill 调）：难度、用的武器、双人、一局没回过血、满灯
static func on_clear() -> void:
	_load()
	unlock("the_end")
	match int(Run.difficulty):
		0:
			unlock("low_voltage")
		HARD:
			unlock("overclocked")
		_:
			unlock("rated_power")
	if Run.crystal_max > 0.0 and Run.crystal_hp / Run.crystal_max >= PERFECT:
		unlock("hidden_channel")
	for p in Run.players:
		var w: String = p.get("weapon", Upgrades.weapon)
		if w != "":
			_weapons[w] = true
	_save()
	if _weapons.size() >= WeaponRegistry.ids().size():
		unlock("full_spectrum")
	if Run.players.size() >= 2:
		unlock("party_line")
	if not _healed:
		unlock("power_saver")


## 换上了精英掉的武器（weapon_pickup.gd）
static func on_weapon_swap() -> void:
	unlock("hot_swap")


## 商店买了一个变异
static func on_mutation(id: String) -> void:
	_load()
	_mutations[id] = true
	_save()
	if _mutations.size() >= TAPE_COUNT:
		unlock("tape_library")


## 图鉴第一次在画面里看到某只（每一只每次进画面一次，Bestiary._Watch 调）：Boss 开打时记下马灯的血
static func on_seen(id: String) -> void:
	if id.begins_with("boss_"):
		_boss_hp[id] = Run.crystal_hp


## 图鉴记了一次击杀（Bestiary.count_kill 调）
static func on_kill(id: String) -> void:
	var e := Bestiary.entry(id)
	if e.get("kind", "") == "elite":
		unlock("warm_up")
	if id == "boss_stoker":
		unlock("first_shift")
	if e.get("kind", "") == "boss" and int(Run.difficulty) == HARD and _boss_hp.has(id) \
			and Run.crystal_hp >= float(_boss_hp[id]) - 0.01:
		unlock("no_static")
	if id == "boss_set":
		on_clear()
	if Bestiary.total_kills() >= SCRAPYARD_KILLS:
		unlock("scrapyard")


## 图鉴点亮了一只新的（Bestiary.mark 调）
static func on_catalogue() -> void:
	if Bestiary.total_count() > 0 and Bestiary.seen_count() >= Bestiary.total_count():
		unlock("complete_catalogue")


# ---------------------------------------------------------------- 徽章

## 在 at（左上角）画一个 16×16 的徽章，放大 s 倍。lit = false 画灰色剪影
static func draw_badge(c: CanvasItem, id: String, at: Vector2, s: int, lit: bool) -> void:
	var a := info(id)
	if a.is_empty():
		return
	var pal: Array = TIER_COLORS[int(a[4])] if lit else LOCKED
	var px := func(x: int, y: int, col: Color) -> void:
		c.draw_rect(Rect2(at + Vector2(x, y) * s, Vector2(s, s)), col)
	# 铜圈：16×16 的圆，外圈暗、上半亮（光从上面来）
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length()
			if d > 7.9:
				continue
			if d > 6.6:
				px.call(x, y, pal[0] if y < 7 else pal[1])
			elif d > 5.8:
				px.call(x, y, pal[2])
			else:
				px.call(x, y, BADGE_BG if lit else LOCKED[2])
	# 中间的图案
	var g: String = a[3]
	if g == "bars":
		for i in 7:
			for y in 6:
				px.call(4 + i, 5 + y, BAR_COLORS[i] if lit else (LOCKED[0] if i % 2 == 0 else LOCKED[1]))
		return
	var rows: Array = GLYPHS.get(g, [])
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == "#":
				px.call(4 + x, 4 + y, pal[0] if lit else LOCKED[0])
			elif ch == "+":
				px.call(4 + x, 4 + y, pal[1] if lit else LOCKED[1])
