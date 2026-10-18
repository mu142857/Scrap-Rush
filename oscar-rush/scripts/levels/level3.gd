extends Node2D
## 第三关「显像管仓库」：一整面电视墙，每块屏幕是一个能走进去的场景（草图/第三关/crt_level3.py 画的）。
## 地图、碰撞、平台、洞都在 Level3Data（export_level3.py 生成）。
## - 屏幕层不吃场景压暗，自己发光；每块屏幕前面一盏对应颜色的灯，只开镜头附近的几盏（灯太多手机会卡）。
## - 上下的洞里垂着电线：在洞里按住跳就往上爬，松手就往下掉。
## - 怪按屏幕的场景来（L3Mob）：每块屏幕摆这个场景的小怪；大屏幕里是遭遇战，最后一波出这个场景的精英怪。
## - 走到家乡那栋房子的门口，进结局。
## 单独打开：Godot --path . scenes/level3.tscn
## F3 显示碰撞框，R 从本关开头重来。

const D := preload("res://scripts/levels/level3_data.gd")
const DARKNESS := Color(0.36, 0.35, 0.41)
const CLIMB_SPEED := 140.0
## 单向平台（家具顶、屋顶、伞、洞口的格栅）单独一层：只有主角和马灯会踩，怪和精英直接落到地上
const PLATFORM_LAYER := 64
## 镜头中心多远以内的屏幕灯才开
const LIGHT_RANGE := 620.0
const TINT_LIGHT := {
	"color": Color(1.0, 0.82, 0.6),
	"bw": Color(0.75, 0.78, 0.86),
	"green": Color(0.5, 0.9, 0.56),
	"amber": Color(1.0, 0.68, 0.32),
}
## 这几块屏幕不摆怪：玄关、家乡（出生点在第一块屏幕左边的走廊里，第一块屏幕照常摆）
const NO_ENEMY := ["entry", "hometown"]
## 遭遇战的特殊玩法（见 l3_mode.gd）：场景名 → 玩法。没列的是普通场子。
## 三条路线都至少碰到三种：路线 1 沙漠风、港口停电、厨房购物……；第一块屏幕（卧室）故意留普通的
const MODES := {
	"harbor": "blackout", "aquarium": "blackout", "attic": "blackout", "subway": "blackout", "bathroom": "blackout",
	"desert": "wind", "rooftop": "wind", "beach": "wind", "weather": "wind", "snow_yard": "wind",
	"static": "signal", "test_card": "signal", "space": "signal", "rain_street": "signal", "classroom": "signal",
	"kitchen": "shop", "living": "shop", "kids": "shop", "workshop": "shop", "ferris": "shop",
}
## 清过场的屏幕，人离开再回来时，有这个几率零星刷出 1～3 只小怪（不关门、不算遭遇战）；同一块屏幕不连着刷
const REVISIT_CHANCE := 0.4
const REVISIT_WARN := 0.7
## 只挡怪、不挡人的墙（单独一层，只有屏幕里摆的怪会碰）：洞口两边各一堵矮墙，每块屏幕左右边上各一堵整面墙。
## 小怪来回走会掉进洞里、或者从门口走到隔壁屏幕，原来那块屏幕就空了（2026-10-17 作者说"有的屏幕没怪"）
const MOB_WALL_LAYER := 128
const MOB_WALL_HEIGHT := 24.0
## 摆怪时离洞口至少这么远
const HOLE_CLEAR := 12.0
const ENEMY_SCRIPTS := {
	"crawler": "res://scripts/enemies/crawler.gd",
	"moth": "res://scripts/enemies/moth.gd",
	"flea": "res://scripts/enemies/flea.gd",
	"shaver": "res://scripts/enemies/shaver.gd",
}

var hud: Hud
var _debug := false
var _retrying := false
var _leaving := false
var _lights: Array[PointLight2D] = []
## 洞口的绿灯（每帧推一下时间重画）
var _beacons: Array[Node2D] = []
var _far: Node2D
## 第一次走进家乡那块屏幕时打一句话（到家的感觉）
var _home_seen := false
const FAR_FOLLOW := 0.6
## 平时摆的小怪和它所在的屏幕：{node, rect}（rect 到地面为止）
var _screen_mobs: Array = []
var _wake_t := 0.0
## 场子屏幕：清场以后回访刷怪用，{rect, enc, smalls, tint, floor, inside, left_clear, last}
var _revisit: Array = []
var _modes: Array[L3Mode] = []
## 关卡里的指路牌（横幅出来的时候藏起来，见 _process）
var _signs: Array[HintSign] = []
## 开场横幅还没出来（开场动画放着、或者动画放完到横幅出来之间那 1.2 秒）：指路牌先别出来，免得闪一下又被横幅藏掉
var _opening_pending := false
## 回访刷怪的几率（自测时可以改成 1）
var revisit_chance := REVISIT_CHANCE
## 出口：家门口。门在山坡上，比屏幕地面高一点，所以一直延到地面，走到门前就算
var _exit := Rect2()


