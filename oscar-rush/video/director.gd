extends Node
## 摆拍导演：每帧强制出图（窗口最小化也照样录，见 force_draw）、开无敌、去掉暂停菜单、顿帧不改时间流速。
## 每个镜头是一个 shot_xxx() 协程，拍完 get_tree().quit()。

var shot := ""
var t := 0.0
var _p: Node2D
var _hold := {}

func _ready() -> void:
	process_priority = 100000
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	if Game.pause_menu:
		Game.pause_menu.queue_free()
		Game.pause_menu = null
	Game.invincible = true
	if not has_method("shot_" + shot):
		push_error("没有这个镜头：" + shot)
		get_tree().quit(1)
		return
	await call("shot_" + shot)
	print("[rec] 镜头结束 t=%.1f" % t)
	await wait(0.1)
	get_tree().quit()


func _process(delta: float) -> void:
	t += delta
	Engine.time_scale = 1.0
	Game.invincible = true
	RenderingServer.force_draw.call_deferred(false, 0.0)
	if hide_hints:
		_hide_hints(get_tree().root)
	# 剧情对话框会暂停游戏等人按键：一直帮它翻页
	_dlg_t += delta
	if _dlg_t > 0.4:
		_dlg_t = 0.0
		for b in get_tree().get_nodes_in_group("dialog_box"):
			if b.has_method("_next"):
				b.call("_next")
	if OS.get_environment("REC_DEBUG") == "1" and int(t) != int(t - delta) and int(t) % 5 == 0:
		print("[dbg] t=%d paused=%s scene=%s" % [int(t), get_tree().paused, get_tree().current_scene.name if get_tree().current_scene else "-"])


var _dlg_t := 0.0


## 新手提示（Coach）和路牌（HintSign）不进画面
var hide_hints := true

func _hide_hints(n: Node) -> void:
	for c in n.get_children():
		if c is Coach or c is HintSign or c is AchievementToast or c is CrewLine:
			c.visible = false
		elif c is Hud:
			var h = c.get("_hint")
			if h is CanvasItem:
				h.visible = false
			_hide_hints(c)
		elif c is Node:
			_hide_hints(c)


# ---------- 小工具 ----------

func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func go_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame


func player() -> Node2D:
	if is_instance_valid(_p):
		return _p
	for n in get_tree().get_nodes_in_group("player"):
		_p = n
		return _p
	return null


func press(what: String) -> void:
	Input.action_press("solo_" + what)


func release(what: String) -> void:
	Input.action_release("solo_" + what)


func tap(what: String, sec := 0.08) -> void:
	press(what)
	await wait(sec)
	release(what)


## 往左/右走到 x（到了就松手）
func walk_to(x: float, timeout := 8.0) -> void:
	var p := player()
	var end := t + timeout
	while p and t < end and absf(p.global_position.x - x) > 3.0:
		var right := p.global_position.x < x
		Input.action_press("solo_right" if right else "solo_left")
		Input.action_release("solo_left" if right else "solo_right")
		await get_tree().process_frame
	release("left")
	release("right")


func new_run() -> void:
	Run.reset_run()
	Game.reset_stats()


# ---------- 镜头 ----------
# 三倍法则：每个镜头按台词估计划时长，录三倍长。只录干净画面（不加字、不定格）。

func set_weapon(w: String) -> void:
	Upgrades.weapon = w
	Run.players[0]["weapon"] = w


## 进某一关：新开一局、拿好武器、等主角出来
func enter(scene: String, w: String, intro := false) -> void:
	new_run()
	set_weapon(w)
	if not intro:
		LevelIntro._played[scene] = true   # 关卡开场动画默认不要
	await go_scene(scene)
	while player() == null:
		await get_tree().process_frame


func clear_all_encounters() -> void:
	for e in encounters():
		e.cleared = true


func boss() -> Node2D:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_signal("defeated"):
			return e
	return null


