extends Node2D
## 第二关「交换台 → 胶片天桥 → 放映厅」（策划案第四节"第二关定案"）。
## 地图、碰撞、遭遇战场子都在 Level2Data（草图/第二关/level2_map.py 生成）。
## - 前半交换局：四间悬在大厅里的机房，用玻璃气动管连起来（10-17 作者定，换掉和第一关一样的三层折返）。
##   接线员大厅（E1）→ 继电器机房（E2）→ 电话簿仓库（E3）→ 片库，片库右边直接接天桥。
##   每间房打完，墙上管口的灯从红变绿，走进管口就被吸进去，坐着小胶囊沿管子飞到下一间房喷出来。
##   每场旁边的墙上挂一部老电话，每一波来之前先响铃。
## - 胶片天桥自动卷轴：镜头缩到 1 倍，每秒往右卷 70 像素；左边是被烧穿的胶片，碰到扣水晶 10、往前弹，不会死。
##   怪不断从前面的画框里走出来。两个换卷点：右上角闪两下圆点，镜头停下，打一场精英怪，打完接着卷。
## - 放映厅：从放映窗下面钻出去，沿台阶座位往下，乐池打最后一场（E4），舞台上的小门是出口 → 商店 → 第三关。
## 单独打开：Godot --path . scenes/level2.tscn
## F3 显示碰撞框，R 从本关开头重来。

const D := preload("res://scripts/levels/level2_data.gd")
const DARKNESS := Color(0.36, 0.35, 0.41)
const NEXT_SCENE := "res://scenes/level3.tscn"

## 从远到近：[图片, 跟镜头的比例, 颜色]
const SCENE_LAYERS := [
	[preload("res://art/levels/level2_far.png"), 0.55, Color(0.72, 0.72, 0.8)],
	[preload("res://art/levels/level2_mid.png"), 0.75, Color(0.8, 0.8, 0.86)],
	[preload("res://art/levels/level2_back.png"), 1.0, Color.WHITE],
	[preload("res://art/levels/level2_props.png"), 1.0, Color.WHITE],
	[preload("res://art/levels/level2_solid.png"), 1.0, Color.WHITE],
	[preload("res://art/levels/level2_near.png"), 1.0, Color.WHITE],
]
## 胶片自己发光，不吃场景压暗
const FILM_TEX := preload("res://art/levels/level2_film.png")

## 每场遭遇战的波次（和 D.ARENAS 一一对应）。第二关"声音"有自己的一套怪（10-17 作者定）：
## 小怪：电线蛇 wire_snake、保险丝甲虫 fuse、手摇电话 phone、拾荒者 scavenger、幻灯机 slide、胶片盘 reel；
## 精英：总机台 switchboard（交换局）、留声机 gramophone（继电器机房、乐池）、放映机 projector（天桥换卷）。
## 留一点第一关的扑灯蛾，配合放灯的玩法。
const WAVES := [
	# E1 接线员大厅：先认识电线蛇、保险丝甲虫、手摇电话
	[["wire_snake", "fuse"], ["phone", "fuse", "fuse"], ["switchboard", "wire_snake"]],
	# E2 继电器机房：拾荒者第一次出来偷灯，最后留声机
	[["scavenger", "fuse"], ["wire_snake", "wire_snake", "phone"], ["slide", "fuse", "moth"], ["gramophone", "fuse"]],
	# E3 电话簿仓库：总机台再来一次，带幻灯机
	[["fuse", "fuse", "scavenger"], ["phone", "slide", "wire_snake"], ["switchboard", "slide"]],
	# E4 放映厅乐池：最后一场，留声机
	[["slide", "slide", "moth"], ["reel", "reel", "scavenger"], ["phone", "fuse", "fuse", "slide"], ["gramophone", "reel"]],
]
## 天桥上两个换卷点的精英怪战：都是放映机，第二场小怪更多
const REEL_WAVES := [
	[["reel", "reel"], ["slide", "reel", "moth"], ["projector"]],
	[["reel", "reel", "slide"], ["scavenger", "reel", "slide"], ["projector", "reel"]],
]
## 天桥上一直从画框里走出来的小怪：胶片天桥上主要是胶片盘
const WANDERERS := ["reel", "reel", "moth", "slide", "scavenger", "fuse"]
const WANDER_GAP := 2.4
const WANDER_MAX := 4

