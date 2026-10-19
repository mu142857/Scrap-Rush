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
## 开场的气动管冲刺（10-17 作者选的开场方案 B）。第一次进第二关先去那里，冲完再回来砸穿天花板落地。
## 在第二关里重来（R、马灯碎了）从存档点重来，不再重播管道。
const TUBE_SCENE := "res://scenes/level2_tube.tscn"
## 胶囊落进接线员大厅的位置（E1 场子正中）
const LANDING := Vector2(250, 540)
## 管道冲完时由 TubeRun 设成 true，这一关 _ready 用掉
static var tube_landing := false

## 从远到近：[层名, 跟镜头的比例, 颜色]。每层是 level2_map.py 切好的 2048 宽竖条（网页版贴图不能太宽），
## 这里拼起来显示，跟镜头的算法和 ParallaxScene 一样（竖直方向视差减半）
const SCENE_LAYERS := [
	["far", 0.55, Color(0.72, 0.72, 0.8)],
	["mid", 0.75, Color(0.8, 0.8, 0.86)],
	# 墙、摆设、能站的东西、前景四层都是 1.0 倍速，合成一张（level2_map.py 生成），省显存
	["main", 1.0, Color.WHITE],
]
## 胶片自己发光，不吃场景压暗。图只有天桥那一条（1840×90），放在 (A_X1, FILM_TOP)
const FILM_TEX := preload("res://art/levels/level2_film.png")
## 胶片卷动时的放映机咔嗒声（草图/第二关/level2_sfx.py 合成的 2 秒循环）
const PROJECTOR_LOOP := preload("res://sfx/level2_projector_loop.wav")

## 每场遭遇战的波次（和 D.ARENAS 一一对应）。第二关"声音"有自己的一套怪（10-17 作者定）：
## 小怪：电线蛇 wire_snake、保险丝甲虫 fuse、手摇电话 phone、拾荒者 scavenger、幻灯机 slide、胶片盘 reel；
## 精英：总机台 switchboard（交换局）、留声机 gramophone（继电器机房、乐池）、放映机 projector（天桥换卷）。
## 留一点第一关的扑灯蛾，配合放灯的玩法。
## 10-17 作者："第二关的怪物和第一关太像了，多加点披着袍子的人形怪"：加了三种披袍人形小怪（RobedEncounter.ROBED），
## 场面以人形为主、机器为辅：交换局主要是接线员 hooded（近战甩电话线），后面掺引座员 usher（远程手电）；
## 放映厅和天桥主要是观众 audience（成群坐着，走近就一起站起来扑）和引座员。
## 10-17 作者："第二关是不是精英怪又重复"：三个精英各只出一次——总机台在 E1、放映机在第二场换卷、留声机在最后的乐池。
## 10-18 作者："我以为你要加新的，结果你删除了旧的"：另外三场各配一个新精英——
## E3 总接线长 chief_operator、第一场换卷剪辑师 film_editor（放映机会话做的），E2 守夜巨人 watchman（布谷鸟钟会话做的有生命的砸地大块头）。
const WAVES := [
	# E1 接线员大厅：先认识接线员，配电线蛇、保险丝甲虫；最后总机台
	[["hooded", "fuse"], ["hooded", "hooded", "wire_snake"], ["switchboard", "hooded"]],
	# E2 继电器机房：拾荒者第一次出来偷灯、手摇电话叫人；最后守夜巨人 watchman（10-18 有生命的砸地大块头），小怪减一点免得挤
	[["scavenger"], ["hooded", "phone"], ["usher", "hooded"],
		["watchman", "hooded"]],
	# E3 电话簿仓库：远近夹击——引座员站远处照，接线员和拾荒者贴身；最后总接线长（10-18 新精英），小怪减一点免得挤
	[["hooded", "hooded", "fuse"], ["usher", "usher", "wire_snake"], ["scavenger", "hooded", "phone"],
		["chief_operator", "hooded"]],
	# E4 放映厅乐池：一排观众坐着，引座员打手电；最后留声机
	[["audience", "audience", "audience"], ["usher", "usher", "reel"], ["audience", "audience", "audience", "slide"], ["gramophone", "usher"]],
]
## 天桥上两个换卷点：第一场最后是剪辑师（10-18 新精英），第二场是放映机
const REEL_WAVES := [
	[["audience", "audience", "reel"], ["usher", "reel", "audience"], ["film_editor", "audience"]],
	[["audience", "audience", "audience"], ["usher", "usher", "reel"], ["projector", "audience"]],
]
## 天桥上一直从画框里走出来的小怪：观众和胶片盘为主
const WANDERERS := ["audience", "reel", "usher", "audience", "reel", "moth"]
const WANDER_GAP := 2.4
const WANDER_MAX := 4
## 天桥小怪：冒火花预警多久才落下来、离人至少多远才出
const WANDER_WARN := 0.5
const WANDER_CLEAR := 60.0
## 换卷战打完，停多久再接着卷
const RESUME_WAIT := 1.2

