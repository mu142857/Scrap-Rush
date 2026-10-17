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
const CLIMB_SPEED := 110.0
## 镜头中心多远以内的屏幕灯才开
const LIGHT_RANGE := 420.0
const TINT_LIGHT := {
	"color": Color(1.0, 0.82, 0.6),
	"bw": Color(0.75, 0.78, 0.86),
	"green": Color(0.5, 0.9, 0.56),
	"amber": Color(1.0, 0.68, 0.32),
}
## 这几块屏幕不摆怪：起点那块、玄关、家乡
const NO_ENEMY := ["entry", "hometown"]
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
## 平时摆的小怪和它所在的屏幕：{node, rect}（rect 到地面为止）
var _screen_mobs: Array = []
var _wake_t := 0.0
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
	Run.start_level()
	Run.crystal_broken.connect(_on_crystal_broken)

	var bg := ParallaxScene.new()
	bg.layers = [
		[preload("res://art/levels/l3_far.png"), 0.6, Color(0.78, 0.78, 0.86)],
		[preload("res://art/levels/l3_mid.png"), 1.0, Color.WHITE],
	]
	bg.bounds = D.BOUNDS
	add_child(bg)
	# 屏幕层：自己发光，不吃压暗
	var screens := Sprite2D.new()
	screens.texture = preload("res://art/levels/l3_screens.png")
	screens.centered = false
	screens.z_index = -17
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	screens.material = unshaded
	add_child(screens)
	var near := Sprite2D.new()
	near.texture = preload("res://art/levels/l3_near.png")
	near.centered = false
	near.z_index = -16
	add_child(near)

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

	_place_enemies()
	_place_hints()

	var first: Player = null
	for i in Run.players.size():
		var p := Player.new()
		p.input_prefix = Run.players[i]["input"]
		p.skin = Run.players[i]["skin"]
		p.position = D.START + Vector2(i * 14, 0)
		add_child(p)
		if first == null:
			first = p

	var crystal := Crystal.new()
	crystal.position = D.START
	add_child(crystal)
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

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tour="):
			var tour: Node = load("res://scripts/debug/tour.gd").new()
			tour.set("out_dir", arg.trim_prefix("--tour="))
			add_child(tour)
		if arg.begins_with("--l3scene="):
			var sc: Node = load("res://scripts/debug/l3_scene_check.gd").new()
			sc.set("scene_name", arg.trim_prefix("--l3scene="))
			add_child(sc)
		if arg == "--l3enc":
			add_child(load("res://scripts/debug/l3_enc_check.gd").new())
		if arg == "--l3check":
			add_child(load("res://scripts/debug/l3_check.gd").new())
		if arg.begins_with("--autotest="):
			var t: Node = load("res://scripts/debug/autotest.gd").new()
			t.set("out_dir", arg.trim_prefix("--autotest="))
			add_child(t)


