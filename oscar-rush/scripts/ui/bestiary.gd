class_name Bestiary
extends RefCounted
## 怪物图鉴的数据和收集记录（作者 10-18："我们做了这么多怪物不都得放进去？"）。界面在 bestiary_menu.gd。
## - 遇到过才点亮：怪第一次出现在画面里就记一笔（Bestiary.watch，EnemyBase / crawler / 三个 Boss 的 _ready 里各一行）。
## - 记录存在 user://bestiary.cfg（网页版在浏览器的 IndexedDB 里）。测试脚本设环境变量 SCRAP_BESTIARY_PATH=别的文件，
##   就不会改到作者真正的记录。没设这个变量的无头测试（--headless）只记在内存里，不写文件。
## - 开发者开关：reveal_all = true 时全部点亮（图鉴里按 F9 切换；或者环境变量 SCRAP_BESTIARY_ALL=1），不写进存档。
## - 编号：贴图路径去掉 res://art/enemies/ 和扩展名，第三关的加 l3_ 前缀（第二关和第三关都有留声机、放映机）；Boss 是 boss_xxx。
## 名字、说明都是英文原文，界面里过 tr()，中文在 localization/text.csv。

const PATH := "user://bestiary.cfg"
const CHAPTERS := ["1", "2", "3", "boss"]

static var reveal_all := false
static var _seen := {}
static var _loaded := false
static var _path := PATH
static var _entries: Array = []
static var _catalog: Array = []
## 每种怪打死了几次（编号 → 次数）
static var _kills := {}
static var _dirty := false
static var _last_save := -100000


## 一只怪在画面里第一次出现时记一笔：给它挂一个小节点，每帧看它在不在画面里，看到了就记下、自己删掉。
## rect 是怪的大致范围（相对怪的原点）。不用 VisibleOnScreenNotifier2D：那个靠渲染，无头测试里不触发
static func watch(node: Node2D, id: String, rect := Rect2(-24, -40, 48, 48)) -> void:
	if id == "" or is_seen(id):
		return
	var w := _Watch.new()
	w.id = id
	w.rect = rect
	node.add_child(w)


class _Watch extends Node:
	var id := ""
	var rect := Rect2()

	func _process(_delta: float) -> void:
		var p := get_parent() as CanvasItem
		if p == null or not p.is_visible_in_tree():
			return
		if (p.get_global_transform_with_canvas() * rect).intersects(p.get_viewport_rect()):
			Bestiary.mark(id)
			queue_free()


## 贴图路径 → 图鉴编号
static func id_for_texture(path: String) -> String:
	# 第三关精英的大号、小号贴图在 l3/size/ 里（l3_elite_art.gd），编号和原图一样
	return path.trim_prefix("res://art/enemies/").get_basename().replace("/size/", "/").replace("/", "_")


static func mark(id: String) -> void:
	_load()
	if _seen.has(id):
		return
	_seen[id] = _next_order()
	_save()


## 打死一只记一次（EnemyBase / crawler / 三个 Boss 死的时候各一行）。顺便也算"遇见过"。
## 连着打死很多只时不每只都写文件：最多 2 秒写一次（网页版每写一次都要同步一次浏览器存储）
static func count_kill(id: String) -> void:
	if id == "":
		return
	_load()
	_kills[id] = int(_kills.get(id, 0)) + 1
	if not _seen.has(id):
		_seen[id] = _next_order()
		_dirty = true
	_dirty = true
	var now := Time.get_ticks_msec()
	if now - _last_save >= 2000:
		_save()


static func kills(id: String) -> int:
	_load()
	return int(_kills.get(id, 0))


## 开着图鉴、换场景前调一下：把还没写进文件的击杀数写进去
static func flush() -> void:
	if _dirty:
		_save()


static func _next_order() -> int:
	var m := 0
	for k in _seen:
		m = maxi(m, int(_seen[k]))
	return m + 1


## 开发者模式（F8 面板的 B）：全部点亮，写进存档（和 F9 的临时全开不同，这个是永久的）
static func unlock_all() -> void:
	_load()
	for e in catalog():
		if not _seen.has(e["id"]):
			_seen[e["id"]] = _next_order()
	_save()