const SCROLL_SPEED := 70.0
## 走上胶片多远开始卷；开卷前停顿一下（"胶片开始转"），镜头先挪到起始位置
const BRIDGE_TRIGGER := D.A_X1 + 16.0
const ROLL_DELAY := 1.4
const ROLL_START_X := D.A_X1 + 180.0
## 卷到镜头中心在这里为止（右边已经看到放映室）；人走进放映室就把镜头还回去
const ROLL_END_X := D.B_X0 - 120.0
const FILM_CENTER_Y := (D.FILM_TOP + D.FILM_BOT) * 0.5 - 6.0
## 烧穿边：画面左边这么宽是火，碰到扣 BURN_DAMAGE
const BURN_W := 20.0
const BURN_DAMAGE := 10.0
## 换卷提示提前多少像素开始闪
const CUE_LEAD := 150.0

## 气动管胶囊的速度（像素/秒）
const TUBE_SPEED := 460.0

const HINTS := [
	{"zone": Rect2(40, 470, 160, 70), "at": Vector2(120, 506), "text": "Go right", "arrow": "right"},
	{"zone": Rect2(330, 470, 90, 70), "at": Vector2(400, 500), "text": "Clear the room, then step into the tube", "arrow": "right"},
	{"zone": Rect2(800, 370, 100, 60), "at": Vector2(880, 392), "text": "Into the tube", "arrow": "right"},
	{"zone": Rect2(330, 180, 110, 70), "at": Vector2(380, 214), "text": "Go left", "arrow": "left"},
	{"zone": Rect2(52, 180, 100, 70), "at": Vector2(74, 214), "text": "Into the tube", "arrow": "left"},
	{"zone": Rect2(600, 230, 200, 70), "at": Vector2(700, 262), "text": "Go right", "arrow": "right"},
	{"zone": Rect2(900, 220, 100, 80), "at": Vector2(980, 262), "text": "The film is burning. Keep moving!", "arrow": "right"},
	{"zone": Rect2(2980, 220, 140, 80), "at": Vector2(3090, 280), "text": "Duck under", "arrow": "right"},
]

enum { PRE, START, ROLL, REEL, HOLD, POST }

var hud: Hud
var _debug := false
var _retrying := false
var _leaving := false
var _cam: Level2Camera
var _crystal: Crystal
var _state := PRE
var _t := 0.0
var _reel_i := 0
var _cued := -1
var _wander_t := 0.0
var _wanderers: Array[Node2D] = []
var _burn: BurnEdge
var _encounters: Array[Encounter] = []
var _tube_lamps: Array[TubeLamp] = []
var _transit := false