const SCROLL_SPEED := 70.0
## 开卷先慢后快（10-18 新玩家体验报告第 7 条：第一次玩不知道左边的火会追上来）：
## 从 SCROLL_SPEED 的 ROLL_EASE_FROM 倍加到全速，第一次开卷用 ROLL_EASE_FIRST 秒，换卷打完再开卷用 ROLL_EASE_AGAIN 秒
const ROLL_EASE_FROM := 0.35
const ROLL_EASE_FIRST := 2.5
const ROLL_EASE_AGAIN := 1.0
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
var _wander_queue: Array = []
var _resume_wait := 0.0
## 这一次开卷已经卷了几秒、加速要用几秒（见 ROLL_EASE_*）
var _roll_t := 0.0
var _roll_ease := ROLL_EASE_FIRST
var _burn: BurnEdge
var _encounters: Array[Encounter] = []
var _tube_lamps: Array[TubeLamp] = []
var _transit := false
var _film: Sprite2D
## 关卡里摆好的灯（电话、顶灯、管口、奖励、放映机、银幕……）：只开镜头附近的（第三关同样的办法，灯多了手机卡）
var _static_lights: Array[PointLight2D] = []
var _light_t := 0.0
## 拼好的背景层：[节点, 跟镜头的比例]
var _bg_layers: Array = []
var _clatter: AudioStreamPlayer
var _flicker_t := 0.0