## 开发者模式（F8 面板连按两下 N）：清空图鉴（遇见过的和击杀数都清），从头再收集
static func clear() -> void:
	_load()
	_seen.clear()
	_kills.clear()
	_save()


## 存档：[seen] 编号 = 第几个遇见的（1、2、3……；旧存档里的 true 当成 0，排在最前面）；[kills] 编号 = 打死几次
static func _save() -> void:
	_dirty = false
	_last_save = Time.get_ticks_msec()
	if _path == "":
		return
	var cfg := ConfigFile.new()
	for k in _seen:
		cfg.set_value("seen", k, int(_seen[k]))
	if _seen.is_empty():
		cfg.set_value("seen", "_", -1)   # 空的也留一个文件，免得读的时候当成没存过
	for k in _kills:
		cfg.set_value("kills", k, int(_kills[k]))
	cfg.save(_path)


static func is_seen(id: String) -> bool:
	_load()
	return _seen.has(id)


## 图鉴里这一只要不要点亮
static func lit(e: Dictionary) -> bool:
	return reveal_all or is_seen(e["id"])


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if OS.get_environment("SCRAP_BESTIARY_ALL") == "1":
		reveal_all = true
	if OS.get_environment("SCRAP_BESTIARY_PATH") != "":
		_path = OS.get_environment("SCRAP_BESTIARY_PATH")
	elif DisplayServer.get_name() == "headless":
		_path = ""   # 无头跑的自动测试：只记在内存里，不读也不改作者真正的图鉴
		return
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	if cfg.has_section("seen"):
		for k in cfg.get_section_keys("seen"):
			var v = cfg.get_value("seen", k, -1)
			if v is bool:
				if v:
					_seen[k] = 0
			elif int(v) >= 0:
				_seen[k] = int(v)
	if cfg.has_section("kills"):
		for k in cfg.get_section_keys("kills"):
			_kills[k] = int(cfg.get_value("kills", k, 0))


# ---------------------------------------------------------------- 一个大列表（作者 10-18："第一关第二关加起来都没第三关多，
# 按关卡分页不对"）：按图鉴编号排好，界面里再换排序

## 排序方式：编号、生命值、击杀数、类型、首次遇见
const SORTS := ["no", "hp", "kills", "type", "first"]


## 按图鉴编号排的全部条目：第一关小怪 → 第一关精英 → Boss1 → 第二关小怪 → 第二关精英 → Boss2 → 第三关小怪 → 第三关精英 → Boss3。
## 每条多一个 no（#001 起；还没登场的电报员排在第二关精英最后，编号是 0，显示 #---）
static func catalog() -> Array:
	if not _catalog.is_empty():
		return _catalog
	var groups := []
	for ch in ["1", "2", "3"]:
		for kind in ["mob", "elite"]:
			groups.append(entries().filter(func(e): return e["chapter"] == ch and e["kind"] == kind))
		groups.append(entries().filter(func(e): return e["kind"] == "boss" and e["place"] == "boss" + ch))
	var n := 0
	for g in groups:
		for e in g:
			if e.get("unreleased", false):
				e["no"] = 0
			else:
				n += 1
				e["no"] = n
			e["level"] = int(e["chapter"]) if e["chapter"] != "boss" else int(String(e["place"]).trim_prefix("boss"))
			_catalog.append(e)
	return _catalog


## 界面用的列表：sort 是 SORTS 里的一个，reverse 反过来，only_big 只看精英和 Boss。
## 没登场的（电报员）只在开发者全开时出现。没点亮的照样在列表里（剪影），按真实数值排
static func listed(sort: String, reverse := false, only_big := false) -> Array:
	var keep := func(e: Dictionary) -> bool:
		return (not e.get("unreleased", false) or reveal_all) and (not only_big or e["kind"] != "mob")
	var list := catalog().filter(keep)
	var key := func(e: Dictionary) -> Array:
		match sort:
			"hp":
				return [-int(stats(e)["hp"])]
			"kills":
				return [-kills(e["id"])]
			"type":
				return [{"boss": 0, "elite": 1, "mob": 2}[e["kind"]]]
			"first":
				# 遇见过的按先后，没遇见的排在后面
				return [int(_seen[e["id"]]) if _seen.has(e["id"]) else 1 << 30]
		return []
	_load()
	# 先按 key 排，一样的按编号；"反过来"就把整个列表倒过来（生命值高到低 → 低到高）
	var keyed: Array = list.map(func(e): return [key.call(e), _order_no(e), e])
	keyed.sort_custom(func(x, y):
		var kx: Array = x[0]
		var ky: Array = y[0]
		for i in kx.size():
			if kx[i] != ky[i]:
				return kx[i] < ky[i]
		return x[1] < y[1])
	var out: Array = keyed.map(func(x): return x[2])
	if reverse:
		out.reverse()
	return out