func _ready() -> void:
	var home_floor: float = D.SCREENS[D.SCREENS.size() - 1]["floor"]
	_exit = Rect2(D.END.x - 12, D.END.y - 30, 24, home_floor - D.END.y + 32)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players=") and Run.players.size() == 1:
			var n := clampi(arg.trim_prefix("--players=").to_int(), 1, 4)
			var schemes := ["kb_left", "kb_right", "pad0", "pad1"]
			Run.players.clear()
			for i in n:
				Run.players.append({"input": schemes[i], "skin": Run.SKINS[i]})
			Run.reset_run()
	# 从存档点重来时 Run._resuming 是真（start_level 会把它清掉，所以先记下来）：重来不放开场动画、不出开场横幅
	var retrying: bool = Run.get("_resuming")
	Run.start_level()
	Run.crystal_broken.connect(_on_crystal_broken)

	# 四层图都切成 2048 宽的竖条拼起来（网页版贴图不能太宽，见 export_level3.py）。
	# 远景跟镜头 0.6 倍走（和 ParallaxScene 同一个算法：竖直方向视差减半）
	_far = _tiled_layer("far", -20, Color(0.78, 0.78, 0.86), false)
	_tiled_layer("mid", -19, Color.WHITE, false)
	_tiled_layer("screens", -17, Color.WHITE, true)       # 屏幕层：自己发光，不吃压暗
	_tiled_layer("near", -16, Color.WHITE, false)

	var dark := CanvasModulate.new()
	dark.color = DARKNESS
	add_child(dark)

	for r in D.SOLIDS:
		_add_box(r, false)
	for p in D.PLATFORMS:
		_add_box(Rect2(p[0], p[2], p[1] - p[0], 4), true)
	# 关卡四周的墙
	for r in [Rect2(-16, -16, D.BOUNDS.size.x + 32, 16), Rect2(-16, -16, 16, D.BOUNDS.size.y + 32),
			Rect2(D.BOUNDS.size.x, -16, 16, D.BOUNDS.size.y + 32)]:
		_add_box(r, false)

	for s in D.SCREENS:
		var rect: Array = s["rect"]
		var l := PointLight2D.new()
		l.texture = Game.light_texture()
		l.color = TINT_LIGHT.get(s["tint"], Color.WHITE)
		l.energy = 0.75
		l.position = Vector2((rect[0] + rect[2]) * 0.5, s["floor"] - 10)
		l.texture_scale = maxf(rect[2] - rect[0], rect[3] - rect[1]) * 0.75 / 32.0
		l.range_item_cull_mask = 1 | 2
		l.enabled = false
		add_child(l)
		_lights.append(l)

	_add_mob_walls()
	_place_enemies()
	_place_hints()
	_place_beacons()

	var first: Player = null
	for i in Run.players.size():
		var p := Player.new()
		p.input_prefix = Run.players[i]["input"]
		p.skin = Run.players[i]["skin"]
		p.position = D.START + Vector2(i * 14, 0)
		add_child(p)
		p.collision_mask |= PLATFORM_LAYER
		if first == null:
			first = p

	var crystal := Crystal.new()
	crystal.position = D.START
	add_child(crystal)
	crystal.collision_mask |= PLATFORM_LAYER
	crystal.pick_up(first, true)

	var cam := Level3Camera.new()
	cam.bounds = D.BOUNDS
	for s in D.SCREENS:
		var r: Array = s["rect"]
		cam.screens.append({"rect": Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]), "floor": s["floor"]})
	add_child(cam)
	cam.snap()

	hud = Hud.new()
	add_child(hud)
	for m in _modes:
		m.hud = hud
	# 开场说清目标（新玩家报告第 1 条：不知道往哪走）。从存档点重来就不再出
	if not retrying:
		# 开场横幅在开场动画（LevelIntro，_ready 最后接）整段放完以后再出：
		# 名字卡和横幅都在屏幕中间，不能叠（框架以后可能在名字卡时就放开暂停，所以不靠暂停来等，等它的 finished）
		_opening_pending = true

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tour="):
			var tour: Node = load("res://scripts/debug/tour.gd").new()
			tour.set("out_dir", arg.trim_prefix("--tour="))
			add_child(tour)
		if arg.begins_with("--l3scene="):
			var sc: Node = load("res://scripts/debug/l3_scene_check.gd").new()
			sc.set("scene_name", arg.trim_prefix("--l3scene="))
			for a2 in OS.get_cmdline_user_args():
				if a2.begins_with("--l3shots="):
					sc.set("shots_dir", a2.trim_prefix("--l3shots="))
				if a2.begins_with("--l3at="):
					var xy := a2.trim_prefix("--l3at=").split(",")
					sc.set("at", Vector2(xy[0].to_float(), xy[1].to_float()))
			add_child(sc)
		if arg.begins_with("--l3auto="):
			var ap: Node = load("res://scripts/debug/l3_autopilot.gd").new()
			ap.set("route_i", arg.trim_prefix("--l3auto=").to_int())
			for a2 in OS.get_cmdline_user_args():
				if a2.begins_with("--l3watch="):
					ap.set("watch", a2.trim_prefix("--l3watch=").to_float())
				if a2.begins_with("--l3shots="):
					ap.set("shots_dir", a2.trim_prefix("--l3shots="))
			add_child(ap)
		if arg.begins_with("--l3mode="):
			var mc: Node = load("res://scripts/debug/l3_mode_check.gd").new()
			mc.set("scene_name", arg.trim_prefix("--l3mode="))
			for a2 in OS.get_cmdline_user_args():
				if a2.begins_with("--l3signal="):
					mc.set("signal_start", a2.trim_prefix("--l3signal=").to_float())
				if a2 == "--l3revisit":
					mc.set("revisit", true)
				if a2.begins_with("--l3shots="):
					mc.set("shots_dir", a2.trim_prefix("--l3shots="))
			add_child(mc)
		if arg == "--l3fix":
			add_child(load("res://scripts/debug/l3_fix_check.gd").new())
		if arg == "--l3enc":
			add_child(load("res://scripts/debug/l3_enc_check.gd").new())
		if arg == "--l3check":
			add_child(load("res://scripts/debug/l3_check.gd").new())
		if arg.begins_with("--autotest="):
			var t: Node = load("res://scripts/debug/autotest.gd").new()
			t.set("out_dir", arg.trim_prefix("--autotest="))
			add_child(t)

	# 开场动画：老电脑开机（l3_boot_intro.gd），用三关共用的 LevelIntro 框架播（黑边、跳过、名字卡、
	# 只在一局第一次进关时播、测试时不播都归框架）。开机画面自己从黑屏开始画，所以不要框架的黑底
	if LevelIntro.should_play(self):
		var intro := LevelIntro.make(3, "SCREENS", L3BootIntro.new())
		intro.start_covered = false
		intro.finished.connect(_opening_banner)
		add_child(intro)
	elif _opening_pending:
		_opening_banner()


