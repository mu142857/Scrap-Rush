class_name TutorialLevel
extends Node2D
## 教学关「片头」（2026-10-18 作者："你的新的关卡我觉得可以作为一个教学关，很短就行"）。
## 五台老电视排成一排，每台是录像里的一个房间，一台教一样，做完这一样右边的门才开：
##   0 卧室   移动、跳、火箭靴（翻过一摞纸箱）
##   1 客厅   射击和蓄力：三台铁皮打靶机（站着的、举挡板只怕蓄满的、在轨道上滑的），不还手
##   2 阁楼   马灯就是命；放下马灯（跑得快、飞得久），一只发条铁皮蛾飞下来扑地上的灯，打掉它；
##            飞过雪花拍开关；回来捡起马灯，带着它过门
##   3 厨房   遭遇战关门（发条拳击手：头上冒 ! 再出拳，教看预警）；清场回血、存档点
##   4 儿童房 精英「大陪练」（冲撞、跳砸）；它掉一把武器，站上去按"下"换；然后出门
## 怪都是教学关专属的训练器材（10-19 作者："教学关还没有独特的敌人"，挑了方案 2「训练靶场」）：
## 脚本 tutorial_target / tutorial_moth / tutorial_boxer / tutorial_coach.gd，美术 草图/教学关/tutorial_mobs.py。
## 画面用第三关的画法画（草图/教学关/render_rooms.py → art/tutorial/room_<i>.png、tutorial_data.gd）。
## 提示框和新手提示（Coach）同一个样式，放在屏幕上方；教学关里 Coach 和底部按键条都藏起来，同一时间只有一段字。
## 马灯在教学关里碎不了：掉到 0 自动补满，提示一句。
## 走出最后一扇门：清掉这一局的状态（Run.reset_run），去 TutorialLevel.next_scene（默认选武器，新开一局的流程）。
## 测试：Godot --headless --fixed-fps 60 --path . scenes/tutorial.tscn -- --tauto（自动走完全程，见 _auto）

const D := preload("res://scripts/tutorial/tutorial_data.gd")
const PLATFORM_LAYER := 64
## 教学关的房间、纸箱、门不吃灯光（光照层只开第 3 位，马灯的灯照 1、2 位）：房间本来就亮，
## 马灯的光再加上去就过曝（10-19 作者："这个灯是不是过于亮了"）。马灯改成脚边一圈淡淡的暖光（TutorialGlow）
const NO_LIGHT_MASK := 4
## 马灯照人和怪的亮度上限（第三关的屏幕层本来就不吃光、外壳被压暗，所以那边不会过曝）
const LANTERN_ENERGY_CAP := 0.35
const DOOR_H := 40.0
const WARM := Color8(255, 211, 138)
## 阁楼：地上一大片雪花（碰到就被弹回左边，不扣血），对面地上一个开关。
## 实测（tutorial_autopilot --tauto 在阁楼里真飞）：跑起来在雪花边上起跳、一直按住跳，空手能飞约 235 像素，提着灯短得多。
## 雪花宽 GAP = 190：提灯飞不过去，放下灯飞得过去（自动驾驶两样都试一次）。拍了开关，雪花上面铺出一座桥，提着灯走回来过桥
const GAP := 190.0
const GAP_X := 150.0

## 教学走完去哪：新开一局时是选武器；从菜单里点"教学"进来的，走完回开始界面（菜单那边设）
static var next_scene := "res://scenes/weapon_select.tscn"

var hud: Hud
var step := 0
var _rooms: Array[Dictionary] = []
var _doors: Array[Node2D] = []
var _players: Array[Player] = []
var _crystal: Crystal
var _prompt: TutorialPrompt
var _sub := 0
var _t := 0.0
var _targets: Array[Node] = []
var _shield_said := false
var _moth: Node2D
var _boxer_said := false
var _switch_hit := false
var _switch: Node2D
var _static: TutorialStatic
var _enc: Encounter
var _pickup: Node2D
var _weapon_before := ""
var _leaving := false
var _moved := 0.0
var _jumped := false
var _start_x := 0.0
var _auto: Node