## 排序时编号最后比：没编号的（电报员）当成第二关精英的最后一个
static func _order_no(e: Dictionary) -> int:
	return int(e["no"]) * 10 if int(e["no"]) > 0 else 10 * _first_no_after(e) - 5


static func _first_no_after(e: Dictionary) -> int:
	var cat := catalog()
	for i in range(cat.find(e) + 1, cat.size()):
		if int(cat[i]["no"]) > 0:
			return int(cat[i]["no"])
	return 9999


static func count_seen(list: Array) -> int:
	return list.filter(func(e): return is_seen(e["id"])).size()


## 全部条目。每条：id、chapter、kind（mob / elite / boss）、name、title（精英的标语）、desc（一两句说明）、
## where（第三关的场景名）、tex（贴图）、hframes、frames（待机动画用哪几帧）、layers（Boss 叠画的几张图）、unreleased
static func entries() -> Array:
	if not _entries.is_empty():
		return _entries
	var E := _entries
	# ---- 第一关：锅炉房
	E.append(_mob("1", "crawler", "Gear Crawler", 4, [0, 1, 2, 3],
		"A gear bug that crawls back and forth. One full shot breaks it."))
	E.append(_mob("1", "moth", "Lamp Moth", 3, [0, 1],
		"Always flies at the brightest thing: your lantern, your charge. Hit it as it pulls up."))
	E.append(_mob("1", "kettle", "Kettle", 3, [0, 1, 2],
		"Bolted down. Its steam won't hurt, but it pushes you off course."))
	E.append(_mob("1", "shaver", "Shaver", 4, [0, 1],
		"Small and fast. After a slash it rests; that's your opening."))
	E.append(_mob("1", "flea", "Spring Flea", 4, [0, 1],
		"Bounces at you. A red mark shows where it will land."))
	E.append(_elite("1", "cuckoo", "CUCKOO CLOCK", "TIME'S UP", 7, [0, 1],
		"Counts down, then fires a tin bird. Hit it while the door is open for double damage."))
	E.append(_elite("1", "sewing", "SEWING MACHINE", "STITCHED UP", 6, [0, 1],
		"Stitches the floor toward you and throws spools. Stitched ground slows you."))
	E.append(_elite("1", "register", "CASH REGISTER", "NO REFUNDS", 6, [0, 1],
		"Snaps its drawer and tosses coins. Drops an extra part."))
	E.append(_elite("1", "piano", "PLAYER PIANO", "ENCORE", 7, [0, 1],
		"Plays the floor keys like a wave. Jump the wave, step off the chords."))
	E.append(_elite("1", "vacuum", "VACUUM", "CLEAN SWEEP", 7, [0, 1],
		"Sucks in you, your shots and your lantern. Hit it 3 times to get the lantern back."))
	E.append(_elite("1", "roller", "STEAM ROLLER", "FULL STEAM", 5, [0, 1],
		"Charges until it hits a wall, then stays stunned. Punish it while it's dizzy."))
	# ---- 第二关：交换台、胶片天桥、放映厅
	E.append(_mob("2", "wire_snake", "Wire Snake", 6, [0, 1],
		"Hangs from the ceiling and lunges down. Hit it while it reels back up."))
	E.append(_mob("2", "fuse_beetle", "Fuse Beetle", 4, [0, 1],
		"Explodes when it dies, shocking the floor and other enemies. Lure the crowd together."))
	E.append(_mob("2", "phone", "Crank Phone", 5, [1, 2],
		"Plays dead, then rings for help. Take it out first."))
	E.append(_mob("2", "scavenger", "Scavenger", 6, [0, 1],
		"Steals your lantern from the floor. Hit it twice to make it drop the lantern."))
	E.append(_mob("2", "slide_projector", "Slide Projector", 4, [0, 1],
		"Aims a red line, then fires. Hit it while it aims to cancel the shot."))
	E.append(_mob("2", "film_reel", "Film Reel", 8, [0, 1, 2],
		"Rolls along the floor and breaks on its second wall. Jump it or shoot it."))
	E.append(_mob("2", "audience", "Audience", 9, [0, 1],
		"Sits still until one stands. Then the whole row pounces."))
	E.append(_mob("2", "usher", "Usher", 8, [0, 1, 2, 3],
		"Sweeps a flashlight cone, then flashes. Step out of the cone."))
	E.append(_mob("2", "hooded_operator", "Line Operator", 8, [0, 1, 2, 3],
		"Whips its phone cord at waist height. Jump it or back off."))
	E.append(_elite("2", "switchboard", "OPERATOR SWITCHBOARD", "PLEASE HOLD", 6, [0, 1],
		"Electrifies the floor under you and calls fuse beetles. Shoot the plug to cut the power."))
	E.append(_elite("2", "gramophone", "GRAMOPHONE", "NOW PLAYING", 6, [0, 1],
		"Its needle scratches along the floor. Jump over it."))
	E.append(_elite("2", "projector", "CINEMA PROJECTOR", "NOW SHOWING", 20, [0, 1],
		"A hot spotlight sweeps the floor, then reels walk out of its picture."))
	E.append(_elite("2", "chief_operator", "CHIEF OPERATOR", "HOLD THE LINE", 8, [0, 1, 2, 3],
		"Hooks you with a cord and reels you in. Dodge off the dotted line."))
	E.append(_elite("2", "film_editor", "FILM EDITOR", "FINAL CUT", 8, [0, 1],
		"Charges with giant scissors and cuts to the spot behind you. Jump over the charge."))
	E.append(_elite("2", "watchman", "WATCHMAN", "CURFEW", 10, [0, 1, 2, 3],
		"A living giant that pounds the ground. The floor cracks where its fists land."))
	var tel := _elite("2", "telegrapher", "TELEGRAPHER", "URGENT. STOP.", 10, [0, 1],
		"Sends morse at you: dots are fast, dashes are slow. Read the code over its head.")
	tel["unreleased"] = true
	E.append(tel)
	# ---- 第三关：电视里的世界（level3_mobs.gd 的 MOBS，按场景排，每个场景四只小怪一只精英）
	# 用 load 读，不写 L3Mob 类名：EnemyBase 会调 Bestiary，写了类名就等于每只怪都依赖第三关的全部脚本，
	# 第三关哪个文件正改到一半（解析错误），全游戏的怪都跟着编译不过（10-18 夜里真出过一次）
	var mobs: Dictionary = load("res://scripts/levels/level3_mobs.gd").get_script_constant_map()["MOBS"]
	# 第三关精英有新画的大号、小号贴图的，图鉴里也用新图（和游戏里一样）
	var art: Dictionary = {}
	if ResourceLoader.exists("res://scripts/enemies/l3/l3_elite_art.gd"):
		art = load("res://scripts/enemies/l3/l3_elite_art.gd").get_script_constant_map().get("ART", {})
	for key in mobs:
		var cfg: Dictionary = mobs[key]
		var kind: String = cfg["kind"]
		var hf: int = cfg["hframes"]
		var e := {
			"id": "l3_" + key, "chapter": "3", "kind": "elite" if kind == "elite" else "mob",
			"name": cfg.get("elite_name", L3_NAMES.get(key, key.capitalize())), "title": cfg.get("title", ""),
			"desc": KIND_DESC.get(kind, ""), "where": SCENES.get(cfg["scene"], cfg["scene"].capitalize()),
			"tex": cfg["texture"], "hframes": hf, "frames": [0, 1] if hf > 1 and kind != "hop" else [0],
			"place": "l3_" + cfg["scene"], "key": key, "moves": cfg.get("moves", []).size(),
		}
		if art.has(key) and ResourceLoader.exists(art[key]["texture"]):
			e["tex"] = art[key]["texture"]
			e["hframes"] = art[key]["hframes"]
		E.append(e)
	# ---- Boss
	E.append({"id": "boss_stoker", "chapter": "boss", "kind": "boss", "name": "THE STOKER", "title": "LEVEL 1 BOSS",
		"desc": "An old boiler that burns memories. It wants the tape in your lantern.",
		"layers": ["res://art/boss/stoker_body.png"], "hframes": 1, "frames": [0], "place": "boss1",
		"script": "res://scripts/boss/stoker.gd", "moves": 7})
	E.append({"id": "boss_operator", "chapter": "boss", "kind": "boss", "name": "THE OPERATOR", "title": "LEVEL 2 BOSS",
		"desc": "A giant switchboard that kept every voice on the planet. It wants the family's voices.",
		"layers": ["res://art/boss/operator_desk.png", "res://art/boss/operator_head.png"], "hframes": 1, "frames": [0],
		"place": "boss2", "script": "res://scripts/boss/operator.gd", "moves": 5})
	E.append({"id": "boss_set", "chapter": "boss", "kind": "boss", "name": "THE SET", "title": "LEVEL 3 BOSS",
		"desc": "The last TV that can still play the tape. It flips channels to fight.",
		"layers": ["res://art/boss/tv_body.png"], "hframes": 1, "frames": [0], "place": "boss3",
		"script": "res://scripts/boss/tv_boss.gd", "moves": 7})
	return _entries