func _ready() -> void:
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
	bg.layers = SCENE_LAYERS
	bg.bounds = D.BOUNDS
	add_child(bg)
	var film := Sprite2D.new()
	film.texture = FILM_TEX
	film.centered = false
	film.z_index = -14
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	film.material = unshaded
	add_child(film)

	var dark := CanvasModulate.new()
	dark.color = DARKNESS
	add_child(dark)
	_add_lights()

	for r in D.SOLIDS:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)
		add_child(body)
	# 关卡左右两头和天桥上方的空气墙（天桥上面是空的，跳出画面也回不来，所以封顶）
	for r in [Rect2(-16, -16, 16, D.BOUNDS.size.y + 32), Rect2(D.BOUNDS.size.x, -16, 16, D.BOUNDS.size.y + 32),
			Rect2(D.A_X1, -16, D.B_X0 - D.A_X1, 16)]:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)
		add_child(body)

	var jump_key := Controls.key_name(Run.players[0]["input"], "jump")
	for h in HINTS:
		var sign := HintSign.new()
		sign.zone = h["zone"]
		sign.position = h["at"]
		sign.text = (h["text"] as String).format({"jump": jump_key})
		sign.arrow = h["arrow"]
		add_child(sign)

	for i in D.ARENAS.size():
		var a: Dictionary = D.ARENAS[i]
		var enc := PhoneEncounter.new()
		enc.left = a["left"]
		enc.right = a["right"]
		enc.ceil_y = a["ceil"]
		enc.floor_left = a["floor_l"]
		enc.floor_right = a["floor_r"]
		enc.waves = WAVES[i]
		enc.phone = D.PHONES[i]
		add_child(enc)
		_encounters.append(enc)
	for t in D.TUBES:
		var lamp := TubeLamp.new()
		var m: Rect2 = t["mouth"]
		lamp.position = Vector2(m.get_center().x, m.position.y - 5)
		add_child(lamp)
		_tube_lamps.append(lamp)

	var first: Player = null
	for i in Run.players.size():
		var p := Player.new()
		p.input_prefix = Run.players[i]["input"]
		p.skin = Run.players[i]["skin"]
		p.position = D.SPAWN + Vector2(i * 14, 0)
		add_child(p)
		if first == null:
			first = p

	_crystal = Crystal.new()
	_crystal.position = D.SPAWN
	add_child(_crystal)
	_crystal.pick_up(first, true)

	_cam = Level2Camera.new()
	_cam.bounds = D.BOUNDS
	add_child(_cam)
	_cam.snap()

	_burn = BurnEdge.new()
	_burn.visible = false
	add_child(_burn)

	hud = Hud.new()
	add_child(hud)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--l2tour="):
			var tour: Node = load("res://scripts/debug/l2_tour.gd").new()
			tour.set("out_dir", arg.trim_prefix("--l2tour="))
			add_child(tour)
		if arg.begins_with("--l2shot="):
			# --l2shot=<场景名>:<截图目录>，单拍一张（见 l2_tour.gd 的 SHOTS）
			var parts := arg.trim_prefix("--l2shot=").split(":", true, 1)
			var tour: Node = load("res://scripts/debug/l2_tour.gd").new()
			tour.set("shot", parts[0])
			tour.set("out_dir", parts[1])
			add_child(tour)


func _add_lights() -> void:
	# [位置, 颜色, 亮度, 半径（像素）]
	var lights := [
		[Vector2(2998, 255), Color(1.0, 0.86, 0.62), 0.9, 90.0],     # 放映机镜头
		[Vector2(3108, 238), Color(1.0, 0.9, 0.7), 0.7, 70.0],       # 放映窗
		[Vector2(3518, 297), Color(1.0, 0.84, 0.6), 0.8, 190.0],     # 银幕
	]
	for p in D.PHONES:
		lights.append([p + Vector2(0, -4), Color(1.0, 0.7, 0.36), 0.45, 46.0])
	for l in lights:
		var light := PointLight2D.new()
		light.texture = Game.light_texture()
		light.position = l[0]
		light.color = l[1]
		light.energy = l[2]
		light.texture_scale = l[3] / 32.0
		add_child(light)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				_retry()
			KEY_F3:
				_debug = not _debug
				queue_redraw()


func _physics_process(delta: float) -> void:
	if _leaving or _retrying:
		return
	var players := _players()
	if players.is_empty():
		return
	for p in players:
		if D.EXIT.has_point(p.global_position):
			_leave()
			return
		if p.global_position.y > D.BOUNDS.end.y + 24.0:
			_fell(p)
	_t += delta
	match _state:
		PRE:
			_check_tubes(players)
			if _lead_x(players) > BRIDGE_TRIGGER:
				_begin_bridge()
		START:
			_cam.scroll_x = lerpf(_cam.scroll_x, ROLL_START_X, 1.0 - exp(-3.0 * delta))
			if _t >= ROLL_DELAY:
				_state = ROLL
				_burn.visible = true
				Game.sfx("whistle", -4.0, 0.7)
		ROLL:
			_roll(delta)
		HOLD:
			var all_in := true
			for p in players:
				if p.global_position.x < D.B_X0 + 8.0:
					all_in = false
			if all_in:
				_end_bridge()
	if _state in [ROLL, REEL, HOLD]:
		_burn_edge(players)
	if _state in [ROLL, REEL, HOLD]:
		var right := _cam.view_rect().end.x - 8.0
		for p in players:
			if p.global_position.x > right:
				p.global_position.x = right
				p.velocity.x = minf(p.velocity.x, 0.0)
	if _debug:
		queue_redraw()