func _ready() -> void:
	if Run.players.is_empty():
		Run.players = [{"input": "solo", "skin": Run.SKINS[0]}]
	Run.start_level()
	Run.crystal_broken.connect(_on_crystal_broken)
	var w := D.SIZE.x
	for i in D.ROOMS.size():
		var r: Dictionary = D.ROOMS[i]
		var ox := i * w
		var g: Rect2 = r["glass"]
		_rooms.append({"ox": ox, "glass": Rect2(g.position + Vector2(ox, 0), g.size), "floor": float(r["floor"])})
		var sp := Sprite2D.new()
		sp.texture = load("res://art/tutorial/room_%d.png" % i)
		sp.centered = false
		sp.position = Vector2(ox, 0)
		sp.z_index = -20
		sp.light_mask = NO_LIGHT_MASK
		add_child(sp)
		_build_room(i)
	# 最后一扇门外面一小段地面，走出去就结束
	var end_x := D.ROOMS.size() * w
	_box(Rect2(end_x, 237, 120, 40), false)
	_box(Rect2(end_x + 110, 0, 16, 280), false)

	for i in Run.players.size():
		var p := Player.new()
		p.input_prefix = Run.players[i]["input"]
		p.skin = Run.players[i]["skin"]
		p.position = Vector2(40 + i * 14, 237)
		add_child(p)
		p.collision_mask |= PLATFORM_LAYER
		_players.append(p)
	_crystal = Crystal.new()
	_crystal.position = Vector2(40, 237)
	add_child(_crystal)
	_crystal.collision_mask |= PLATFORM_LAYER
	_crystal.pick_up(_players[0], true)
	var glow := TutorialGlow.new()
	glow.target = _crystal
	add_child(glow)
	_start_x = _players[0].position.x
	_weapon_before = str(_players[0].call("weapon")) if _players[0].has_method("weapon") else ""

	var cam := Level3Camera.new()
	cam.bounds = Rect2(0, 0, end_x + 126, D.SIZE.y)
	for r in _rooms:
		cam.screens.append({"rect": r["glass"], "floor": r["floor"]})
	add_child(cam)
	cam.snap()

	hud = Hud.new()
	add_child(hud)
	# 教学关自己出提示：新手提示框和底部按键条都藏起来，免得两段字叠在一起
	hud.show_hint = false
	var coach: Node = hud.get("_coach")
	if coach:
		coach.visible = false
		coach.process_mode = Node.PROCESS_MODE_DISABLED
	# 教学关不教情绪值（情绪也压在 10 以下）：右上角的情绪表藏起来，画面干净些
	for fx in hud.find_children("*", "EmotionFx", true, false):
		var g: Control = fx.get("_gauge")
		if g:
			g.visible = false
		var sl: Label = fx.get("_state_label")
		if sl:
			sl.visible = false
	# 大陪练的跳砸、冲撞标记按这个范围算（第三关开头会改回它自己的）
	L3Mob.arena = Rect2(0, 0, end_x + 126, D.SIZE.y + 40)
	_prompt = TutorialPrompt.new()
	add_child(_prompt)
	_say_step()

	for arg in OS.get_cmdline_user_args():
		if arg == "--tauto":
			_auto = load("res://scripts/debug/tutorial_autopilot.gd").new()
			add_child(_auto)


# ---------------------------------------------------------------- 房间

func _build_room(i: int) -> void:
	var ox: float = _rooms[i]["ox"]
	var w := D.SIZE.x
	var h := D.SIZE.y
	var fy: float = _rooms[i]["floor"]
	_box(Rect2(ox, 0, w, 8), false)                       # 外壳顶
	_box(Rect2(ox, fy, w, h - fy + 12), false)            # 地面（外壳底）
	var door_top := fy - DOOR_H
	# 左右外壳：中间那几台两边各挖一个门洞（和隔壁电视的门洞对齐）
	if i == 0:
		_box(Rect2(ox, 0, 8, fy), false)
	else:
		_box(Rect2(ox, 0, 8, door_top), false)
	_box(Rect2(ox + w - 8, 0, 8, door_top), false)
	# 门：两台电视的外壳之间一扇卷帘门，这一步做完才升起来
	var door := TutorialDoor.new()
	door.position = Vector2(ox + w - 8, door_top)
	door.size = Vector2(16, DOOR_H)
	add_child(door)
	_doors.append(door)
	# 屏幕里的家具：单向平台（阁楼的不要：免得提着灯踩家具跳到开关那边）
	if i != 2:
		for p in D.ROOMS[i]["plats"]:
			_box(Rect2(ox + p[0], p[2], p[1] - p[0], 4), true)
	_build_room_extras(i, ox, fy)