static func _mob(ch: String, file: String, name: String, hf: int, frames: Array, desc: String) -> Dictionary:
	return {"id": file, "chapter": ch, "kind": "mob", "name": name, "title": "", "desc": desc,
		"tex": "res://art/enemies/%s.png" % file, "hframes": hf, "frames": frames,
		"place": "factory" if ch == "1" else L2_PLACE.get(file, "exchange")}


static func _elite(ch: String, file: String, name: String, title: String, hf: int, frames: Array, desc: String) -> Dictionary:
	var e := _mob(ch, file, name, hf, frames, desc)
	e["kind"] = "elite"
	e["title"] = title
	e["moves"] = ELITE_MOVES.get(file, 0)
	return e


## 第三关小怪说明：按打法给一句（再加上"从哪个屏幕里爬出来的"，见 bestiary_menu.gd）
const KIND_DESC := {
	"fly": "Flutters toward light. Hit it before it dives.",
	"hop": "Hops at you. Watch the red mark where it lands.",
	"dash": "Flashes, then dashes. Hit it while it rests.",
	"shoot": "Keeps its distance and fires. Close in fast.",
	"elite": "Watch for the red \"!\" before each move.",
}

## 第三关的场景（每个场景是一台电视里的一个频道）
const SCENES := {
	"workshop": "Workshop", "classroom": "Classroom", "subway": "Subway", "rain_street": "Rainy Street",
	"rooftop": "Rooftop", "living": "Living Room", "bedroom": "Bedroom", "kids": "Kids' Room", "study": "Study",
	"bathroom": "Bathroom", "attic": "Attic", "kitchen": "Kitchen", "beach": "Beach", "aquarium": "Aquarium",
	"snow_yard": "Snowy Yard", "harbor": "Harbor", "desert": "Desert", "forest": "Forest", "space": "Space",
	"ferris": "Fairground", "weather": "Weather Report", "test_card": "Test Card", "static": "Static",
}