func _add_box(r: Rect2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
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


## 摆怪（2026-10-17 作者试玩后改）：
## - 精英怪只在关门的遭遇战里打：大屏幕、地上没洞，两边闸门锁住，打完才开；每种场景最多一场，一共 8 场左右。
##   前一波是这个场景的两只小怪，后一波精英怪单独出来（不再带小怪），留出走位的地方。
## - 平时的小怪少放：宽不到 SMALL_SCREEN 的屏幕不放（当喘口气的走廊），中等的 1 只，宽的 2 只；
##   射击怪只放进宽屏幕；离左右入口至少 ENTRY_CLEAR，人一进来不会贴脸。
## - 只有主角所在那块屏幕里的怪会动，别的屏幕里的怪定住（像暂停的电视画面），见 _wake_mobs。
const SMALL_SCREEN := 160.0
const WIDE_SCREEN := 240.0
const ENTRY_CLEAR := 36.0


func _place_enemies() -> void:
	L3Mob.arena = D.BOUNDS
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var fought := {}
	for i in D.SCREENS.size():
		var s: Dictionary = D.SCREENS[i]
		if i == 0 or s["name"] in NO_ENEMY:
			continue
		var rect: Array = s["rect"]
		var w: float = rect[2] - rect[0]
		var fy: float = s["floor"]
		var tint: String = s["tint"]
		var smalls := L3Mob.smalls(s["name"])
		if smalls.is_empty():
			continue
		var elite := L3Mob.elite(s["name"])
		var bag := _shuffled(smalls, rng)
		if w >= 180.0 and not _has_hole(s) and elite != "" and not fought.has(s["name"]):
			fought[s["name"]] = true
			var enc := Encounter.new()
			enc.left = rect[0] + 10
			enc.right = rect[2] - 10
			enc.ceil_y = rect[1]
			enc.floor_left = fy
			enc.floor_right = fy
			enc.waves = [[_not_shooter(bag, 0), _not_shooter(bag, 1)], [elite]]
			enc.spawn_hook = _spawn_in_encounter.bind(tint, rect[1], rect[0] + 10, rect[2] - 10)
			add_child(enc)
			continue
		if w < SMALL_SCREEN:
			continue
		var n := 2 if w >= WIDE_SCREEN else 1
		var left: float = rect[0] + ENTRY_CLEAR
		var right: float = rect[2] - ENTRY_CLEAR
		for k in n:
			var kind: String = bag[k % bag.size()] if w >= WIDE_SCREEN else _not_shooter(bag, k)
			var x: float = left + (right - left) * (k + 1) / (n + 1) + rng.randf_range(-8, 8)
			var e := _make_mob(kind, tint)
			e.position = Vector2(x, fy - (30.0 if e is Moth else 0.0))
			add_child(e)
			_screen_mobs.append({"node": e, "rect": Rect2(rect[0], rect[1], w, fy - rect[1] + 2)})
	_wake_mobs()


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
	var e := L3Mob.make(kind, tint)
	# 脚底离天花板至少一个身高，不然高的精英怪一生出来上半截就卡在外壳里
	e.position = Vector2(x, ceil_y + cfg["frame_size"].y + 4.0)
	add_child(e)
	return e


func _place_hints() -> void:
	var jump_key := Controls.key_name(Run.players[0]["input"], "jump")
	var first: Array = D.SCREENS[0]["rect"]
	var signs := [
		{"zone": Rect2(0, D.START.y - 80, first[0] + 60, 80), "at": Vector2(first[0] + 20, D.START.y - 40),
		 "text": "Walk into the screens", "arrow": "right"},
		{"zone": Rect2(D.END.x - 60, D.END.y - 60, 120, 60), "at": D.END + Vector2(0, -36), "text": "Home", "arrow": "down"},
	]
	if D.SHAFTS.size() > 0:
		var sh: Rect2 = D.SHAFTS[0]
		signs.append({"zone": Rect2(sh.position.x - 40, sh.end.y - 60, sh.size.x + 80, 60),
			"at": Vector2(sh.get_center().x, sh.end.y - 34), "text": "Hold %s on the cable to climb" % jump_key, "arrow": "up"})
	for h in signs:
		var sign := HintSign.new()
		sign.zone = h["zone"]
		sign.position = h["at"]
		sign.text = h["text"]
		sign.arrow = h["arrow"]
		add_child(sign)


func _process(delta: float) -> void:
	_wake_t -= delta
	if _wake_t <= 0.0:
		_wake_t = 0.15
		_wake_mobs()
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	for l in _lights:
		l.enabled = l.position.distance_to(c) < LIGHT_RANGE


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

		# 洞里的电线：按住跳往上爬（关卡的 _physics_process 先于玩家跑，玩家那边再加重力也还是往上）
		if Input.is_action_pressed(p.input_prefix + "_jump"):
			for sh in D.SHAFTS:
				if sh.has_point(p.global_position):
					p.velocity.y = -CLIMB_SPEED
					break


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				_retry()
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


func _leave() -> void:
	_leaving = true
	hud.show_banner("HOME")
	await get_tree().create_timer(1.6, true, false, true).timeout
	Game.flash(Color.BLACK, 1.0, 0.8)
	await get_tree().create_timer(0.4, true, false, true).timeout
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _retry() -> void:
	if _retrying:
		return
	_retrying = true
	Engine.time_scale = 1.0
	Run.retry_level()
	get_tree().reload_current_scene()


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