func _build_room_extras(i: int, ox: float, fy: float) -> void:
	match i:
		0:
			# 一摞纸箱挡在门前：跳上第一个，再在空中按住跳用火箭靴翻过最高那摞
			_crate(Rect2(ox + 250, fy - 22, 30, 22))
			_crate(Rect2(ox + 380, fy - 64, 34, 64))
		2:
			_static = TutorialStatic.new()
			_static.position = Vector2(ox + GAP_X, fy)
			_static.width = GAP
			add_child(_static)
			_switch = TutorialSwitch.new()
			_switch.position = Vector2(ox + GAP_X + GAP + 24, fy)
			add_child(_switch)


func _crate(r: Rect2) -> void:
	_box(r, false)
	var c := TutorialCrate.new()
	c.position = r.position
	c.size = r.size
	add_child(c)


func _box(r: Rect2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = PLATFORM_LAYER if one_way else 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)


func _process(_delta: float) -> void:
	# 马灯每个物理帧按血量重设亮度；这里在它之后把上限压住（没有物理帧的那一帧也不会越压越暗）
	if _crystal:
		var l: PointLight2D = _crystal.get("_light")
		if l:
			l.energy = minf(l.energy, LANTERN_ENERGY_CAP)


func _room_of(x: float) -> int:
	return clampi(int(x / D.SIZE.x), 0, D.ROOMS.size() - 1)


# ---------------------------------------------------------------- 每一步

func _physics_process(delta: float) -> void:
	if _leaving or _players.is_empty():
		return
	_t += delta
	# 教学关不让情绪涨上去（画面滤镜、怪变快都是正式关卡的事）
	Run.emotion = minf(Run.emotion, 10.0)
	var p := _players[0]
	match step:
		0:
			_moved = maxf(_moved, absf(p.global_position.x - _start_x))
			if not p.is_on_floor():
				_jumped = true
			if _sub == 0 and _moved > 60.0 and _jumped:
				_sub = 1
				_say(tr("In the air, hold %s: rocket boots") % _key("jump"))
			# 翻过最高那摞纸箱（站到它右边）：开门，进下一台
			if p.global_position.x > _rooms[0]["ox"] + 418:
				_open(0)
				_next()
		1:
			if _sub == 0 and _room_of(p.global_position.x) == 1:
				_sub = 1
				_spawn_targets()
			# 第一次打在挡板上（没蓄满）：说一句怎么打倒它
			if _sub == 1 and not _shield_said and _targets.any(func(e): return is_instance_valid(e) and e.get("blocked") and not e.get("dead")):
				_shield_said = true
				_say(_shield_text())
			if _sub == 1 and _targets.all(func(e): return not is_instance_valid(e) or e.get("dead")):
				_sub = 2
				_say(tr("Good... the door's open."), true)
				_open(1)
			if _sub == 2 and p.global_position.x > _rooms[1]["ox"] + D.SIZE.x - 4:
				_next()
		2:
			_tick_lantern_step(p)
		3:
			_tick_fight_step(p)
		4:
			_tick_elite_step(p)
	# 走出最后一扇门
	if step >= 5 and p.global_position.x > D.ROOMS.size() * D.SIZE.x + 20:
		_finish()


func _tick_lantern_step(p: Player) -> void:
	if _room_of(p.global_position.x) != 2:
		return
	_static_bounce()
	match _sub:
		0:
			_sub = 1
			_say(tr("Keep that lantern safe. If it breaks, your journey ends here."), false, true)
			_t = 0.0
		1:
			if _t > 3.5:
				_sub = 2
				_say(tr("Too far with the lantern. Press %s to put it down") % _key("crystal"))
		2:
			if p.crystal == null:
				_sub = 3
				_spawn_moth()
				_say(tr("A light left on the ground draws something hungry."), false, true)
		3:
			# 拍了开关也算过（先飞过去也不卡）
			if not is_instance_valid(_moth) or _moth.get("dead") or (_switch and _switch.get("hit")):
				_sub = 4
				_say(tr("Now fly over to the switch"))
		4:
			if _switch and _switch.get("hit"):
				_sub = 5
				_static.call("bridge")
				_say(tr("A bridge! Go back, press %s to pick up the lantern") % _key("crystal"))
		5:
			if p.crystal != null:
				_sub = 6
				_say(tr("Carry it over the bridge and out"), true)
				_open(2)
	# 灯没拿在手上，门不开（教"带着灯走"）
	if _sub == 6 and p.crystal == null and _doors[2].get("open"):
		_doors[2].call("set_open", false)
		_sub = 5
		_say(tr("Don't leave the lantern behind. Press %s.") % _key("crystal"))
	if _sub == 6 and p.global_position.x > _rooms[2]["ox"] + D.SIZE.x - 4:
		_next()