## 第三关小怪的名字（精英的名字用 level3_mobs.gd 里的 elite_name）
const L3_NAMES := {
	"bulb_moth": "Bulb Moth", "bench_vise": "Bench Vise", "hand_saw": "Hand Saw", "nail_gun": "Nail Gun",
	"alarm_clock": "Alarm Clock", "flip_desk": "Flip-top Desk", "board_eraser": "Board Eraser", "film_projector": "Film Projector",
	"strap_bat": "Strap Bat", "walkman": "Walkman", "subway_rat": "Subway Rat", "farebox": "Farebox",
	"rain_umbrella": "Umbrella", "parking_meter": "Parking Meter", "wind_cat": "Wind-up Cat", "payphone": "Payphone",
	"laundry_shirt": "Laundry Shirt", "homing_pigeon": "Homing Pigeon", "yagi_bug": "Antenna Bug", "roof_dish": "Roof Dish",
	"rabbitears": "Rabbit Ears", "dialphone": "Dial Phone", "upright_vac": "Upright Vacuum", "gramophone": "Phonograph",
	"alarmclock": "Bedside Clock", "tapemoth": "Tape Moth", "iron": "Iron", "flashcam": "Flash Camera",
	"tinchopper": "Tin Chopper", "jackbox": "Jack-in-the-Box", "tincar": "Tin Car", "tinbot": "Tin Robot",
	"ledger": "Ledger", "globe": "Globe", "desklamp": "Desk Lamp", "keyclacker": "Typewriter",
	"tproll": "Toilet Roll", "plunger": "Plunger", "razor": "Razor", "hairdryer": "Hair Dryer",
	"filmreel": "Home Movie Reel", "cardbox": "Cardboard Box", "oldchair": "Old Chair", "projector": "Home Projector",
	"toaster": "Toaster", "fan": "Desk Fan", "mixer": "Hand Mixer", "percolator": "Percolator",
	"crab": "Crab", "jelly": "Jellyfish", "hermit": "Hermit Crab", "boombox": "Boombox",
	"aq_clownfish": "Clownfish", "aq_chest": "Treasure Chest", "aq_shrimp": "Shrimp", "aq_cannon": "Toy Cannon",
	"sy_snowman": "Snowman", "sy_bulb": "Fairy Light", "sy_sled": "Sled", "sy_stove": "Stove",
	"hb_gull": "Gull", "hb_buoy": "Buoy", "hb_crate": "Crate", "hb_foghorn": "Foghorn",
	"ds_vulture": "Vulture", "ds_jackrabbit": "Jackrabbit", "ds_wheel": "Wagon Wheel", "ds_cactus": "Cactus",
	"fr_mushroom": "Mushroom", "fr_firefly": "Firefly", "fr_beetle": "Beetle", "fr_squirrel": "Squirrel",
	"space_ufo": "UFO", "space_lander": "Lander", "space_sputnik": "Sputnik", "space_robot": "Space Robot",
	"ferris_balloon": "Balloon", "ferris_horse": "Carousel Horse", "ferris_bumper": "Bumper Car", "ferris_popcorn": "Popcorn Cart",
	"weather_cloud": "Cloud", "weather_sun": "Sun", "weather_ticker": "News Ticker", "weather_thermo": "Thermometer",
	"test_reticle": "Reticle", "test_bars": "Test Bars", "test_jack": "Jack Plug", "test_siggen": "Signal Generator",
	"static_ghost": "Ghost", "static_ears": "Static Ears", "static_coax": "Coax Cable", "static_tube": "Vacuum Tube",
}


