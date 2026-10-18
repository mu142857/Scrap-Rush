extends Node2D
## 手感测试关：直接用 Oscar 的第一关场景当背景（按图层分成 5 层做视差，见 ParallaxScene），
## 碰撞先手摆几个矩形，对准图上的传送带、走道、地面和 Boss 台。
## Oscar 出了"平台层"以后，改成按平台层自动生成碰撞。
## F3 显示碰撞框，R 从本关开头重来。

## 从远到近：[图片, 跟镜头的比例, 颜色]。near 是能站的东西，必须是 1
const SCENE_LAYERS := [
	[preload("res://art/levels/scene1_far.png"), 0.55, Color(0.72, 0.72, 0.8)],
	[preload("res://art/levels/scene1_beams.png"), 0.7, Color(0.8, 0.8, 0.86)],
	[preload("res://art/levels/scene1_machines.png"), 0.8, Color(0.88, 0.88, 0.92)],
	[preload("res://art/levels/scene1_truss.png"), 0.9, Color(0.95, 0.95, 0.97)],
	# near 拆成三层，桥和吊车（Bridge 节点）夹在中间，前后关系和原图一样
	[preload("res://art/levels/scene1_near_a.png"), 1.0, Color.WHITE],
	[preload("res://art/levels/scene1_near_b.png"), 1.0, Color.WHITE],
	[preload("res://art/levels/scene1_near_c.png"), 1.0, Color.WHITE],
]
const BOUNDS := Rect2(0, 0, 1006, 426)
## 场景整体压暗，光只来自马灯、荧光条和闪光
const DARKNESS := Color(0.36, 0.35, 0.41)