## 开场横幅"去录像里那栋房子"：开场动画放完（或者没放）1.2 秒后出
func _opening_banner() -> void:
	_after(1.2, func() -> void:
		_opening_pending = false
		if is_instance_valid(hud) and not _leaving:
			hud.show_banner(tr("Find the house from the tape. Up and to the right."), 3.0))


func _tiled_layer(layer: String, z: int, tint: Color, unshaded: bool) -> Node2D:
	var root := Node2D.new()
	root.z_index = z
	root.modulate = tint
	var mat: CanvasItemMaterial = null
	if unshaded:
		mat = CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for i in D.TILES:
		var sp := Sprite2D.new()
		sp.texture = load("res://art/levels/l3_%s_%d.png" % [layer, i])
		sp.centered = false
		sp.position = Vector2(i * D.TILE_W, 0)
		if mat:
			sp.material = mat
		root.add_child(sp)
	add_child(root)
	return root


func _add_box(r: Rect2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = PLATFORM_LAYER if one_way else 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)


## 一块屏幕的地面上有没有洞（摆怪、放遭遇战都要避开）
func _has_hole(s: Dictionary) -> bool:
	var rect: Array = s["rect"]
	for h in D.HOLES:
		if h[0] < rect[2] and h[1] > rect[0] and (h[2] == s["floor"] or h[3] == s["floor"]):
			return true
	return false