func _ready() -> void:
	# 第一次进来（不是重来、不是刚从管道落下来）：先去坐管道。调试参数可以跳过
	var landing := tube_landing
	tube_landing = false
	if not landing and not Run.get("_resuming") and not _skip_tube():
		_leaving = true
		get_tree().change_scene_to_file.call_deferred(TUBE_SCENE)
		return
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

	for i in SCENE_LAYERS.size():
		var l: Array = SCENE_LAYERS[i]
		_tiled_layer(l[0], l[1], l[2], -20 + i)
	# 背景跟镜头：等镜头这一帧挪完再跟（ParallaxScene 也是这样），不然背景慢一帧、会抖
	process_priority = 100
	var film := Sprite2D.new()
	film.texture = FILM_TEX
	film.centered = false
	film.position = Vector2(D.A_X1, D.FILM_TOP)
	film.z_index = -14
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	film.material = unshaded
	add_child(film)
	_film = film
	_add_bridge_dust()
	_clatter = AudioStreamPlayer.new()
	_clatter.stream = TubeRun.looped(PROJECTOR_LOOP)
	_clatter.volume_db = -60.0
	add_child(_clatter)

	var dark := CanvasModulate.new()
	dark.color = DARKNESS
	add_child(dark)
	_add_lights()
	# 场景里自己会动的东西和几个能互动的小玩意（闪灯、吊灯、银幕、胶片上的影子、油灯、电话），见 level2_life.gd
	var life: Node2D = load("res://scripts/levels/level2_life.gd").new()
	life.set("level", self)
	add_child(life)

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

	# 机房里的单向平台（从下面能跳上去，按下键跳下来）和藏在高处的零件、灯油（10-18 夜间打磨）
	for r in D.PLATFORMS:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		shape.one_way_collision = true
		body.add_child(shape)
		add_child(body)
	for pk in D.PICKUPS:
		var item := Pickup.new()
		item.kind = pk["kind"]
		item.position = pk["pos"]
		add_child(item)

	var jump_key := Controls.key_name(Run.players[0]["input"], "jump")
	for h in HINTS:
		var sign := HintSign.new()
		# 区域下边正好是地面：人站在地上 y 也正好等于它，Rect2.has_point 不算下边线，牌子就不出来。往下多放 4 像素
		sign.zone = (h["zone"] as Rect2).grow_individual(0, 0, 0, 4)
		sign.position = h["at"]
		sign.text = tr(h["text"]).format({"jump": jump_key})
		sign.arrow = h["arrow"]
		sign.level_width = D.BOUNDS.size.x
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
	# 乐池那场打完，舞台小门上亮一块"出口"牌子（打之前不亮，免得打着架看见出口却出不去）
	_encounters.back().finished.connect(func():
		var sign := HintSign.new()
		sign.zone = Rect2(D.EXIT.position.x - 180.0, D.EXIT.position.y - 60.0, 220.0, 120.0)
		sign.position = Vector2(D.EXIT.get_center().x, D.EXIT.position.y - 8.0)
		sign.text = tr("Exit")
		sign.arrow = "down"
		sign.level_width = D.BOUNDS.size.x
		add_child(sign))
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
	# 从天桥后面的存档点重来：天桥已经走完，人在放映室
	if Run.is_cleared("bridge"):
		_state = POST
	_collect_static_lights()

	if landing or OS.get_cmdline_user_args().has("--landing"):
		_crash_landing()

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
	# 第二关的开场动画在气动管里播，这里热不到：进场时把材质都画一遍，网页版先编好着色器（scripts/fx/material_warmer.gd）
	MaterialWarmer.warm.call_deferred(self)


## 一层背景：TILES 条竖条按 TILE_W 排开，放在一个节点下面整体跟镜头走
func _tiled_layer(layer: String, scale: float, color: Color, z: int) -> void:
	var root := Node2D.new()
	root.z_index = z
	root.modulate = color
	for i in D.TILES:
		var sp := Sprite2D.new()
		sp.texture = load("res://art/levels/level2_%s_%d.png" % [layer, i])
		sp.centered = false
		sp.position = Vector2(i * D.TILE_W, 0)
		root.add_child(sp)
	add_child(root)
	_bg_layers.append([root, scale])


## 视差：镜头在关卡正中时各层对齐；远层"落后"（和 ParallaxScene._follow 一样，不取整，免得远景一格一格跳）
func _follow_bg() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var off := cam.get_screen_center_position() - D.BOUNDS.get_center()
	for l in _bg_layers:
		var lag := 1.0 - float(l[1])
		(l[0] as Node2D).position = Vector2(off.x * lag, off.y * lag * 0.5)


## 天桥上空漂着的灰尘：被放映的光照亮的一颗颗小亮点，慢慢往上飘、来回晃，像老电影院光束里的浮尘。
## 在胶片后面、背景前面；自己发一点光（不吃压暗）。整段天桥一共 120 颗，很省（10-18 夜间打磨）
func _add_bridge_dust() -> void:
	var p := CPUParticles2D.new()
	p.amount = 120
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2((D.B_X0 - D.A_X1) * 0.5, 160.0)
	p.position = Vector2((D.A_X1 + D.B_X0) * 0.5, (D.FILM_TOP + D.FILM_BOT) * 0.5)
	p.direction = Vector2(0.3, -1.0)
	p.spread = 60.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector2(0, -1.5)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.6, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.9, 0.7, 0.8))
	ramp.add_point(0.75, Color(1.0, 0.86, 0.62, 0.6))
	ramp.set_color(1, Color(1.0, 0.8, 0.55, 0.0))
	p.color_ramp = ramp
	p.z_index = -17
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = m
	add_child(p)