## 阁楼的雪花：人（或者地上的马灯）踩到就被弹回雪花左边，不扣血；桥铺好以后就没事了
func _static_bounce() -> void:
	if _static == null or _static.get("bridged"):
		return
	var x0 := _static.global_position.x
	var x1 := x0 + GAP
	var fy := _static.global_position.y
	for p in _players:
		if p.global_position.x > x0 and p.global_position.x < x1 and p.global_position.y > fy - 3.0 and p.is_on_floor():
			_static.call("zap", p.global_position.x)
			p.global_position = Vector2(x0 - 24.0, fy - 2.0)
			p.velocity = Vector2.ZERO
	if _crystal and _crystal.carrier == null:
		var c := _crystal.global_position
		if c.x > x0 and c.x < x1 and c.y > fy - 3.0:
			_crystal.global_position = Vector2(x0 - 36.0, fy - 2.0)
			_crystal.velocity = Vector2.ZERO


func _tick_fight_step(p: Player) -> void:
	match _sub:
		0:
			if _room_of(p.global_position.x) == 3:
				_sub = 1
				_enc = _make_encounter(3, [["boxer"], ["boxer", "boxer"]])
				_say(tr("Doors shut. Clear the fight to get through."))
		1:
			# 第一次有拳击手收拳：教看头上的 !
			if not _boxer_said:
				for e in get_tree().get_nodes_in_group("enemy"):
					if e is TutorialBoxer and e.is_winding():
						_boxer_said = true
						_say(tr("A red ! means it's about to strike. Jump over or back off"))
						break
			if _enc and _enc.cleared:
				_sub = 2
				_t = 0.0
				_say(tr("The lantern is one step closer to home. If it breaks, you restart here."), true)
				_open(3)
		2:
			if p.global_position.x > _rooms[3]["ox"] + D.SIZE.x - 4:
				_next()


func _tick_elite_step(p: Player) -> void:
	match _sub:
		0:
			if _room_of(p.global_position.x) == 4:
				_sub = 1
				_enc = _make_encounter(4, [["coach"]])
				_say(tr("Last one: an elite. Elites drop weapons"))
		1:
			# 精英出场卡在屏幕上方：出场时先把提示收起来
			var showing := true
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.has_method("in_intro") and e.call("in_intro"):
					showing = false
			_prompt.hold = not showing
			if _enc and _enc.cleared:
				_sub = 2
				_prompt.hold = false
				_drop_weapon(4)
				_say(tr("Stand on the weapon, press %s to swap") % _key("down"))
		2:
			var now := str(p.call("weapon")) if p.has_method("weapon") else ""
			if now != _weapon_before or not is_instance_valid(_pickup):
				_sub = 3
				_say(tr("That's all. Out you go."), true)
				_open(4)
				step = 5


func _next() -> void:
	step += 1
	_sub = 0
	_t = 0.0
	_say_step()


func _say_step() -> void:
	match step:
		0:
			_say(tr("%s  Move      %s  Jump") % [_key("move"), _key("jump")])
		1:
			_say(_shoot_text())
		_:
			_prompt.show_text("")


func _shield_text() -> String:
	if Upgrades.weapon == "flash":
		return tr("Shielded! Full charge, let it have it!")
	return tr("Shielded! Not enough, again!")


func _shoot_text() -> String:
	var k := _key("attack")
	match Upgrades.weapon:
		"rivet":
			return tr("Hold %s to fire nonstop") % k
		"hammer":
			return tr("Tap %s: steam blast all around you  (it needs to cool down)") % k
	return tr("Hold %s to charge,  release to shoot.  Watch the ring fill") % k


func _say(text: String, good := false, arrow := false) -> void:
	_prompt.show_text(text, good, arrow)


func _key(what: String) -> String:
	return Controls.key_name(Run.players[0]["input"], what)


func _open(i: int) -> void:
	if i < _doors.size():
		_doors[i].call("set_open", true)
	Game.sfx("ready", -6.0)


## 客厅三台铁皮打靶机：站着的、举挡板的、在轨道上滑的
func _spawn_targets() -> void:
	var r: Dictionary = _rooms[1]
	var ox: float = r["ox"]
	for k in 3:
		var e := TutorialTarget.new()
		e.kind = ["plain", "shield", "rail"][k]
		e.position = Vector2(ox + 190 + k * 80, r["floor"])
		if e.kind == "rail":
			e.rail = Vector2(ox + 330, ox + 400)
		add_child(e)
		_targets.append(e)