## 摆怪（2026-10-17 第三版，作者：怪别删，把屏幕做大）：
## - 每种场景（23 种）在地图上有一块大屏是它的精英战场子（Level3Data 里 encounter = true）：
##   关门的遭遇战，三波：两只小怪 → 两只小怪 → 精英怪单独出来。场子都是大屏、地上没洞，关上门跑不掉。
## - 别的屏幕按玻璃宽度摆这个场景的小怪：不到 MID_SCREEN 1 只，到 WIDE_SCREEN 2 只，再宽 3 只；
##   射击怪只放进宽度够 SHOOTER_SCREEN 的屏幕；离左右入口至少 ENTRY_CLEAR，人一进来不会贴脸。
## - 只有主角所在那块屏幕里的怪会动，别的屏幕里的怪定住（像暂停的电视画面），见 _wake_mobs。
## 遭遇战清场回血：每只小怪回这么多（见 _place_enemies）
const HEAL_PER_MOB := 1.4
const MID_SCREEN := 200.0
const WIDE_SCREEN := 330.0
const SHOOTER_SCREEN := 260.0
const ENTRY_CLEAR := 36.0


func _place_enemies() -> void:
	L3Mob.arena = D.BOUNDS
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in D.SCREENS.size():
		var s: Dictionary = D.SCREENS[i]
		if s["name"] in NO_ENEMY:
			continue
		var rect: Array = s["rect"]
		var w: float = rect[2] - rect[0]
		var fy: float = s["floor"]
		var tint: String = s["tint"]
		var smalls := L3Mob.smalls(s["name"])
		if smalls.is_empty():
			continue
		var bag := _shuffled(smalls, rng)
		var elite := L3Mob.elite(s["name"])
		if s.get("encounter", false) and elite != "":
			var enc := Encounter.new()
			enc.left = rect[0] + 10
			enc.right = rect[2] - 10
			enc.ceil_y = rect[1]
			enc.floor_left = fy
			enc.floor_right = fy
			# 2026-10-18 作者试玩"没有压迫感"：宽屏场子多放小怪（两波小怪 + 精英，波数不变）；
			# 清场回血按小怪数量给（每只 1.4，5 只回 7；原来不管多少只都回 12，第三关是净回血）
			# 10-18 作者又说"敌人太多了"：一场加起来不超过 8 只（精英最多再叫出 2 只），
			# 宽屏改成 3 只 → 2 只，窄屏 2 → 2，一场 5 或 4 只小怪 + 精英
			var first := 3 if w >= WIDE_SCREEN else 2
			var second := 2
			var w1: Array = []
			var w2: Array = []
			for k in first:
				w1.append(bag[k % bag.size()])
			for k in second:
				w2.append(bag[(k + first) % bag.size()])
			enc.waves = [w1, w2, [elite]]
			enc.clear_heal = roundf(HEAL_PER_MOB * (first + second))
			enc.spawn_hook = _spawn_in_encounter.bind(tint, rect[1], rect[0] + 10, rect[2] - 10)
			add_child(enc)
			var glass := Rect2(rect[0], rect[1], w, fy - rect[1])
			if MODES.has(s["name"]):
				var mode := L3Mode.new()
				mode.kind = MODES[s["name"]]
				mode.rect = glass
				mode.floor_y = fy
				mode.enc = enc
				for p in D.PLATFORMS:
					if p[0] >= rect[0] and p[1] <= rect[2] and p[2] > rect[1] and p[2] < fy:
						mode.platforms.append(p)
				add_child(mode)
				_modes.append(mode)
			_revisit.append({"rect": glass, "enc": enc, "smalls": smalls, "tint": tint, "floor": fy,
				"inside": false, "left_clear": false, "last": false})
			continue
		var n := 1 if w < MID_SCREEN else (2 if w < WIDE_SCREEN else 3)
		var left: float = rect[0] + ENTRY_CLEAR
		var right: float = rect[2] - ENTRY_CLEAR
		for k in n:
			var kind: String = bag[k % bag.size()] if w >= SHOOTER_SCREEN else _not_shooter(bag, k)
			var x: float = _off_hole(left + (right - left) * (k + 1) / (n + 1) + rng.randf_range(-8, 8), fy)
			var e := _make_mob(kind, tint)
			e.position = Vector2(x, fy - (30.0 if e is Moth else 0.0))
			add_child(e)
			# _ready 里会把 collision_mask 设成 1，所以加进场景以后再加上挡怪墙那一层
			(e as CollisionObject2D).collision_mask |= MOB_WALL_LAYER
			_screen_mobs.append({"node": e, "rect": Rect2(rect[0], rect[1], w, fy - rect[1] + 2)})
	_wake_mobs()