## 收集关卡里摆好的灯：主角、马灯、怪、烧穿边、胶囊这些会动的东西自己带的灯不算
func _collect_static_lights() -> void:
	for n in find_children("*", "PointLight2D", true, false):
		var owner_node := n.get_parent()
		if owner_node == self or owner_node is Pickup or owner_node is TubeLamp:
			_static_lights.append(n)
	_cull_lights()


## 灯光的圈碰得到画面才开（按画面范围算，前半段机房上下挨得近，按距离算会把楼上楼下的灯都开着）
func _cull_lights() -> void:
	if _cam == null:
		return
	var view := _cam.view_rect().grow(16.0)
	for l in _static_lights:
		if is_instance_valid(l):
			var r := l.texture_scale * 32.0
			l.enabled = view.grow(r).has_point(l.global_position)


func _skip_tube() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg in ["--skip-tube", "--landing"] or arg.begins_with("--l2tour") or arg.begins_with("--l2shot"):
			return true
	return false


## 从管道冲下来：胶囊砸穿接线员大厅的天花板，落在场子正中，人从胶囊里滚出来，直接开打（E1 的场子判定马上就满足）
func _crash_landing() -> void:
	var players := _players()
	# 人先藏在天花板上面（不在场子里，免得胶囊还没落地就开打）
	for p in players:
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.global_position = Vector2(LANDING.x, 380)
	if is_instance_valid(_crystal):
		_crystal.visible = false
	_cam.global_position = Vector2(LANDING.x, 400)
	var hole := CeilingHole.new()
	hole.position = Vector2(LANDING.x, 434)
	add_child(hole)
	var cap := Capsule.new()
	cap.big = true
	cap.position = Vector2(LANDING.x, 400)
	add_child(cap)
	_cam.chase = cap
	# 第一场的第一波晚 1 秒（10-18 新玩家报告：刚出 40 秒的管道，手还在换道的节奏上，落地马上就被冲脸）
	(_encounters[0] as PhoneEncounter).first_delay = 1.0
	Game.add_shake(7.0)
	Game.sfx("crack", -2.0, 0.6)
	Game.sparks(self, Vector2(LANDING.x, 440), Color8(200, 190, 170), 16, 120.0, Vector2.DOWN)
	var tw := create_tween()
	tw.tween_property(cap, "position:y", LANDING.y - 4.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Game.sfx("boom", -3.0, 0.9)
	Game.add_shake(8.0)
	Game.flash(Color(1, 0.95, 0.85), 0.35, 0.3)
	Game.sparks(self, LANDING + Vector2(0, -4), Color8(255, 200, 120), 18, 140.0)
	Game.dust(self, LANDING, 6)
	_cam.chase = null
	cap.queue_free()
	var wreck := CapsuleWreck.new()
	wreck.position = LANDING
	add_child(wreck)
	for i in players.size():
		var p := players[i]
		if not is_instance_valid(p):
			continue
		p.global_position = LANDING + Vector2(i * 12 - 6, -2)
		p.velocity = Vector2((-1 if i % 2 == 0 else 1) * 60.0, -150.0)
		p.visible = true
		p.process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(_crystal):
		_crystal.visible = true
	# 镜头直接对准落地的人（10-18 新玩家报告）：原来跟着下落的胶囊慢半拍，落地那一下地面压在屏幕最底下，
	# 底部的操作说明正好叠在地面线上，要过半秒才滑回正常位置。落地有白闪和震屏，跳一下看不出来
	for p in players:
		if is_instance_valid(p):
			p.reset_physics_interpolation()
	_cam.teleported()


func _add_lights() -> void:
	# [位置, 颜色, 亮度, 半径（像素）]
	var lights := [
		[Vector2(2998, 255), Color(1.0, 0.86, 0.62), 0.9, 90.0],     # 放映机镜头
		[Vector2(3108, 238), Color(1.0, 0.9, 0.7), 0.7, 70.0],       # 放映窗
		[Vector2(3518, 297), Color(1.0, 0.84, 0.6), 0.8, 190.0],     # 银幕
		[Vector2(867, 235), Color(1.0, 0.86, 0.62), 0.55, 46.0],     # 片库墙上那块放着"家"的小幕布
	]
	for p in D.PHONES:
		lights.append([p + Vector2(0, -4), Color(1.0, 0.7, 0.36), 0.45, 46.0])
	# 每间机房的顶灯现在挂在 level2_life.gd 的吊灯上（会摇，灯光跟着走）
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
			KEY_F3:
				_debug = not _debug
				queue_redraw()


## 老放映机的闪烁：胶片那层的亮度每隔一小会儿随机轻轻跳一下（幅度很小，不影响看清东西）
func _process(delta: float) -> void:
	_follow_bg()
	_light_t -= delta
	if _light_t <= 0.0:
		_light_t = 0.2
		_cull_lights()
	if _film == null:
		return
	# 放映机声：胶片在卷（ROLL）时响，换卷停下、卷完、下了天桥就淡掉
	var rolling := _state == ROLL and _resume_wait <= 0.0
	var target_db := -16.0 if rolling else -60.0
	_clatter.volume_db = move_toward(_clatter.volume_db, target_db, delta * (30.0 if rolling else 20.0))
	if _clatter.volume_db > -59.0 and not _clatter.playing:
		_clatter.play()
	elif _clatter.volume_db <= -59.5 and _clatter.playing:
		_clatter.stop()
	_flicker_t -= delta
	if _flicker_t <= 0.0:
		_flicker_t = randf_range(0.06, 0.14)
		var k := 1.0 - randf() * 0.07
		if randf() < 0.04:
			k = 0.85                    # 偶尔暗一下，像片门里漏了一格
		_film.modulate = Color(k, k * 0.99, k * 0.97)


func _physics_process(delta: float) -> void:
	if _leaving or _retrying:
		return
	var players := _players()
	if players.is_empty():
		return
	for p in players:
		# 出口在乐池那场（最后一场）的场子里：打完才能走
		if D.EXIT.has_point(p.global_position) and _encounters.back().cleared:
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
				_roll_t = 0.0
				_roll_ease = ROLL_EASE_FIRST
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
	if _resume_wait > 0.0:
		_resume_wait -= delta
		return
	_roll_t += delta
	var ease := smoothstep(0.0, _roll_ease, _roll_t)
	_cam.scroll_x += SCROLL_SPEED * lerpf(ROLL_EASE_FROM, 1.0, ease) * delta
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
	hud.show_banner("THE FILM IS ROLLING", 1.0)


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
	_save_bridge_checkpoint()


## 天桥走完存一次档（10-18 夜间打磨）：后半段（放映室、乐池）死了从放映室重来，不用再看一遍两分多钟的卷轴。
## Run.save_checkpoint 不让存天桥以后的点（天桥中间不能重来），所以这里照它的格式自己写，多记一个 "bridge"，
## 重来时 _ready 看到它就直接是"天桥走完了"的状态
func _save_bridge_checkpoint() -> void:
	if Run.checkpoint.get("scene", "") != scene_file_path:
		Run.checkpoint = {"scene": scene_file_path, "cleared": []}
	Run.checkpoint["pos"] = Vector2(D.B_X0 + 40.0, D.BRIDGE_Y - 16.0)
	Run.checkpoint["hp"] = Run.crystal_hp
	# 场子里掉了还没捡的零件也算拿到（和 Run.save_checkpoint 一样）
	Run.checkpoint["parts"] = Run.parts + int(Run.get("_drops"))
	(Run.checkpoint["cleared"] as Array).append("bridge")
	Run.checkpoint_saved.emit()


## 换卷：镜头停住，整屏就是场子，两边闸门落下，打完接着卷
func _start_reel(i: int) -> void:
	_state = REEL
	var v := _cam.view_rect()
	var enc := RobedEncounter.new()
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
		_state = ROLL
		_roll_t = 0.0
		_roll_ease = ROLL_EASE_AGAIN
		# 打完先停一下再接着卷：人常站在场子左边，紧挨着烧穿边，马上卷就会被烧（10-18 夜间打磨）
		_resume_wait = RESUME_WAIT
		Game.sfx("rivets", -8.0, 0.7))
	add_child(enc)