## 碰撞对着 scene1.png（5 层叠起来的原图）逐像素量过（按行求平均亮度，台面那一行最亮）。
## 小台阶（≤8 像素）做成斜坡，走路不会卡；高的箱子、柜子是直墙，要跳。
const SOLIDS: Array[Rect2] = [
	Rect2(0, -16, 1006, 16),       # 天花板
	Rect2(-16, -200, 16, 800),     # 左墙
	Rect2(1006, -200, 16, 800),    # 右墙
	Rect2(45, 118, 866, 18),       # 上层：传送带，到 911 为止
	# 上层左端是一座桁架立柱（美术上从顶一直到传送带下面）。原来是空的：开局往左一走，直接穿过
	# 中层左端的缺口掉到底层，上层、中层四场遭遇战全跳过（夜间打磨关卡检查抓到的）
	Rect2(0, 0, 45, 136),          # 上层左端的桁架立柱
	Rect2(48, 208, 958, 14),       # 中层：桁架走道，左边 0~48 留缺口往下跳
	# 原来的"Boss 台"现在是会伸缩的桥（Bridge 节点管桥面碰撞）。桥下面从桥面到地面一直是实心：
	# 桥伸出来以后这块被桥和两根柱子围住，人掉不进去；桥伸出来之前，钢琴那场的闸门挡着，人也过不来
	Rect2(449, 343, 359, 71),      # 桥下面，走不进去
	Rect2(422, 354, 27, 60),       # Boss 台左边的柱子（台阶）
	Rect2(808, 354, 25, 60),       # Boss 台右边的柱子
]
## 不是长方形的地面：沿台面从左到右描点，最后两点封到下面
const POLYS := [
	# 上层右端的灰色铁台，比传送带高 5 像素，接一小段坡；右边 989~1006 留缺口往下跳
	[Vector2(905, 118), Vector2(911, 113), Vector2(989, 113), Vector2(989, 136), Vector2(905, 136)],
	# 底层地面：左边铁轨 406，小坑 414，机器 407，柜子 396，机器 410/405，再往右都是 414
	[
		Vector2(-16, 406), Vector2(86, 406), Vector2(95, 414), Vector2(99, 414),
		Vector2(107, 407), Vector2(195, 407), Vector2(195, 396), Vector2(237, 396),
		Vector2(237, 410), Vector2(290, 410), Vector2(296, 405), Vector2(320, 405),
		Vector2(326, 410), Vector2(342, 410), Vector2(347, 414), Vector2(1022, 414),
		Vector2(1022, 440), Vector2(-16, 440),
	],
]
const SPAWN := Vector2(90, 118)
## 遭遇战之间的走廊里留两只会复活的爬虫，其余的怪都在遭遇战里
const CRAWLERS: Array[Vector2] = [Vector2(525, 118), Vector2(555, 208)]
## 遭遇战（Encounter）：left/right 是两扇闸门的 x，ceil 是天花板，floor_l/floor_r 是两扇闸门脚下的地面。
## 沿路线依次是：上层两场 → 中层两场（往左走）→ 底层一场 → 最底层桥上的最后一场。
## 每场最后一波出一个精英怪（布谷鸟钟、收银机、缝纫机、吸尘器、自动钢琴），带一两只小怪；
## 桥上那场先打四波小怪，最后蒸汽压路机单独出场（第一关最强的精英怪）。
const ENCOUNTERS := [
	{"left": 230, "right": 450, "ceil": 0, "floor_l": 118, "floor_r": 118, "hazards": [],
	 "waves": [["crawler", "crawler"], ["shaver", "crawler"], ["cuckoo", "flea"]]},
	{"left": 600, "right": 860, "ceil": 0, "floor_l": 118, "floor_r": 118, "hazards": [["kettle", Vector2(730, 118)]],
	 "waves": [["moth", "moth"], ["flea", "flea", "crawler"], ["register", "shaver", "moth"]]},
	{"left": 640, "right": 880, "ceil": 136, "floor_l": 208, "floor_r": 208, "hazards": [["kettle", Vector2(760, 208)]],
	 "waves": [["crawler", "shaver", "crawler"], ["moth", "moth", "flea"], ["sewing", "shaver", "flea"]]},
	{"left": 230, "right": 470, "ceil": 136, "floor_l": 208, "floor_r": 208, "hazards": [],
	 "waves": [["flea", "flea"], ["moth", "moth", "moth"], ["vacuum", "shaver", "crawler"]]},
	# 钢琴那场打完，桥从右边柱子伸出来（Oscar 原稿里桥和吊车的动画），之后一直伸着
	{"left": 110, "right": 390, "ceil": 222, "floor_l": 407, "floor_r": 414, "hazards": [["kettle", Vector2(308, 405)]],
	 "opens_bridge": true,
	 "waves": [["crawler", "crawler", "shaver"], ["moth", "flea", "moth"], ["piano", "shaver", "flea"]]},
	# 桥那场：在伸出来的桥面上打，最后压路机。打完往右走过柱子、跳下去就是出口
	{"left": 455, "right": 802, "ceil": 222, "floor_l": 343, "floor_r": 343, "hazards": [],
	 "waves": [["crawler", "crawler", "flea"], ["moth", "moth", "shaver"], ["flea", "flea", "shaver", "shaver"],
		["moth", "moth", "shaver", "shaver", "crawler"], ["roller"]]},
]
## 关卡出口：桥上最后一场打完、从右边柱子跳下来，走到底层最右端，就进第一关 Boss 房。
## 玩家、水晶血量、零件都在 Run 里，Boss 房自己会 Run.start_level()。
const EXIT := Rect2(966, 360, 40, 60)
const BOSS_SCENE := "res://scenes/boss1.tscn"
## 路线提示：有玩家走进 zone 就在 at 处亮出一块提示牌。
## 路线：上层往右 → 右端跳下 → 中层往左 → 左端跳下 → 底层往右打 Boss
const HINTS := [
	{"zone": Rect2(45, 60, 200, 64), "at": Vector2(150, 84), "text": "Go right", "arrow": "right"},
	{"zone": Rect2(820, 60, 186, 64), "at": Vector2(997, 84), "text": "Drop down here", "arrow": "down"},
	{"zone": Rect2(820, 140, 186, 74), "at": Vector2(900, 176), "text": "Go left", "arrow": "left"},
	{"zone": Rect2(0, 140, 200, 74), "at": Vector2(24, 176), "text": "Drop down here", "arrow": "down"},
	{"zone": Rect2(0, 330, 180, 90), "at": Vector2(120, 372), "text": "Go right", "arrow": "right"},
	{"zone": Rect2(340, 300, 82, 120), "at": Vector2(400, 322), "text": "Hold {jump} in the air to fly", "arrow": "up"},
	{"zone": Rect2(833, 330, 173, 90), "at": Vector2(980, 384), "text": "Boss ahead", "arrow": "right"},
]

var hud: Hud
var _debug := false
var _retrying := false
var _leaving := false
var _bridge: Bridge