## 第一关 01｜2080 年只剩修机器的活：提灯在第一关里慢慢走，看旧机器（台词约 10 秒 → 录 35 秒）
func shot_l1_env() -> void:
	await enter("res://scenes/test_level.tscn", "hammer")
	clear_all_encounters()
	await wait(1.0)
	await walk_to(985.0, 20.0)
	await wait(0.6)
	await walk_to(1000.0, 3.0)   # 右端跳下到中层
	await wait(1.5)
	await walk_to(20.0, 20.0)
	await walk_to(4.0, 3.0)      # 中层左端跳下到底层
	await wait(1.5)
	await walk_to(420.0, 15.0)
	await wait(2.0)


## 第一关 02｜挑工具、关灯：选武器界面慢慢翻一遍再选蒸汽锤，进关开场动画，提灯往右走（台词约 9 秒 → 录 30 秒）
func shot_l1_weapon() -> void:
	new_run()
	await go_scene("res://scenes/weapon_select.tscn")
	var ws := get_tree().current_scene
	await wait(2.0)
	var ids: Array = ws.get("_ids")
	for k in ids.size() - 1:
		ws.call("_move", 1)
		await wait(1.1)
	await wait(0.8)
	var target := ids.find("hammer")
	while int(ws.get("_selected")) != target:
		ws.call("_move", -1)
		await wait(0.7)
	await wait(2.5)
	ws.call("_choose")
	while player() == null:
		await get_tree().process_frame
	await wait(6.0)
	await walk_to(140.0, 4.0)
	await wait(2.0)
	await walk_to(215.0, 6.0)
	await wait(3.0)


## 第一关 03｜机器甲、乙逼近被打掉：第一场遭遇战正常打完三波（布谷鸟钟精英收尾）（台词约 14 秒 → 录到打完，约 40~60 秒）
func shot_l1_fight() -> void:
	await enter("res://scenes/test_level.tscn", "hammer")
	await wait(1.0)
	await walk_to(300.0, 6.0)
	var enc: Encounter = encounters()[0]
	await fight(120.0, func(): return enc.cleared, 236.0, 444.0)
	await wait(3.0)


## 第一关 04｜机器丙"我下班了"：主角站着不打，怪靠过来（台词约 6 秒 → 录 20 秒）
func shot_l1_stand() -> void:
	await enter("res://scenes/test_level.tscn", "hammer")
	var encs := encounters()
	for k in encs.size():
		if k != 1:
			encs[k].cleared = true
	teleport(Vector2(640.0, 110.0))
	await wait(0.5)
	await walk_to(700.0, 4.0)
	await wait(0.3)
	player().set("facing", 1)
	await wait(22.0)


## 第一关 05｜锅炉 Boss：进门、Boss 醒来、开打，一直打到击败、门打开（台词约 10 秒 → 整场录下来）
func shot_l1_boss() -> void:
	await enter("res://scenes/boss1.tscn", "hammer")
	await boss_fight()


func boss_fight(max_sec := 200.0) -> void:
	var arena := get_tree().current_scene
	var tx: float = float(arena.get("trigger_x")) if arena.get("trigger_x") != null else 200.0
	await walk_to(tx + 20.0, 10.0)
	while boss() == null:
		await get_tree().process_frame
	var b := boss()
	var done := [false]
	b.defeated.connect(func(): done[0] = true)
	var t0 := t
	await fight(max_sec, func(): return done[0])
	if not done[0]:
		print("[rec] Boss 打了 %.0f 秒没死，补刀" % (t - t0))
		while not done[0] and is_instance_valid(b):
			b.call("hurt", 99999.0, Vector2.LEFT, true) if b.has_method("hurt") else null
			await wait(0.5)
	print("[rec] Boss 死于 %.1f 秒" % (t - t0))
	await wait(8.0)


# ---------- 自动打怪 ----------

const RANGE := {"flash": 70.0, "rivet": 50.0, "hammer": 22.0, "laser": 80.0, "shotgun": 36.0, "record": 60.0, "tongs": 60.0}

func _weapon() -> String:
	return str(Upgrades.weapon)