## 怪从前面的画框里走出来：画框上沿冒一串火花，怪落到胶片上
func _wander(delta: float) -> void:
	_wander_t += delta
	for w in _wanderers.duplicate():
		if not is_instance_valid(w) or w.get("dead"):
			_wanderers.erase(w)
	# 预警到点的落下来
	for q in _wander_queue.duplicate():
		q["t"] -= delta
		if q["t"] <= 0.0:
			_wander_queue.erase(q)
			var e: Node2D = (load(q["path"]) as GDScript).new()
			e.set("respawn_time", 0.0)
			e.position = Vector2(q["x"], D.FILM_TOP + 22.0)
			add_child(e)
			_wanderers.append(e)
	if _wander_t < WANDER_GAP or _wanderers.size() + _wander_queue.size() >= WANDER_MAX:
		return
	# 落点：画面右边那一截，离每个人都至少 WANDER_CLEAR 像素（不会生在人头顶上）；找不到就这次不出
	var v := _cam.view_rect()
	var x := -1.0
	for _try in 6:
		var cx := v.end.x - randf_range(40.0, 150.0)
		var ok := true
		for p in _players():
			if absf(p.global_position.x - cx) < WANDER_CLEAR:
				ok = false
		if ok:
			x = cx
			break
	if x < 0.0:
		return
	_wander_t = 0.0
	var kind: String = WANDERERS[randi() % WANDERERS.size()]
	var path: String = RobedEncounter.ROBED.get(kind, Encounter.TYPES.get(kind, ""))
	_wander_queue.append({"x": x, "t": WANDER_WARN, "path": path})
	# 预警：画框上沿冒一串火花、响一声，WANDER_WARN 秒后怪才从画框里落下来
	Game.sparks(self, Vector2(x, D.FILM_TOP + 14.0), Color8(255, 214, 150), 8, 50.0, Vector2.DOWN)
	Game.sfx("scrap", -14.0, 1.5, 0.1)


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
	if _leaving or _retrying:
		return
	hud.show_banner("THE TAPE IS RUINED")
	Game.flash(Color(0.9, 0.9, 0.95), 0.5, 1.2)
	Game.add_shake(5.0)
	get_tree().paused = true
	await get_tree().create_timer(1.6, true, false, true).timeout
	get_tree().paused = false
	_retry()