# ---------------------------------------------------------------- 卡片背景、基础数据（作者 10-18："给怪加入对应的背景"、"写生命值之类的基础数据"）

## 背景图集 art/ui/bestiary_bg.png 的格子顺序（tools/make_bestiary_bg.py 生成，两边要一样）
const BG_PATH := "res://art/ui/bestiary_bg.png"
const BG_CELL := Vector2i(190, 110)
const BG_COLS := 6
const PLACES := ["factory", "exchange", "bridge", "cinema", "boss1", "boss2", "boss3",
	"l3_workshop", "l3_classroom", "l3_subway", "l3_rain_street", "l3_rooftop", "l3_living", "l3_bedroom", "l3_kids",
	"l3_study", "l3_bathroom", "l3_attic", "l3_kitchen", "l3_beach", "l3_aquarium", "l3_snow_yard", "l3_harbor",
	"l3_desert", "l3_forest", "l3_space", "l3_ferris", "l3_weather", "l3_test_card", "l3_static"]
## 第二关的怪在哪一段出（level2.gd 的 WAVES / REEL_WAVES）：交换局、胶片天桥（换卷）、放映厅（乐池）
const L2_PLACE := {
	"wire_snake": "exchange", "fuse_beetle": "exchange", "phone": "exchange", "scavenger": "exchange",
	"hooded_operator": "exchange", "switchboard": "exchange", "watchman": "exchange", "chief_operator": "exchange",
	"telegrapher": "exchange", "film_reel": "bridge", "film_editor": "bridge", "projector": "bridge",
	"audience": "cinema", "usher": "cinema", "slide_projector": "cinema", "gramophone": "cinema",
}
## 第一、二关精英有几招（各脚本的招式状态机里数的，10-18；电报员还没登场也算上）
const ELITE_MOVES := {
	"cuckoo": 2, "sewing": 2, "register": 2, "piano": 3, "vacuum": 2, "roller": 3,
	"switchboard": 2, "gramophone": 2, "projector": 2, "chief_operator": 3, "film_editor": 2, "watchman": 3, "telegrapher": 3,
}
## 平时走路 / 飞的速度用哪个常量（按顺序找第一个有的；跳的怪、不动的怪单独处理）
const SPEED_NAMES := ["WALK_SPEED", "MOVE_SPEED", "SPEED", "CRUISE_SPEED", "PATROL_SPEED", "SHUFFLE_SPEED",
	"DRIVE_SPEED", "CRAWL_SPEED", "ROLL_SPEED", "FLEE_SPEED"]