## 气动管：这间房的遭遇战打完，管口灯变绿；有人走进管口，所有人一起被吸进去
func _check_tubes(players: Array[Player]) -> void:
	if _transit:
		return
	for i in D.TUBES.size():
		var t: Dictionary = D.TUBES[i]
		var open := _encounters[t["needs"]].cleared
		_tube_lamps[i].open = open
		if not open:
			continue
		for p in players:
			if (t["mouth"] as Rect2).grow(2.0).has_point(p.global_position + Vector2(0, -4)):
				_ride(t)
				return


func _ride(t: Dictionary) -> void:
	_transit = true
	var players := _players()
	# 放在地上的马灯也一起吸进去，到了以后在第一个人手里
	if is_instance_valid(_crystal) and _crystal.carrier == null:
		_crystal.pick_up(players[0], true)
	for p in players:
		p.velocity = Vector2.ZERO
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(_crystal):
		_crystal.visible = false
		_crystal.process_mode = Node.PROCESS_MODE_DISABLED
	Game.sfx("suction", -4.0, 1.2)
	Game.sparks(self, (t["mouth"] as Rect2).get_center(), Color8(220, 220, 230), 8, 60.0)
	var capsule := Capsule.new()
	var path: Array = [(t["mouth"] as Rect2).get_center()]
	path.append_array(t["path"])
	path.append(t["out"])
	capsule.position = path[0]
	add_child(capsule)
	_cam.chase = capsule
	for k in range(1, path.size()):
		var a: Vector2 = path[k - 1]
		var b: Vector2 = path[k]
		var tw := create_tween()
		tw.tween_property(capsule, "position", b, a.distance_to(b) / TUBE_SPEED)
		await tw.finished
		if not is_instance_valid(capsule):
			return
		Game.sfx("clang", -18.0, 1.6, 0.1)
	_cam.chase = null
	capsule.queue_free()
	var out: Vector2 = t["out"]
	var vel: Vector2 = t["vel"]
	for i in players.size():
		var p := players[i]
		if not is_instance_valid(p):
			continue
		p.global_position = out + Vector2(-signf(vel.x) * i * 10.0, 0)
		p.velocity = vel
		p.visible = true
		p.process_mode = Node.PROCESS_MODE_INHERIT
		p.reset_physics_interpolation()
	if is_instance_valid(_crystal):
		_crystal.visible = true
		_crystal.process_mode = Node.PROCESS_MODE_INHERIT
		_crystal.reset_physics_interpolation()
	Game.sfx("suction", -8.0, 0.8)
	Game.sparks(self, out + Vector2(0, -6), Color8(220, 220, 230), 10, 80.0)
	Game.add_shake(2.0)
	_transit = false


func _roll(delta: float) -> void:
	_cam.scroll_x += SCROLL_SPEED * delta
	# 换卷：提前闪提示，到点停下打精英怪
	if _reel_i < D.REEL_CHANGES.size():
		var rc: float = D.REEL_CHANGES[_reel_i]
		if _cued < _reel_i and _cam.scroll_x >= rc - CUE_LEAD:
			_cued = _reel_i
			var cue := CueDots.new()
			add_child(cue)
		if _cam.scroll_x >= rc:
			_cam.scroll_x = rc
			_start_reel(_reel_i)
			return
	if _cam.scroll_x >= ROLL_END_X:
		_cam.scroll_x = ROLL_END_X
		_state = HOLD
		return
	_wander(delta)