## 出口：主角自己走进舞台小门（门里透出光），横幅出来，画面慢慢淡黑，切到 Boss2 房间再淡开。
## 黑幕挂在根节点上（SceneFade），切场景时不断；Boss2 那边主角从门口走进来、落闸、打名字卡，接得上。
func _leave() -> void:
	_leaving = true
	var door := Vector2(D.EXIT.get_center().x, D.EXIT.end.y - 4.0)
	for p in _players():
		p.velocity = Vector2.ZERO
		p.process_mode = Node.PROCESS_MODE_DISABLED
		var tw := create_tween()
		tw.tween_property(p, "global_position:x", door.x, 0.35)
		tw.tween_property(p, "modulate:a", 0.0, 0.3)
	if is_instance_valid(_crystal):
		var tc := create_tween()
		tc.tween_interval(0.35)
		tc.tween_property(_crystal, "modulate:a", 0.0, 0.3)
	Game.sfx("scrape", -10.0, 0.6)
	hud.show_banner("PICTURE HOUSE CLEARED", 1.2)
	await get_tree().create_timer(0.55, false).timeout
	Game.sfx("whistle", -8.0, 0.55)
	# 先打总机（boss2），打完它才进商店、去第三关（boss2_room.gd 的 next_shop = NEXT_SCENE）
	TubeRun.resume_d = 0.0
	SceneFade.go(get_tree(), "res://scenes/boss2.tscn", 0.9, 0.2, 0.8)


func _retry() -> void:
	# 已经走出出口、正在淡出去 Boss2：不许重来（质检会话 10-18 报：淡出时按 R 会把关卡重载、出口白走）
	if _retrying or _leaving:
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