## 洞口两边各立一堵矮墙（只在洞所在的那层地面上），每块屏幕左右边上各立一堵到天花板的墙，怪撞墙会掉头
func _add_mob_walls() -> void:
	for h in D.HOLES:
		for x in [h[0] - 3.0, h[1]]:
			_mob_wall(Rect2(x, h[2] - MOB_WALL_HEIGHT, 3, MOB_WALL_HEIGHT))
	for s in D.SCREENS:
		var r: Array = s["rect"]
		var fy: float = s["floor"]
		for x in [r[0] - 3.0, r[2]]:
			_mob_wall(Rect2(x, r[1], 3, fy - r[1]))


func _mob_wall(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = MOB_WALL_LAYER
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	body.add_child(shape)
	add_child(body)


## 摆怪的 x 落在这层地面的洞上（或离洞口太近）就挪到洞外面离得近的那一边
func _off_hole(x: float, floor_y: float) -> float:
	for h in D.HOLES:
		if h[2] != floor_y:
			continue
		if x > h[0] - HOLE_CLEAR and x < h[1] + HOLE_CLEAR:
			return h[0] - HOLE_CLEAR if x - h[0] < h[1] - x else h[1] + HOLE_CLEAR
	return x


## 袋子里第 k 只不是射击怪的（没有就照给）
func _not_shooter(bag: Array, k: int) -> String:
	var ok := bag.filter(func(n): return L3Mob.DATA.MOBS[n]["kind"] != "shoot")
	return ok[k % ok.size()] if not ok.is_empty() else bag[k % bag.size()]


## 只让有人在的那块屏幕里的怪动。别的屏幕里的怪定住：不追人、不开枪、不伤人
func _wake_mobs() -> void:
	var feet: Array[Vector2] = []
	for n in get_tree().get_nodes_in_group("player"):
		feet.append((n as Node2D).global_position)
	for m in _screen_mobs.duplicate():
		var node: Node = m["node"]
		if not is_instance_valid(node):
			_screen_mobs.erase(m)
			continue
		var r: Rect2 = m["rect"]
		var awake := false
		for f in feet:
			if r.grow(6.0).has_point(f):
				awake = true
		node.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED


func _shuffled(arr: Array, rng: RandomNumberGenerator) -> Array:
	var out := arr.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## 第三关的怪按屏幕上色；第一关的怪（还没画到的场景先顶上）照原样
func _make_mob(kind: String, tint: String) -> Node2D:
	if L3Mob.exists(kind):
		return L3Mob.make(kind, tint)
	return load(ENEMY_SCRIPTS.get(kind, ENEMY_SCRIPTS["crawler"])).new()


## 遭遇战生怪：第三关的怪由这里造（要按屏幕上色），别的交回 Encounter 自己造
func _spawn_in_encounter(kind: String, x: float, tint: String, ceil_y: float, left: float, right: float) -> Node2D:
	if not L3Mob.exists(kind):
		return null
	var cfg: Dictionary = L3Mob.DATA.MOBS[kind]
	# 精英怪落在场子里离主角远的那一头
	if cfg["kind"] == "elite":
		var px := (left + right) * 0.5
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			px = (players[0] as Node2D).global_position.x
		var half: float = cfg["frame_size"].x * 0.5 + 6.0
		x = right - half if px < (left + right) * 0.5 else left + half
	else:
		x = _flank_x(x, left, right)
	var e := L3Mob.make(kind, tint)
	# 脚底离天花板至少一个身高，不然高的精英怪一生出来上半截就卡在外壳里
	e.position = Vector2(x, ceil_y + cfg["frame_size"].y + 4.0)
	add_child(e)
	return e


## 遭遇战的小怪轮流落在主角左边、右边，离人 60～110：两边一起围上来，而不是全堆在一头
## （2026-10-18 作者试玩"没有压迫感"）。一边放不下就放另一边
var _flank_side := 1


func _flank_x(x: float, left: float, right: float) -> float:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return x
	var px := (players[0] as Node2D).global_position.x
	_flank_side = -_flank_side
	for side in [_flank_side, -_flank_side]:
		var fx: float = px + side * randf_range(60.0, 110.0)
		if fx > left + 18.0 and fx < right - 18.0:
			return fx
	return x


## 回访刷怪：人走进一块已经清过场的屏幕（清场以后离开过）时掷一次骰子
func _check_revisits() -> void:
	var feet: Array[Vector2] = []
	for n in get_tree().get_nodes_in_group("player"):
		feet.append((n as Node2D).global_position)
	for r in _revisit:
		var inside := false
		for f in feet:
			if (r["rect"] as Rect2).grow(4.0).has_point(f):
				inside = true
		var enc: Encounter = r["enc"]
		if inside and not r["inside"] and enc.cleared and r["left_clear"]:
			if r["last"]:
				r["last"] = false
			elif randf() < revisit_chance:
				r["last"] = true
				_revisit_spawn(r, feet[0] if not feet.is_empty() else (r["rect"] as Rect2).get_center())
		if not inside and r["inside"] and enc.cleared:
			r["left_clear"] = true
		r["inside"] = inside


## 刷 1～3 只：先在落点闪一下雪花（0.7 秒），再把怪放出来。离人至少 70，不落在洞口
func _revisit_spawn(r: Dictionary, player_at: Vector2) -> void:
	var rect: Rect2 = r["rect"]
	var fy: float = r["floor"]
	var n := randi_range(1, 3)
	var xs: Array[float] = []
	for k in n:
		for _try in 16:
			var x := _off_hole(randf_range(rect.position.x + 24.0, rect.end.x - 24.0), fy)
			if absf(x - player_at.x) >= 70.0 and xs.all(func(o): return absf(o - x) >= 20.0):
				xs.append(x)
				break
	for x in xs:
		var kind: String = r["smalls"][randi() % r["smalls"].size()]
		var flash := _StaticFlash.new()
		flash.position = Vector2(x, fy)
		flash.add_to_group("revisit_flash")
		add_child(flash)
		Game.sfx("static", -16.0, 1.4, 0.1)
		_after(REVISIT_WARN, func() -> void:
			if is_instance_valid(flash):
				flash.queue_free()
			if _leaving:
				return
			var e := _make_mob(kind, r["tint"])
			e.position = Vector2(x, fy - (30.0 if e is Moth else 0.0))
			add_child(e)
			(e as CollisionObject2D).collision_mask |= MOB_WALL_LAYER
			_screen_mobs.append({"node": e, "rect": Rect2(rect.position.x, rect.position.y, rect.size.x, rect.size.y + 2)}))


## 过一会儿再做某事。用挂在关卡下面的 Timer，不用 SceneTree 的计时器：
## 人死了重来、走出关卡时 Timer 跟着关卡一起没了，不会在关卡释放以后再回调
func _after(sec: float, fn: Callable) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = sec
	add_child(t)
	t.timeout.connect(func() -> void:
		fn.call()
		t.queue_free())
	t.start()


## 回访刷怪的出场预兆：落点上一块一闪一闪的雪花
class _StaticFlash:
	extends Node2D

	var _t := 0.0

	func _ready() -> void:
		z_index = 7
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var h := int(minf(_t * 60.0, 18.0))
		for y in h:
			for x in range(-7, 7):
				if randf() < 0.45:
					var v := randf_range(0.5, 1.0)
					draw_rect(Rect2(x, -y - 1, 1, 1), Color(v, v, v, 0.85))


func _place_hints() -> void:
	var jump_key := Controls.key_name(Run.players[0]["input"], "jump")
	var first: Array = D.SCREENS[0]["rect"]
	var signs := [
		{"zone": Rect2(0, D.START.y - 80, first[0] + 60, 80), "at": Vector2(first[0] + 20, D.START.y - 40),
		 "text": "Walk into the screens", "arrow": "right"},
		{"zone": Rect2(D.END.x - 60, D.END.y - 60, 120, 60), "at": D.END + Vector2(0, -36), "text": "Home", "arrow": "down"},
	]
	# 每个洞底下都放一块"按住跳顺着电线爬"（2026-10-17 夜：原来只有第一个洞有，走别的路线的人看不到）
	for sh in D.SHAFTS:
		signs.append({"zone": Rect2(sh.position.x - 40, sh.end.y - 60, sh.size.x + 80, 60),
			"at": Vector2(sh.get_center().x, sh.end.y - 34), "text": tr("Hold %s on the cable to climb") % jump_key, "arrow": "up"})
	# 一段走到头是实心外壳：墙前提示"此路不通，找电线往上爬"，箭头指回头
	for i in range(1, D.SCREENS.size()):
		var s: Dictionary = D.SCREENS[i]
		if not s.get("wall_left", false):
			continue
		var prev: Dictionary = D.SCREENS[i - 1]
		var pr: Array = prev["rect"]
		var r: Array = s["rect"]
		signs.append({"zone": Rect2(pr[2] - 70, prev["floor"] - 60, 70, 60), "at": Vector2(pr[2] - 34, prev["floor"] - 30),
			"text": "Dead end - find a cable up", "arrow": "left"})
		signs.append({"zone": Rect2(r[0], s["floor"] - 60, 70, 60), "at": Vector2(r[0] + 34, s["floor"] - 30),
			"text": "Dead end - find a cable up", "arrow": "right"})
	for h in signs:
		var sign := HintSign.new()
		# 区域下边都正好在地面上，Rect2.has_point 不算下边线：人站着不动时 y 正好等于地面，牌子会时有时无。
		# 往下多算 4 像素（2026-10-17 夜，第二关会话发现同样的问题）
		sign.zone = (h["zone"] as Rect2).grow_individual(0, 0, 0, 4)
		sign.position = h["at"]
		sign.text = h["text"]
		sign.arrow = h["arrow"]
		sign.level_width = D.BOUNDS.size.x
		add_child(sign)
		_signs.append(sign)


## 画面上正显示着的提示框（屏幕坐标）：新手提示框（Coach，在顶上或底下）、底部的按键提示条
func _ui_boxes() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if hud == null:
		return out
	var coach: Node = hud.get("_coach")
	if coach:
		var box: Control = coach.get("_box")
		if box and box.modulate.a > 0.01:
			out.append(box.get_global_rect().grow(4.0))
	var hint: Control = hud.get("_hint")
	if hint and hint.modulate.a > 0.01:
		out.append(hint.get_global_rect().grow(4.0))
	return out


## 指路牌的字在屏幕上压到了某个提示框：先藏起来（两段字不叠在一起）
func _sign_blocked(sg: HintSign, boxes: Array[Rect2]) -> bool:
	if boxes.is_empty():
		return false
	var lb: Label = sg.get("_label")
	if lb == null:
		return false
	var xf := lb.get_global_transform_with_canvas()
	var r := Rect2(xf.origin, lb.size * xf.get_scale())
	for b in boxes:
		if r.intersects(b):
			return true
	return false


func _banner_showing() -> bool:
	if hud == null:
		return false
	var b: Label = hud.get("_banner")
	return b != null and b.visible and b.modulate.a > 0.01


## 往上爬的洞口：开口正下方、顺着电线有三个小"^"，从下往上一个接一个亮，开口里一小团绿光慢慢一明一暗。
## 一进这块屏幕就看得出"从这里上去"（新玩家报告第 1 条）。箭头带一圈暗边，哪种色调的屏幕上都看得清；
## 死胡同那头没有洞，也就没有箭头
const BEACON := Color(0.55, 1.0, 0.6)
const CHEVRON := [Vector2i(0, 0), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-2, 2), Vector2i(2, 2)]