func _begin_bridge() -> void:
	_state = START
	_t = 0.0
	_cam.scroll_x = _cam.global_position.x
	_cam.scroll_y = FILM_CENTER_Y
	_cam.scrolling = true
	_cam.set_wide(true)
	Game.sfx("rivets", -6.0, 0.6)
	Game.add_shake(2.0)
	hud.show_banner("THE FILM IS ROLLING")


func _end_bridge() -> void:
	_state = POST
	_burn.visible = false
	_cam.scrolling = false
	_cam.forget_ground()
	_cam.set_wide(false)
	for w in _wanderers:
		if is_instance_valid(w):
			w.queue_free()
	_wanderers.clear()


## 换卷：镜头停住，整屏就是场子，两边闸门落下，打完接着卷
func _start_reel(i: int) -> void:
	_state = REEL
	var v := _cam.view_rect()
	var enc := Encounter.new()
	enc.left = v.position.x + BURN_W + 6.0
	enc.right = v.end.x - 10.0
	enc.ceil_y = D.FILM_TOP + 14.0
	enc.floor_left = D.BRIDGE_Y
	enc.floor_right = D.BRIDGE_Y
	enc.waves = REEL_WAVES[i]
	# 人可能贴着画面右边，在场子的"进场"范围外面，这场就不会开打：先把人收进场子里
	for p in _players():
		p.global_position.x = clampf(p.global_position.x, enc.left + 32.0, enc.right - 32.0)
	enc.finished.connect(func():
		_reel_i += 1
		_state = ROLL)
	add_child(enc)


## 怪从前面的画框里走出来：画框上沿冒一串火花，怪落到胶片上
func _wander(delta: float) -> void:
	_wander_t += delta
	for w in _wanderers.duplicate():
		if not is_instance_valid(w) or w.get("dead"):
			_wanderers.erase(w)
	if _wander_t < WANDER_GAP or _wanderers.size() >= WANDER_MAX:
		return
	_wander_t = 0.0
	var v := _cam.view_rect()
	var x := v.end.x - randf_range(40.0, 150.0)
	var kind: String = WANDERERS[randi() % WANDERERS.size()]
	var path: String = Encounter.TYPES[kind]
	var e: Node2D = (load(path) as GDScript).new()
	e.set("respawn_time", 0.0)
	e.position = Vector2(x, D.FILM_TOP + 22.0)
	add_child(e)
	_wanderers.append(e)
	Game.sparks(self, Vector2(x, D.FILM_TOP + 14.0), Color8(255, 214, 150), 6, 50.0, Vector2.DOWN)
	Game.sfx("scrap", -16.0, 1.5, 0.1)


## 烧穿边：画面左边一条火。人碰到扣水晶、往前弹；放在地上的马灯被追上也扣血，自动回到人手里；
## 落在后面的怪直接烧掉
func _burn_edge(players: Array[Player]) -> void:
	var v := _cam.view_rect()
	var edge := v.position.x + BURN_W
	_burn.position = Vector2(v.position.x, 0)
	for p in players:
		if p.global_position.x < edge:
			# 提着灯：hurt 里已经把伤害转给马灯；空手：hurt 只会晕一下，马灯另外扣
			if p.hurt(Vector2(edge - 30.0, p.global_position.y), BURN_DAMAGE) and p.crystal == null:
				Run.damage_crystal(BURN_DAMAGE)
			p.global_position.x = edge + 30.0
			p.reset_physics_interpolation()
			p.velocity = Vector2(150.0, -140.0)
			Game.sparks(self, Vector2(edge, p.global_position.y - 6.0), Color8(255, 170, 70), 10, 80.0)
	if is_instance_valid(_crystal) and _crystal.carrier == null and _crystal.global_position.x < edge + 6.0:
		_crystal.take_hit(Vector2(edge - 30.0, _crystal.global_position.y), BURN_DAMAGE)
		var p := players[0]
		_crystal.global_position = p.global_position
		_crystal.reset_physics_interpolation()
		_crystal.pick_up(p)
	for w in _wanderers.duplicate():
		if is_instance_valid(w) and w.global_position.x < edge - 12.0:
			_wanderers.erase(w)
			w.queue_free()