## 关卡里摆好的小奖励（不会消失）：零件 part（商店的钱）、灯油 oil（马灯回 10 血）。
## 平时上下浮一点、自己发光（暗处也看得见），碰到就收。
class Pickup extends Area2D:
	const OIL_HEAL := 10.0
	var kind := "part"
	var _t := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(12, 14)
		cs.shape = r
		cs.position = Vector2(0, -6)
		add_child(cs)
		body_entered.connect(_on_body)
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m
		z_index = 5
		var l := PointLight2D.new()
		l.texture = Game.light_texture()
		l.color = Color(1.0, 0.8, 0.5)
		l.energy = 0.7
		l.texture_scale = 0.55
		l.position = Vector2(0, -6)
		add_child(l)
		_t = position.x * 0.01

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _on_body(b: Node) -> void:
		if not b is Player:
			return
		if kind == "oil":
			Run.heal_crystal(OIL_HEAL)
			Game.sfx("lantern_pick", -6.0, 1.3)
		else:
			Run.add_part()
			Game.sfx("lantern_pick", -4.0, 1.6)
		Game.sparks(get_parent(), global_position + Vector2(0, -6), Color(1.0, 0.85, 0.55), 10, 70.0)
		queue_free()

	func _draw() -> void:
		var o := Vector2(0, -7 + roundf(sin(_t * 3.0)))
		if kind == "oil":
			# 一小罐灯油：铁皮罐、黄铜盖，罐身上一道暖光
			draw_rect(Rect2(o + Vector2(-3, -3), Vector2(6, 7)), Color8(96, 88, 80))
			draw_rect(Rect2(o + Vector2(-3, -3), Vector2(1, 7)), Color8(140, 130, 118))
			draw_rect(Rect2(o + Vector2(-1, -5), Vector2(3, 2)), Color8(170, 150, 92))
			draw_rect(Rect2(o + Vector2(-2, 0), Vector2(4, 2)), Color8(255, 196, 92))
			return
		var dark := Color8(150, 112, 70)
		var lit := Color8(255, 211, 138)
		draw_rect(Rect2(o + Vector2(-2, -2), Vector2(5, 5)), lit)
		for d in [Vector2(-1, -4), Vector2(-1, 3), Vector2(-4, -1), Vector2(3, -1)]:
			draw_rect(Rect2(o + d, Vector2(3, 1) if absf(d.y) > 2 else Vector2(1, 3)), dark)
		draw_rect(Rect2(o, Vector2(1, 1)), dark)


## 天花板被胶囊砸出来的洞：一圈参差的黑口子，边上挂着几根断钢筋，往下掉几颗碎屑
class CeilingHole extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		z_index = 2

	func _process(delta: float) -> void:
		_t += delta
		if _t < 2.0:
			queue_redraw()

	func _draw() -> void:
		var edge := [-14, -11, -12, -8, -10, -6, -9, -12, -10, -13, -9, -11, -14]
		for i in edge.size():
			var x := -18 + i * 3
			draw_rect(Rect2(x, edge[i], 3, -edge[i] + 2 + (i % 3)), Color8(10, 9, 9))
		PixelDraw.line(self, Vector2(-16, 0), Vector2(-20, 7), Color8(110, 100, 90))
		PixelDraw.line(self, Vector2(12, 0), Vector2(17, 9), Color8(110, 100, 90))
		PixelDraw.line(self, Vector2(3, 1), Vector2(5, 6), Color8(90, 80, 70))
		if _t < 2.0:
			for k in 4:
				var y := fmod(_t * 90.0 + k * 23.0, 100.0)
				draw_rect(Rect2(-10 + k * 6, 4 + y, 1, 1), Color8(150, 140, 125))


