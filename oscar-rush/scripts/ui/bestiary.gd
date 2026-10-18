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
	return path.trim_prefix("res://art/enemies/").get_basename().replace("/", "_")


static func mark(id: String) -> void:
	_load()
	if _seen.has(id):
		return
	_seen[id] = true
	if _path == "":
		return
	var cfg := ConfigFile.new()
	for k in _seen:
		cfg.set_value("seen", k, true)
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
	if cfg.load(_path) == OK and cfg.has_section("seen"):
		for k in cfg.get_section_keys("seen"):
			_seen[k] = true


## 某一页的条目（不含没登场的，除非开发者开关开着）
static func page(chapter: String) -> Array:
	return entries().filter(func(e): return e["chapter"] == chapter and (not e.get("unreleased", false) or reveal_all))


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
	# ---- 第三关：电视里的世界（L3Mob.DATA.MOBS，按场景排，每个场景四只小怪一只精英）
	var mobs: Dictionary = L3Mob.DATA.MOBS
	for key in mobs:
		var cfg: Dictionary = mobs[key]
		var kind: String = cfg["kind"]
		var hf: int = cfg["hframes"]
		var e := {
			"id": "l3_" + key, "chapter": "3", "kind": "elite" if kind == "elite" else "mob",
			"name": cfg.get("elite_name", L3_NAMES.get(key, key.capitalize())), "title": cfg.get("title", ""),
			"desc": KIND_DESC.get(kind, ""), "where": SCENES.get(cfg["scene"], cfg["scene"].capitalize()),
			"tex": cfg["texture"], "hframes": hf, "frames": [0, 1] if hf > 1 and kind != "hop" else [0],
		}
		E.append(e)
	# ---- Boss
	E.append({"id": "boss_stoker", "chapter": "boss", "kind": "boss", "name": "THE STOKER", "title": "LEVEL 1 BOSS",
		"desc": "An old boiler that burns memories. It wants the tape in your lantern.",
		"layers": ["res://art/boss/stoker_body.png"], "hframes": 1, "frames": [0]})
	E.append({"id": "boss_operator", "chapter": "boss", "kind": "boss", "name": "THE OPERATOR", "title": "LEVEL 2 BOSS",
		"desc": "A giant switchboard that kept every voice on the planet. It wants the family's voices.",
		"layers": ["res://art/boss/operator_desk.png", "res://art/boss/operator_head.png"], "hframes": 1, "frames": [0]})
	E.append({"id": "boss_set", "chapter": "boss", "kind": "boss", "name": "THE SET", "title": "LEVEL 3 BOSS",
		"desc": "The last TV that can still play the tape. It flips channels to fight.",
		"layers": ["res://art/boss/tv_body.png"], "hframes": 1, "frames": [0]})
	return _entries


static func _mob(ch: String, file: String, name: String, hf: int, frames: Array, desc: String) -> Dictionary:
	return {"id": file, "chapter": ch, "kind": "mob", "name": name, "title": "", "desc": desc,
		"tex": "res://art/enemies/%s.png" % file, "hframes": hf, "frames": frames}


static func _elite(ch: String, file: String, name: String, title: String, hf: int, frames: Array, desc: String) -> Dictionary:
	var e := _mob(ch, file, name, hf, frames, desc)
	e["kind"] = "elite"
	e["title"] = title
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