## 掉出关卡：扣水晶，放回附近能站的地方（天桥上从画框里被"放"回来）
func _fell(p: Player) -> void:
	if p.crystal:
		p.crystal.take_carried_hit(BURN_DAMAGE)
	else:
		Run.damage_crystal(BURN_DAMAGE)
	var x := p.global_position.x
	if _state in [START, ROLL, REEL, HOLD]:
		p.global_position = Vector2(_cam.view_rect().position.x + 90.0, D.FILM_TOP + 30.0)
	elif x < D.A_X1:
		p.global_position = D.SPAWN
	else:
		p.global_position = Vector2(clampf(x, D.B_X0 + 20.0, D.B_X0 + 200.0), D.BRIDGE_Y - 4.0)
	p.reset_physics_interpolation()
	_cam.forget_ground()
	p.velocity = Vector2.ZERO
	Game.flash(Color(1, 0.9, 0.7), 0.4, 0.5)


func _lead_x(players: Array[Player]) -> float:
	for p in players:
		if p.crystal:
			return p.global_position.x
	return players[0].global_position.x


func _players() -> Array[Player]:
	var out: Array[Player] = []
	for n in get_tree().get_nodes_in_group("player"):
		if n is Player:
			out.append(n)
	return out


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
	hud.show_banner("PICTURE HOUSE CLEARED")
	Game.flash(Color.BLACK, 1.0, 0.6)
	await get_tree().create_timer(0.6, true, false, true).timeout
	Engine.time_scale = 1.0
	get_tree().paused = false
	# 先打总机（boss2），打完它才进商店、去第三关（boss2_room.gd 的 next_shop = NEXT_SCENE）
	get_tree().change_scene_to_file("res://scenes/boss2.tscn")


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
		draw_rect(r, Color(0.3, 1.0, 0.5, 0.25))
		draw_rect(r, Color(0.3, 1.0, 0.5, 0.9), false)
	for h in HINTS:
		draw_rect(h["zone"], Color(1.0, 0.8, 0.3, 0.6), false)
	draw_rect(D.EXIT, Color(0.4, 0.7, 1.0, 0.9), false)
	if _state in [ROLL, REEL, HOLD]:
		var v := _cam.view_rect()
		draw_line(Vector2(v.position.x + BURN_W, v.position.y), Vector2(v.position.x + BURN_W, v.end.y), Color.RED)


## 管口上面的小灯：红 = 这间房还没打完，绿 = 可以走进去了
class TubeLamp extends Node2D:
	var open := false:
		set(v):
			if v != open:
				open = v
				queue_redraw()
				if v:
					Game.sfx("ding", -12.0, 1.4)
				if _light:
					_light.color = Color(0.4, 1.0, 0.5) if v else Color(1.0, 0.3, 0.2)
	var _light: PointLight2D

	func _ready() -> void:
		z_index = 3
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m
		_light = PointLight2D.new()
		_light.texture = Game.light_texture()
		_light.color = Color(1.0, 0.3, 0.2)
		_light.energy = 0.5
		_light.texture_scale = 20.0 / 32.0
		add_child(_light)

	func _draw() -> void:
		var col := Color8(120, 240, 140) if open else Color8(240, 80, 60)
		draw_rect(Rect2(-2, -2, 4, 3), Color8(70, 58, 30))
		draw_rect(Rect2(-1, -1, 2, 2), col)


## 气动管里的胶囊：一个小黄铜筒，前后亮一点
class Capsule extends Node2D:
	func _ready() -> void:
		z_index = 3
		var l := PointLight2D.new()
		l.texture = Game.light_texture()
		l.color = Color(1.0, 0.85, 0.6)
		l.energy = 0.8
		l.texture_scale = 40.0 / 32.0
		add_child(l)

	func _draw() -> void:
		draw_rect(Rect2(-3, -3, 6, 6), Color8(134, 117, 63))
		draw_rect(Rect2(-3, -3, 6, 1), Color8(170, 150, 92))
		draw_rect(Rect2(-1, -1, 2, 2), Color8(250, 230, 180))