## 落地以后的胶囊残骸：歪在地上的黄铜筒，舷窗碎了，冒一点烟
class CapsuleWreck extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		_t += delta
		if _t < 4.0:
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-9, -7, 18, 7), Color8(134, 117, 63))
		draw_rect(Rect2(-9, -7, 18, 1), Color8(170, 150, 92))
		draw_rect(Rect2(6, -6, 4, 6), Color8(100, 96, 90))
		draw_rect(Rect2(-3, -6, 6, 4), Color8(30, 28, 30))
		PixelDraw.line(self, Vector2(-2, -6), Vector2(2, -3), Color8(200, 200, 210))
		if _t < 4.0:
			for k in 3:
				var y := fmod(_t * 14.0 + k * 6.0, 18.0)
				draw_rect(Rect2(-2 + k * 3, -9 - y, 2, 2), Color(0.6, 0.58, 0.55, 0.5 * (1.0 - y / 18.0)))


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

	## 开场砸下来的那只是坐人的大胶囊（和管道冲刺里一样大），竖着往下掉
	var big := false

	func _draw() -> void:
		if big:
			draw_rect(Rect2(-5, -8, 10, 16), Color8(134, 117, 63))
			draw_rect(Rect2(-5, -8, 1, 16), Color8(170, 150, 92))
			draw_rect(Rect2(-4, 6, 8, 3), Color8(100, 96, 90))
			draw_rect(Rect2(-3, -3, 5, 7), Color8(30, 28, 30))
			draw_rect(Rect2(-1, -3, 2, 7), Color8(200, 40, 40))
			return
		draw_rect(Rect2(-3, -3, 6, 6), Color8(134, 117, 63))
		draw_rect(Rect2(-3, -3, 6, 1), Color8(170, 150, 92))
		draw_rect(Rect2(-1, -1, 2, 2), Color8(250, 230, 180))


## 交换台的遭遇战：每一波来之前，场子旁边墙上的电话先响铃（多给 0.6 秒反应）
## 认得第二关披袍人形小怪的遭遇战（encounter.gd 的种类表里没有它们，这里补上）
class RobedEncounter extends Encounter:
	const ROBED := {
		"hooded": "res://scripts/enemies/hooded_operator.gd",
		"usher": "res://scripts/enemies/usher.gd",
		"audience": "res://scripts/enemies/audience.gd",
		# 第二关新精英（放映机会话做的）。要按精英出场，得在 encounter.gd 的 ELITES 里也有名字（归三个主要bug修复会话）
		"chief_operator": "res://scripts/enemies/chief_operator.gd",
		"film_editor": "res://scripts/enemies/film_editor.gd",
		"watchman": "res://scripts/enemies/watchman.gd",
	}

	func _make(kind: String) -> Node2D:
		if ROBED.has(kind):
			var e: Node2D = (load(ROBED[kind]) as GDScript).new()
			e.set("respawn_time", 0.0)
			return e
		return super._make(kind)


class PhoneEncounter extends RobedEncounter:
	var phone := Vector2.ZERO
	## 开打以后第一波再多等几秒：从管道砸下来时用（落地演出放完、人站稳、手从换道切回来），只管第一波
	var first_delay := 0.0

	func _start() -> void:
		super._start()
		_gap -= first_delay
		first_delay = 0.0

	func _spawn_wave(i: int) -> void:
		super._spawn_wave(i)
		for q in _queue:
			q["t"] -= 0.6
		var ring := RingFx.new()
		ring.position = phone
		get_parent().add_child(ring)


## 电话响铃：铃两边冒弧线，电铃响一阵
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
		if _rung == 0:
			# 老电话的电铃（小锤快速敲铃，gen_sfx.py 的 bell），比原来"叮叮叮"更像电话在响
			Game.sfx("bell", -9.0, 1.0, 0.05)
			_rung = 1
		if _t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - _t / LIFE
		var col := Color(1.0, 0.82, 0.45, a)
		var shake := 1.0 if int(_t * 30.0) % 2 == 0 else -1.0
		for k in 2:
			var r := 8.0 + k * 4.0 + _t * 6.0
			PixelDraw.arc(self, Vector2(shake, -11), r, PI * 1.15, PI * 1.45, col)
			PixelDraw.arc(self, Vector2(shake, -11), r, PI * 1.55, PI * 1.85, col)


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
			PixelDraw.disc(self, Vector2.ZERO, 7.0, Color(0.98, 0.94, 0.86))
			PixelDraw.ring(self, Vector2.ZERO, 7.0, Color(0.2, 0.16, 0.12))