func enemies() -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e is Node2D and not e.get("dead") and e.is_inside_tree():
			out.append(e)
	return out


## 打了 3 秒还掉不了血的怪（隔着屏幕边框、打不到）先不管它，10 秒后再说
var _ignore := {}
var _tgt: Node2D
var _tgt_hp := 0.0
var _tgt_t := 0.0


func _track(e: Node2D, attacking: bool) -> void:
	if e != _tgt:
		_tgt = e
		_tgt_hp = float(e.get("hp")) if e and e.get("hp") != null else 0.0
		_tgt_t = t
		return
	if e == null or e.get("hp") == null:
		return
	var hp := float(e.get("hp"))
	if hp < _tgt_hp or not attacking:
		_tgt_hp = hp
		_tgt_t = t
	elif t - _tgt_t > 3.0:
		_ignore[e.get_instance_id()] = t + 10.0
		_tgt = null


func nearest_enemy(max_dx := 400.0) -> Node2D:
	var p := player()
	var best: Node2D = null
	var bd := INF
	for e in enemies():
		if _ignore.get(e.get_instance_id(), 0.0) > t:
			continue
		var d: float = absf(e.global_position.x - p.global_position.x) + absf(e.global_position.y - p.global_position.y) * 0.5
		if d < bd and absf(e.global_position.x - p.global_position.x) < max_dx:
			bd = d
			best = e
	return best


## 正常打：找最近的怪，走到这把武器的射程上，面朝它攻击；怪在头顶就跳，隔几秒随手跳一下躲子弹。
## until 返回 true 或者到 sec 秒就停。lo/hi 限制主角左右活动范围（不跑出镜头外）。
func fight(sec: float, until := Callable(), lo := -INF, hi := INF, attack := true) -> void:
	var p := player()
	var end := t + sec
	var atk_t := 0.0
	var hold := 0.0
	var jump_t := randf_range(1.5, 3.5)
	var jump_rel := 0.0
	var w := _weapon()
	var rng: float = RANGE.get(w, 50.0)
	while t < end and is_instance_valid(p):
		if until.is_valid() and until.call():
			break
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		atk_t += dt
		jump_t -= dt
		var e := nearest_enemy()
		if OS.get_environment("REC_DEBUG") == "1" and int(t * 2) != int((t - dt) * 2) and int(t) % 3 == 0:
			print("[dbg] t=%.1f p=%s e=%s %s" % [t, p.global_position.round(), e.name if e else "-", e.global_position.round() if e else ""])
		var mx := 0
		if e:
			var dx := e.global_position.x - p.global_position.x
			var want := rng * 0.8
			if absf(dx) > want + 6.0:
				mx = 1 if dx > 0 else -1
			elif absf(dx) < want * 0.4 and rng > 30.0:
				mx = -1 if dx > 0 else 1   # 太近就退半步
			if p.global_position.x + mx * 4.0 < lo or p.global_position.x + mx * 4.0 > hi:
				mx = 0
			if mx != 0:
				Input.action_press("solo_right" if mx > 0 else "solo_left")
				Input.action_release("solo_left" if mx > 0 else "solo_right")
			else:
				release("left")
				release("right")
				if absf(dx) > 1.0:
					p.set("facing", 1 if dx > 0 else -1)
			var attacking := attack and absf(dx) < rng * 1.4
			_track(e, attacking)
			if attacking:
				hold = _press_attack(w, atk_t, hold, p, dt)
			else:
				release("attack")
				hold = 0.0
			if e.global_position.y < p.global_position.y - 28.0 and absf(dx) < rng and jump_t < 1.0:
				jump_t = 0.0
		else:
			release("left")
			release("right")
			release("attack")
		jump_rel -= dt
		if jump_t <= 0.0:
			press("jump")
			jump_t = randf_range(2.0, 4.5)
			jump_rel = randf_range(0.15, 0.35)
		elif jump_rel <= 0.0:
			release("jump")
	if OS.get_environment("REC_DEBUG") == "1":
		print("[dbg] fight end t=%.1f valid=%s until=%s" % [t, is_instance_valid(p), until.call() if until.is_valid() else "-"])
	for a in ["left", "right", "attack", "jump"]:
		release(a)