## 速度分 5 档（像素/秒，档的上限）
const SPEED_TIERS := [16.0, 22.0, 30.0, 40.0]

static var _bg: Texture2D
static var _stats := {}


static func bg_texture() -> Texture2D:
	if _bg == null and ResourceLoader.exists(BG_PATH):
		_bg = load(BG_PATH)
	return _bg


## 这只怪背景在图集里的那一格
static func bg_cell(e: Dictionary) -> Rect2:
	var i := maxi(PLACES.find(e.get("place", "factory")), 0)
	return Rect2((i % BG_COLS) * BG_CELL.x, (i / BG_COLS) * BG_CELL.y, BG_CELL.x, BG_CELL.y)


## 基础数据：{hp, atk, spd（0 不动、1~5 档、-1 不显示）, moves（0 不显示）}。直接从各个怪的脚本里读当前的数，
## 改了血量这里自动跟着变。单人的数（Boss 两个人打血 ×1.5；碰撞伤害随情绪档 ×1~2，这里是平静时的）
static func stats(e: Dictionary) -> Dictionary:
	var id: String = e["id"]
	if _stats.has(id):
		return _stats[id]
	var st := {"hp": 0, "atk": 0, "spd": -1, "moves": int(e.get("moves", 0))}
	var obj: Object = null
	var script: GDScript = null
	if e["kind"] == "boss":
		script = load(e["script"])
		var c := script.get_script_constant_map()
		st["hp"] = int(c.get("BASE_HP", 0))
		st["atk"] = int(c.get("CONTACT_DAMAGE", 0))
	elif id == "crawler":
		script = load("res://scripts/enemies/crawler.gd")
		var c := script.get_script_constant_map()
		st["hp"] = int(c.get("MAX_HP", 0))
		st["atk"] = int(c.get("CONTACT_DAMAGE", 0))
		st["spd"] = _tier(float(c.get("SPEED", 0)))
	else:
		if e.has("key"):
			obj = load("res://scripts/enemies/l3/l3_mob.gd").call("make", e["key"], "")
		else:
			obj = load("res://scripts/enemies/%s.gd" % id).new()
		obj.call("_setup")
		st["hp"] = int(obj.get("max_hp"))
		st["atk"] = int(obj.get("contact_damage"))
		st["spd"] = _speed_of(obj.get_script())
		# 第三关精英按打法走（l3_elite.gd 的 TYPE[打法]["walk"]，_setup 时放在 _tp 里）
		var tp = obj.get("_tp")
		if tp is Dictionary and tp.has("walk"):
			st["spd"] = _tier(float(tp["walk"]))
		obj.free()
	_stats[id] = st
	return st


static func _speed_of(script: Script) -> int:
	var s := script
	while s != null:
		var path := s.resource_path
		if path.ends_with("/kettle.gd"):
			return 0
		if path.ends_with("/flea.gd"):
			return 3   # 跳着扑过来：一跳 120 像素左右，按中档算
		var c := s.get_script_constant_map()
		for n in SPEED_NAMES:
			if c.has(n):
				return _tier(float(c[n]))
		s = s.get_base_script()
	return -1


static func _tier(v: float) -> int:
	if v <= 0.0:
		return 0
	for i in SPEED_TIERS.size():
		if v <= SPEED_TIERS[i]:
			return i + 1
	return 5