func _ready() -> void:
	# 调试：Godot --path . -- --players=2 直接开双人（键盘左右两半），3、4 人接手柄
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
	bg.bounds = BOUNDS
	add_child(bg)
	_bridge = Bridge.new()
	add_child(_bridge)
	_bridge.set_state(Bridge.FRAMES - 1)

	var dark := CanvasModulate.new()
	dark.color = DARKNESS
	add_child(dark)

	for r in SOLIDS:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)
		add_child(body)
	for poly in POLYS:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var shape := CollisionPolygon2D.new()
		shape.polygon = PackedVector2Array(poly)
		body.add_child(shape)
		add_child(body)

	var jump_key := Controls.key_name(Run.players[0]["input"], "jump")
	for h in HINTS:
		var sign := HintSign.new()
		sign.zone = h["zone"]
		sign.position = h["at"]
		sign.text = tr(h["text"]).format({"jump": jump_key})
		sign.arrow = h["arrow"]
		add_child(sign)

	for pos in CRAWLERS:
		var c := Crawler.new()
		c.position = pos
		add_child(c)

	for d in ENCOUNTERS:
		var enc := Encounter.new()
		enc.left = minf(d["left"], d["right"])
		enc.right = maxf(d["left"], d["right"])
		enc.ceil_y = d["ceil"]
		enc.floor_left = d["floor_l"] if d["left"] < d["right"] else d["floor_r"]
		enc.floor_right = d["floor_r"] if d["left"] < d["right"] else d["floor_l"]
		enc.waves = d["waves"]
		enc.hazards = d["hazards"]
		if d.get("opens_bridge", false):
			enc.finished.connect(_open_bridge.bind(enc))
		add_child(enc)

	var first: Player = null
	for i in Run.players.size():
		var p := Player.new()
		p.input_prefix = Run.players[i]["input"]
		p.skin = Run.players[i]["skin"]
		p.position = SPAWN + Vector2(i * 14, 0)
		add_child(p)
		if first == null:
			first = p

	var crystal := Crystal.new()
	crystal.position = SPAWN
	add_child(crystal)
	crystal.pick_up(first, true)

	var cam := GameCamera.new()
	cam.bounds = BOUNDS
	add_child(cam)
	cam.snap()

	hud = Hud.new()
	add_child(hud)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fx="):
			var fx: Node = load("res://scripts/debug/fx_shots.gd").new()
			fx.set("out_dir", arg.trim_prefix("--fx="))
			add_child(fx)
		if arg == "--arc":
			add_child(load("res://scripts/debug/arc.gd").new())
		if arg == "--probe":
			add_child(load("res://scripts/debug/probe.gd").new())
		if arg.begins_with("--tour="):
			var tour: Node = load("res://scripts/debug/tour.gd").new()
			tour.set("out_dir", arg.trim_prefix("--tour="))
			add_child(tour)
		if arg.begins_with("--autotest="):
			var t: Node = load("res://scripts/debug/autotest.gd").new()
			t.set("out_dir", arg.trim_prefix("--autotest="))
			add_child(t)


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


func _physics_process(_delta: float) -> void:
	if _leaving or _retrying:
		return
	for p in get_tree().get_nodes_in_group("player"):
		if EXIT.has_point((p as Node2D).global_position):
			_leave()
			return


## 钢琴那场打完：歇一下，桥从右边柱子伸出来，接上左边的柱子，人才能上桥打最后一场
func _open_bridge(enc: Node) -> void:
	# 从存档点重来、钢琴那场早就打完了（一波怪都没出过）：桥直接是伸出来的样子，不再放 3.5 秒的动画。
	# 不然桥还在慢慢伸的时候，人能走上桥下面那块还看不见的实心（夜间打磨地形压力测试抓到的）
	if is_instance_valid(enc) and enc.get("_wave") == -1:
		if is_instance_valid(_bridge):
			_bridge.set_state(0.0)
		return
	await get_tree().create_timer(0.8, false).timeout
	if is_instance_valid(_bridge):
		Game.sfx("whistle", -2.0, 0.9)
		_bridge.extend()


func _leave() -> void:
	_leaving = true
	# 全局统一的切场：淡到全黑 → 切 → 在 Boss 房里淡开（SceneFade 自己会恢复 time_scale 和暂停）
	SceneFade.go(get_tree(), BOSS_SCENE)


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
	for r in SOLIDS:
		draw_rect(r, Color(0.3, 1.0, 0.5, 0.25))
		draw_rect(r, Color(0.3, 1.0, 0.5, 0.9), false)
	for poly in POLYS:
		var outline := PackedVector2Array(poly)
		draw_colored_polygon(outline, Color(0.3, 1.0, 0.5, 0.25))
		outline.append(outline[0])
		draw_polyline(outline, Color(0.3, 1.0, 0.5, 0.9))
	for h in HINTS:
		draw_rect(h["zone"], Color(1.0, 0.8, 0.3, 0.6), false)
	draw_rect(EXIT, Color(0.4, 0.7, 1.0, 0.9), false)