func _press_attack(w: String, tt: float, hold: float, p: Node, dt: float) -> float:
	match w:
		"hammer":
			if int(tt / 0.25) != int((tt - dt) / 0.25):
				press("attack")
			else:
				release("attack")
			return 0.0
		"record", "shotgun":
			if int(tt / 0.2) != int((tt - dt) / 0.2):
				press("attack")
			else:
				release("attack")
			return 0.0
		"flash":
			if hold < 0.0:
				release("attack")
				return hold + dt
			press("attack")
			hold += dt
			if hold >= float(p.call("charge_time")) + 0.05:
				release("attack")
				return -0.1
			return hold
	press("attack")
	return hold + dt


func encounters() -> Array:
	var out := []
	_collect(get_tree().current_scene, out)
	return out


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Encounter:
			out.append(c)
		_collect(c, out)


func teleport(pos: Vector2) -> void:
	var p := player()
	p.global_position = pos
	p.set("velocity", Vector2.ZERO)
	p.reset_physics_interpolation()
	var cam := get_viewport().get_camera_2d()
	if cam:
		cam.global_position = pos
		cam.reset_physics_interpolation()
		if cam.has_method("snap"):
			cam.call("snap")


## 一路往 dir 方向走到 x：路上遇到开打的遭遇战就打完再走，怪贴近了顺手打，被挡住就跳。
func advance(x: float, timeout := 120.0, max_fight := 150.0) -> void:
	var p := player()
	var end := t + timeout
	var last_x := p.global_position.x
	var stuck := 0.0
	while t < end and is_instance_valid(p) and absf(p.global_position.x - x) > 4.0:
		var enc: Encounter = null
		for e in encounters():
			if e.started and not e.cleared:
				enc = e
		if enc:
			await fight(max_fight, func(): return enc.cleared, enc.left + 8.0, enc.right - 8.0)
			await wait(0.8)
			continue
		var e2 := nearest_enemy(40.0)
		if e2 and absf(e2.global_position.y - p.global_position.y) < 30.0:
			await fight(0.6)
			continue
		var right := p.global_position.x < x
		Input.action_press("solo_right" if right else "solo_left")
		Input.action_release("solo_left" if right else "solo_right")
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		if absf(p.global_position.x - last_x) < 0.05:
			stuck += dt
		else:
			stuck = 0.0
		last_x = p.global_position.x
		if stuck > 0.25:
			press("jump")
			await wait(0.3)
			release("jump")
			stuck = 0.0
	for a in ["left", "right", "attack", "jump"]:
		release(a)


## 第二关：跳过气动管，从坠落开场进来；除了 keep 那几场，别的遭遇战标成打完
func enter_l2(w: String, keep: Array, pos := Vector2.ZERO, state := -1) -> void:
	new_run()
	set_weapon(w)
	load("res://scripts/levels/level2.gd").set("tube_landing", true)
	await go_scene("res://scenes/level2.tscn")
	while player() == null:
		await get_tree().process_frame
	var lvl := get_tree().current_scene
	var encs: Array = lvl.get("_encounters")
	for k in encs.size():
		if not keep.has(k):
			encs[k].cleared = true
	if pos != Vector2.ZERO:
		await wait(3.5)   # 等胶囊坠落演出放完（它会把人摆到落点），再传送
		if state >= 0:
			lvl.set("_state", state)   # 先设好关卡状态，免得传送时越过天桥触发点、开始卷轴
		teleport(pos)
		lvl.get("_cam").call("snap")
		await wait(0.5)