## 交换台的遭遇战：每一波来之前，场子旁边墙上的电话先响铃（多给 0.6 秒反应）
class PhoneEncounter extends Encounter:
	var phone := Vector2.ZERO

	func _spawn_wave(i: int) -> void:
		super._spawn_wave(i)
		for q in _queue:
			q["t"] -= 0.6
		var ring := RingFx.new()
		ring.position = phone
		get_parent().add_child(ring)


## 电话响铃：铃两边冒弧线，叮叮叮三声
class RingFx extends Node2D:
	const LIFE := 1.0
	var _t := 0.0
	var _rung := 0

	func _ready() -> void:
		z_index = 5
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m

	func _process(delta: float) -> void:
		_t += delta
		while _rung < 3 and _t >= _rung * 0.18:
			Game.sfx("ding", -10.0, 1.9 if _rung % 2 == 0 else 1.7)
			_rung += 1
		if _t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - _t / LIFE
		var col := Color(1.0, 0.82, 0.45, a)
		var shake := 1.0 if int(_t * 30.0) % 2 == 0 else -1.0
		for k in 2:
			var r := 8.0 + k * 4.0 + _t * 6.0
			draw_arc(Vector2(shake, -11), r, PI * 1.15, PI * 1.45, 4, col, 1.0)
			draw_arc(Vector2(shake, -11), r, PI * 1.55, PI * 1.85, 4, col, 1.0)


## 烧穿边：画面左边一条往上窜的火（白 → 黄 → 橙 → 焦黑），只画在胶片那一段上下
class BurnEdge extends Node2D:
	const COLS := [Color8(255, 244, 214), Color8(250, 206, 100), Color8(226, 120, 54), Color8(110, 46, 32)]
	var _t := 0.0

	func _ready() -> void:
		z_index = 4
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m
		var l := PointLight2D.new()
		l.texture = Game.light_texture()
		l.color = Color(1.0, 0.6, 0.3)
		l.energy = 0.9
		l.texture_scale = 70.0 / 32.0
		l.position = Vector2(10, (D.FILM_TOP + D.FILM_BOT) * 0.5)
		add_child(l)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var y0 := int(D.FILM_TOP) - 30
		var y1 := int(D.FILM_BOT) + 30
		for y in range(y0, y1, 2):
			var on_film := y >= D.FILM_TOP and y < D.FILM_BOT
			var base := 20.0 if on_film else 8.0
			var w := base + sin(y * 0.21 + _t * 9.0) * 3.0 + sin(y * 0.07 - _t * 5.0) * 4.0
			var widths := [w - 12.0, w - 6.0, w - 2.0, w]
			for k in range(3, -1, -1):
				if widths[k] > 0.0:
					draw_rect(Rect2(0, y, roundf(widths[k]), 2), COLS[k])
		# 往右飘的火星
		for i in 10:
			var s := fmod(_t * 0.8 + i * 0.37, 1.0)
			var x := 18.0 + s * 40.0
			var y := y0 + fmod(i * 53.0 + _t * 20.0, float(y1 - y0)) - s * 20.0
			draw_rect(Rect2(roundf(x), roundf(y), 1, 1), COLS[1 + i % 2])


## 换卷提示：老电影换卷前，画面右上角闪两下的小圆点
class CueDots extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		z_index = 30
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m
		Game.sfx("ding", -8.0, 0.8)

	func _process(delta: float) -> void:
		_t += delta
		var cam := get_viewport().get_camera_2d()
		if cam:
			var half := get_viewport_rect().size * 0.5 / cam.zoom
			global_position = cam.get_screen_center_position() + Vector2(half.x - 34.0, -half.y + 26.0)
		if _t > 1.6:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		# 两次闪：0~0.35 秒、0.8~1.15 秒
		if (_t < 0.35) or (_t > 0.8 and _t < 1.15):
			draw_circle(Vector2.ZERO, 7.0, Color(0.98, 0.94, 0.86))
			draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 20, Color(0.2, 0.16, 0.12), 1.0)