## 阁楼：放下马灯以后，一只发条铁皮蛾从屋顶左边飞下来扑地上的灯
func _spawn_moth() -> void:
	var r: Dictionary = _rooms[2]
	_moth = TutorialMoth.new()
	_moth.position = Vector2(r["ox"] + 40, r["floor"] - 150)
	add_child(_moth)
	Game.sfx("buzz", -12.0, 1.6)


func _make_encounter(i: int, waves: Array) -> Encounter:
	var r: Dictionary = _rooms[i]
	var g: Rect2 = r["glass"]
	var enc := Encounter.new()
	enc.left = g.position.x + 6
	enc.right = g.end.x - 6
	enc.ceil_y = g.position.y
	enc.floor_left = r["floor"]
	enc.floor_right = r["floor"]
	enc.waves = waves
	enc.spawn_hook = _spawn_tutorial_mob.bind(i)
	add_child(enc)
	return enc


## 教学关专属的怪（遭遇战按名字生）：拳击手从上面落下来；大陪练生在离人远的那头，血砍到 450，打起来半分钟内
func _spawn_tutorial_mob(kind: String, x: float, room: int) -> Node2D:
	var r: Dictionary = _rooms[room]
	var e: EnemyBase
	match kind:
		"boxer":
			e = TutorialBoxer.new()
		"coach":
			e = TutorialCoach.new()
			var g: Rect2 = r["glass"]
			x = g.end.x - 50.0 if _players[0].global_position.x < g.get_center().x else g.position.x + 50.0
		_:
			return null
	e.position = Vector2(x, r["floor"] - 40.0)
	add_child(e)
	if kind == "coach":
		e.max_hp = 450.0
		e.hp = 450.0
	return e


func _drop_weapon(i: int) -> void:
	var have := str(_players[0].call("weapon")) if _players[0].has_method("weapon") else "flash"
	var id := "shotgun" if have != "shotgun" else "rivet"
	_weapon_before = have
	var wp := WeaponPickup.new()
	wp.weapon = id
	wp.position = Vector2(_rooms[i]["ox"] + D.SIZE.x * 0.5, _rooms[i]["floor"])
	add_child(wp)
	_pickup = wp


func _on_crystal_broken() -> void:
	# 教学关不死：马灯补满，提示一句
	Run.heal_crystal(Run.crystal_max)
	_say(tr("Lantern's gone!!! Good thing this is only practice..."), false, true)


func _finish() -> void:
	_leaving = true
	Game.flash(Color(1.0, 0.86, 0.62), 0.35, 1.0)
	Game.sfx("tvon", -6.0, 1.1)
	_prompt.show_text("")
	hud.show_banner(tr("TUTORIAL CLEAR"), 1.2)
	TutorialLevel.mark_done()
	_after_finish.call_deferred()


func _after_finish() -> void:
	await get_tree().create_timer(1.6).timeout
	# 教学里挨的打、换的武器、存的档都不算进正式这一局
	Run.reset_run()
	SceneFade.go(get_tree(), next_scene)


# ---------------------------------------------------------------- 第一次开局才进教学：记在一个小文件里

const DONE_PATH := "user://tutorial.cfg"


static func _done_path() -> String:
	# 测试时跟着进度存档的环境变量走，不碰作者真正的记录
	var p := OS.get_environment("SCRAP_PROGRESS_PATH")
	return p + ".tutorial.cfg" if p != "" else DONE_PATH


## 这次运行里玩过（或跳过）了：测试、命令行开的游戏不写文件，只记在这里
static var _done_mem := false


## 教学玩过（或跳过）没有。开始界面"新开一局"时用：没玩过就先进教学
static func done() -> bool:
	if _done_mem:
		return true
	var cfg := ConfigFile.new()
	if cfg.load(_done_path()) != OK:
		return false
	return bool(cfg.get_value("tutorial", "done", false))


static func mark_done() -> void:
	_done_mem = true
	# 照 Run.real_launch() 的规矩：测试、headless、命令行开的游戏只记在内存里，不写作者的文件
	# （设了 SCRAP_PROGRESS_PATH 的测试写到它旁边）
	if OS.get_environment("SCRAP_PROGRESS_PATH") == "" and not Run.real_launch():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("tutorial", "done", true)
	cfg.save(_done_path())


## 跳过教学（暂停菜单、开始界面的"跳过"按钮调）：记成玩过，直接去下一个场景
static func skip(tree: SceneTree) -> void:
	mark_done()
	tree.paused = false
	Run.reset_run()
	SceneFade.go(tree, next_scene)