func _place_beacons() -> void:
	for h in D.HOLES:
		var top := float(h[2])
		# 洞下面那块屏幕的玻璃顶：箭头画在玻璃上，紧贴开口下面
		for s in D.SCREENS:
			var r: Array = s["rect"]
			if h[0] >= r[0] and h[1] <= r[2] and float(h[3]) == float(s["floor"]):
				top = r[1]
		var lamps := Node2D.new()
		lamps.z_index = -15
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		lamps.material = unshaded
		lamps.position = Vector2(float(h[0]) + 11.0, top + 8.0)
		lamps.set_meta("t", 0.0)
		lamps.draw.connect(func() -> void:
			var t: float = lamps.get_meta("t")
			for i in 3:
				# 最下面的先亮，往上走，每 1.5 秒一轮；没轮到的是暗绿，看得出是一串
				var k := fposmod(t / 1.5 - (2 - i) / 3.0, 1.0)
				var on := clampf(1.0 - k * 2.0, 0.0, 1.0)
				var c := BEACON.darkened(0.55).lerp(BEACON.lightened(0.4), on)
				var y := float(i) * 6.0
				for d in CHEVRON:
					lamps.draw_rect(Rect2(d.x - 1, y + d.y - 1, 3, 3), Color(0.05, 0.08, 0.06, 0.9))
				for d in CHEVRON:
					lamps.draw_rect(Rect2(d.x, y + d.y, 1, 1), c))
		add_child(lamps)
		_beacons.append(lamps)
		var l := PointLight2D.new()
		l.texture = Game.light_texture()
		l.color = BEACON
		l.energy = 0.5
		l.texture_scale = 1.4
		l.position = Vector2((h[0] + h[1]) * 0.5, top + 6.0)
		l.range_item_cull_mask = 1 | 2
		l.enabled = false
		add_child(l)
		_lights.append(l)
		var tw := create_tween().set_loops()
		tw.tween_property(l, "energy", 0.9, 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(l, "energy", 0.4, 0.8).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	_follow_far()
	# 屏幕中间有横幅（开场"去录像里那栋房子"、特殊玩法的标题、到家、通关）的时候，指路牌全藏起来，
	# 横幅消失以后再淡回来：两段字不叠在一起（2026-10-18 作者实机截图："注意不要有这种文字重叠"）
	var banner := _opening_pending or _banner_showing()
	var boxes := _ui_boxes()
	for sg in _signs:
		if banner or _sign_blocked(sg, boxes):
			# 牌子自己每帧按淡入淡出设 visible，所以藏的时候连它的处理一起停掉，透明度清零，横幅走了再从零淡入
			sg.process_mode = Node.PROCESS_MODE_DISABLED
			sg.visible = false
			sg.set("_alpha", 0.0)
			sg.modulate.a = 0.0
		elif sg.process_mode == Node.PROCESS_MODE_DISABLED:
			sg.process_mode = Node.PROCESS_MODE_INHERIT
	for b in _beacons:
		b.set_meta("t", float(b.get_meta("t")) + delta)
		b.queue_redraw()
	_wake_t -= delta
	if _wake_t <= 0.0:
		_wake_t = 0.15
		_wake_mobs()
		_check_revisits()
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	for l in _lights:
		l.enabled = l.position.distance_to(c) < LIGHT_RANGE


func _follow_far() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or _far == null:
		return
	var off := cam.get_screen_center_position() - D.BOUNDS.get_center()
	var lag := 1.0 - FAR_FOLLOW
	_far.position = Vector2(off.x * lag, off.y * lag * 0.5).round()


func _physics_process(_delta: float) -> void:
	if _leaving or _retrying:
		return
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null:
			continue
		if _exit.has_point(p.global_position):
			_leave()
			return
		if not _home_seen and _in_home(p.global_position):
			_home_seen = true
			Game.sfx("tvon", -8.0, 0.9)
			hud.show_banner(tr("It looks just like the tape."), 2.6)

		# 洞里的电线：按住跳往上爬（关卡的 _physics_process 先于玩家跑，玩家那边再加重力也还是往上）
		if Input.is_action_pressed(p.input_prefix + "_jump"):
			for sh in D.SHAFTS:
				if sh.has_point(p.global_position):
					p.velocity.y = -CLIMB_SPEED
					break


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F3:
				_debug = not _debug
				queue_redraw()


func _on_crystal_broken() -> void:
	hud.show_banner("THE TAPE IS RUINED")
	Game.flash(Color(0.9, 0.9, 0.95), 0.5, 1.2)
	Game.add_shake(5.0)
	get_tree().paused = true
	await get_tree().create_timer(1.6, true, false, true).timeout
	get_tree().paused = false
	_retry()


func _in_home(feet: Vector2) -> bool:
	var s: Dictionary = D.SCREENS[D.SCREENS.size() - 1]
	var r: Array = s["rect"]
	return feet.x > r[0] + 24 and feet.x < r[2] and feet.y > r[1] and feet.y <= float(s["floor"]) + 1.0


func _leave() -> void:
	_leaving = true
	# 到家门口：一下暖光、一声"叮"，再出通关横幅
	Game.flash(Color(1.0, 0.86, 0.62), 0.35, 1.2)
	Game.sfx("ding", -6.0, 0.9)
	hud.show_banner("SCREENS CLEARED")
	await get_tree().create_timer(1.6, true, false, true).timeout
	# 最后一次商店就在老电视门口，出去就是最终 Boss（boss3），打完进结局
	ShopRoom.next_scene = "res://scenes/boss3.tscn"
	SceneFade.go(get_tree(), "res://scenes/shop.tscn")


func _retry() -> void:
	if _retrying:
		return
	_retrying = true
	Engine.time_scale = 1.0
	Run.retry_level()
	# 重来也用统一的渐黑渐开（比过关快一点）；先暂停，免得黑下去的那 0.3 秒里马灯又挨打。SceneFade 切场时会解除暂停
	get_tree().paused = true
	SceneFade.go(get_tree(), get_tree().current_scene.scene_file_path, 0.3, 0.1, 0.45)


func _draw() -> void:
	if not _debug:
		return
	for r in D.SOLIDS:
		draw_rect(r, Color(0.3, 1.0, 0.5, 0.2))
		draw_rect(r, Color(0.3, 1.0, 0.5, 0.8), false)
	for p in D.PLATFORMS:
		draw_line(Vector2(p[0], p[2]), Vector2(p[1], p[2]), Color(1.0, 0.8, 0.3), 1.0)
	for sh in D.SHAFTS:
		draw_rect(sh, Color(0.4, 0.7, 1.0, 0.8), false)
	draw_rect(_exit, Color(1.0, 0.9, 0.4, 0.9), false)