## 第二关 E1 接线员大厅：胶囊砸下来直接开打，三波，最后总机台（名字卡"请稍候"）
func shot_l2_e1() -> void:
	await enter_l2("rivet", [0])
	await wait(2.0)
	var enc: Encounter = get_tree().current_scene.get("_encounters")[0]
	while not enc.started:
		await advance(player().global_position.x + 30.0, 2.0)
	await fight(180.0, func(): return enc.cleared, enc.left + 8.0, enc.right - 8.0)
	await wait(4.0)


## 第二关 E2 继电器机房：拾荒者、手摇电话叫人、守夜巨人
func shot_l2_e2() -> void:
	await enter_l2("rivet", [1], Vector2(600, 430))
	await advance(720.0, 6.0)
	var enc: Encounter = get_tree().current_scene.get("_encounters")[1]
	await fight(180.0, func(): return enc.cleared, enc.left + 8.0, enc.right - 8.0)
	await wait(4.0)


## 第二关 E3 电话簿仓库：最后总接线长
func shot_l2_e3() -> void:
	await enter_l2("rivet", [2], Vector2(380, 250))
	await advance(250.0, 6.0)
	var enc: Encounter = get_tree().current_scene.get("_encounters")[2]
	await fight(180.0, func(): return enc.cleared, enc.left + 8.0, enc.right - 8.0)
	await wait(4.0)


## 第二关 胶片天桥：从片库走上天桥，自动卷轴，两场换卷（剪辑师、放映机）都打完，走到放映室
func shot_l2_bridge() -> void:
	await enter_l2("rivet", [], Vector2(880, 300))
	await advance(2960.0, 400.0)
	await wait(2.0)


## 第二关 放映厅：从放映室钻出去，沿座位往下到乐池，打最后一场（观众扑上来、留声机）
func shot_l2_hall() -> void:
	await enter_l2("rivet", [3], Vector2(2960, 300), 5)
	await wait(1.0)
	await advance(3600.0, 200.0)
	await wait(4.0)


func shot_l2_boss() -> void:
	await enter("res://scenes/boss2.tscn", "rivet")
	await boss_fight()



## 第三关 01｜屏幕世界开场：开机动画，提灯进来，先对着空气乱打、往前冒进几下，再进第一块屏幕（卧室）打遭遇战
func shot_l3_start() -> void:
	await enter("res://scenes/level3.tscn", "laser", true)
	await wait(7.0)
	var p := player()
	# 打空：原地朝右按住攻击一会儿、松开，往前冲一段，回头再打一下
	press("attack"); await wait(1.4); release("attack")
	await wait(0.4)
	press("right"); press("jump"); await wait(0.25); release("jump"); await wait(0.6); release("right")
	press("attack"); await wait(1.0); release("attack")
	press("left"); await wait(0.15); release("left")
	press("attack"); await wait(0.8); release("attack")
	press("right"); await wait(0.5); release("right")
	press("jump"); press("attack"); await wait(0.9); release("jump"); release("attack")
	await wait(0.5)
	await advance(500.0, 150.0)
	await wait(3.0)


## 第三关 02｜沿最底下一排屏幕一路往右打：屋顶、雪花屏、雨街几场遭遇战（每场最后出这块屏幕的精英）
func shot_l3_run() -> void:
	await enter("res://scenes/level3.tscn", "laser")
	await wait(1.0)
	await advance(2400.0, 420.0)
	await wait(3.0)


func shot_l3_boss() -> void:
	await enter("res://scenes/boss3.tscn", "laser")
	await boss_fight()


## 第一关 03b｜再打一场：中层继电器那场（爬虫、剃须刀、缝纫机精英），给"机器甲乙"多一份素材
func shot_l1_fight2() -> void:
	await enter("res://scenes/test_level.tscn", "hammer")
	var encs := encounters()
	for k in encs.size():
		if k != 2:
			encs[k].cleared = true
	teleport(Vector2(960.0, 200.0))
	await wait(1.0)
	await walk_to(800.0, 6.0)
	var enc: Encounter = encs[2]
	await fight(150.0, func(): return enc.cleared, enc.left + 8.0, enc.right - 8.0)
	await wait(3.0)
