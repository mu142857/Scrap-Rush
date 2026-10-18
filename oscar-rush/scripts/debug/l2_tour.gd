extends Node
## 第二关巡检：沿路线走一遍，到点截图。看碰撞、遭遇战闸门、电话响铃、天桥卷轴、烧穿边、换卷、放映厅。
## 用法（窗口被挡住时截图会冻住，用离屏录像）：
##   Godot --path . -w --write-movie /tmp/l2.avi --fixed-fps 60 scenes/level2.tscn -- --l2tour=<截图目录>
## 开了无敌和 F3 碰撞框。遭遇战用 "clear" 直接打完（只为了往前走）。按物理帧数走（每秒 120 帧）。
## 窗口被挡住时录像只有开头一两秒是新画面。那就用单拍：每个场景单独开一次，开局传送过去、摆好状态，1 秒内截图：
##   Godot --path . -w --write-movie /tmp/x.avi --fixed-fps 60 --quit-after 200 scenes/level2.tscn -- --l2shot=bridge:<目录>

var out_dir := ""
## 单拍模式：SHOTS 里的场景名
var shot := ""
## [传送到, 天桥状态（-1 不管）, 镜头卷轴 x, 第几帧截图]
const SHOTS := {
	"R1": [Vector2(250, 540), -1, 0.0, 70],
	"R2": [Vector2(700, 430), -1, 0.0, 70],
	"R3": [Vector2(250, 250), -1, 0.0, 70],
	"R4": [Vector2(760, 300), -1, 0.0, 50],
	"R4home": [Vector2(880, 300), -1, 0.0, 50],
	"tube": [Vector2(412, 540), -1, 0.0, 60],
	"bridge": [Vector2(1340, 300), 2, 1360.0, 50],
	"oil": [Vector2(1900, 300), 2, 1960.0, 50],
	"burn": [Vector2(1135, 300), 2, 1360.0, 40],
	"reel": [Vector2(1660, 300), 2, 1636.0, 90],
	"booth": [Vector2(2960, 300), 5, 0.0, 60],
	"hall": [Vector2(3290, 388), 5, 0.0, 60],
	"E4": [Vector2(3580, 520), 5, 0.0, 90],
	# 观察：进乐池那场，小怪一出来就打死，精英留着，每秒打印精英的位置（查留声机会不会卡在台阶座位上）
	"E4watch": [Vector2(3600, 520), 5, 0.0, 99999],
	# 拼接缝检查：大图层切成 2048 宽的竖条，接缝在各层图里的 x=2048。镜头停在让接缝正好在画面中间的位置
	# （HOLD 状态：镜头不卷、也不触发换卷）。main 1.0 倍：镜头 2048；mid 0.75 倍：2114；far 0.55 倍：2211
	"seam_main": [Vector2(2000, 300), 4, 2048.0, 50],
	"seam_mid": [Vector2(2060, 300), 4, 2114.0, 50],
	"seam_far": [Vector2(2160, 300), 4, 2211.0, 50],
	# 场景活气（level2_life.gd）：天桥上等飞蛾影子飞过；银幕放老电影（镜头摆到银幕正前方、1 倍）
	"moth": [Vector2(1340, 300), 2, 1360.0, 610],
	"screen": [Vector2(3430, 454), 5, 0.0, 560],
	# 互动小东西：开枪打三盏油灯、一盏吊灯、电话簿仓库那部电话（三下），最后打印结果（不截图看也行）
	"knock": [Vector2(330, 250), -1, 0.0, 760],
	# 天桥后的存档点：站进放映室（HOLD → 天桥结束、存档），按 R 重来，看是不是在放映室、天桥不再开始
	"bridgecp": [Vector2(2900, 300), 4, 2700.0, 99999],
	# 提示牌（hint_sign 的 level_width）：后半段的牌子和天桥口那块长字
	"sign_duck": [Vector2(3040, 300), 5, 0.0, 90],
	"sign_exit": [Vector2(3600, 500), 5, 0.0, 90],
	"sign_burn": [Vector2(960, 300), -1, 0.0, 70],
	"lamp2": [Vector2(600, 430), -1, 0.0, 70],
	"lamp3": [Vector2(110, 250), -1, 0.0, 70],
	"lamp4": [Vector2(630, 300), -1, 0.0, 70],
	# 下面两个不截单张，只跑着（配 --write-movie 录连续帧），每 30 帧打一行横幅状态
	"banner": [Vector2(1030, 300), -1, 0.0, 99999],
	"exit": [Vector2(3618, 500), 5, 0.0, 99999],
}
var _frame := 0
var _i := 0
## 走完整条路线（自动驾驶）：电话簿仓库里往左走，其他地方往右走，被挡住就跳一下；
## 遭遇战开打 150 帧以后自动打完（autoclear）。每 SHOT_EVERY 帧打一行状态，离开关卡（进商店）就退出
const SHOT_EVERY := 300
const MAX_FRAMES := 20000
var _steps: Array = [
]


var _jump_t := 0
var _stuck := 0
## --l2retry：第一场换卷战开打时故意让马灯碎掉一次，测从存档点重来（只碎一次）
static var _killed := false
## bridgecp 单拍：0 还没重来，1 已经重来过
static var _cp_phase := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if shot == "":
		var tree := get_tree()
		get_parent().tree_exiting.connect(func():
			if Run.get("_resuming"):
				print("[l2tour] f%d level reloading (retry)" % _frame)
				return
			print("[l2tour] f%d level left (exit reached)" % _frame)
			tree.quit())
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.invincible = true
	if shot == "":
		get_parent().set("_debug", true)            # 单拍截图不开碰撞框，看的是正式画面
		get_parent().queue_redraw()


var _fight_start := {}
var _wave_seen := {}
var _done := {}


func _physics_process(_delta: float) -> void:
	_frame += 1
	if shot == "plats":
		_plats()
		return
	if shot != "":
		_single()
		return
	# autoclear：开打 150 帧以后直接打完
	for n in get_parent().get_children():
		if n is Encounter and n.started and not n.cleared:
			if not _fight_start.has(n):
				_fight_start[n] = _frame
				print("[l2tour] f%d fight start %d..%d" % [_frame, n.left, n.right])
			elif _frame - _fight_start[n] > 2400:
				print("[l2tour] f%d STUCK %d..%d wave=%d alive=%d queue=%d" % [_frame, n.left, n.right, n._wave, n._alive.size(), n._queue.size()])
				_run([0, "clear", null])
			elif (_frame - _fight_start[n]) % 90 == 0:
				# 真打：把场上活着的怪一只只打死，让每一波（包括精英）都真的生出来、死掉
				var killed := []
				for e in n._alive:
					if is_instance_valid(e) and not e.get("dead") and e.has_method("hurt"):
						killed.append(e.get_script().resource_path.get_file().get_basename())
						e.hurt(99999.0, Vector2.UP, true)
				if not killed.is_empty():
					print("[l2tour] f%d %d..%d wave %d killed %s" % [_frame, n.left, n.right, n._wave, killed])
		elif n is Encounter and n.cleared and _fight_start.has(n) and not _done.has(n):
			_done[n] = true
			print("[l2tour] f%d CLEARED for real %d..%d after %d frames" % [_frame, n.left, n.right, _frame - _fight_start[n]])
	_retry_probe()
	_autopilot()
	while _i < _steps.size() and _frame >= _steps[_i][0]:
		_run(_steps[_i])
		_i += 1


func _retry_probe() -> void:
	if _killed or not OS.get_cmdline_user_args().has("--l2retry"):
		return
	if get_parent().get("_state") == 3:
		_killed = true
		print("[l2tour] f%d forcing crystal break on the bridge" % _frame)
		Game.invincible = false
		Run.damage_crystal(99999.0)


func _autopilot() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p: CharacterBody2D = players[0]
	if p.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	var in_r3 := Rect2(40, 140, 420, 130).has_point(p.global_position)
	Input.action_release("solo_left" if not in_r3 else "solo_right")
	Input.action_press("solo_right" if not in_r3 else "solo_left")
	if p.is_on_floor() and absf(p.velocity.x) < 5.0:
		_stuck += 1
	else:
		_stuck = 0
	if _stuck > 20 and _jump_t == 0:
		_jump_t = 24
	if _jump_t > 0:
		Input.action_press("solo_jump")
		_jump_t -= 1
		if _jump_t == 0:
			Input.action_release("solo_jump")
	if _frame == 30:
		var lamps: Array = get_parent().get("_tube_lamps")
		var encs: Array = get_parent().get("_encounters")
		print("[l2tour] start at %s cleared=%s lamps=%s" % [p.global_position, encs.map(func(e): return e.cleared), lamps.map(func(l): return l.open)])
	if _frame % 1200 == 0:
		var lights: Array = get_parent().get("_static_lights")
		var on := lights.filter(func(l): return is_instance_valid(l) and l.enabled).size()
		print("[l2tour] f%d static lights on %d / %d" % [_frame, on, lights.size()])
	if _frame % SHOT_EVERY == 0:
		var cam := get_viewport().get_camera_2d()
		print("[l2tour] f%d player=%s floor=%s cam=%s zoom=%.2f state=%s hp=%.0f" % [_frame, p.global_position,
			p.is_on_floor(), cam.get_screen_center_position().round(), cam.zoom.x, get_parent().get("_state"), Run.crystal_hp])
	if _frame > MAX_FRAMES:
		print("[l2tour] gave up")
		get_tree().quit()


## 平台检查：把人逐块放到每个单向平台上方 6 像素，等它落稳，看是不是站在平台顶上
func _plats() -> void:
	var lvl := get_parent()
	var D: Script = load("res://scripts/levels/level2_data.gd")
	var plats: Array = D.get_script_constant_map()["PLATFORMS"]
	var i := int(_frame / 40)
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p: CharacterBody2D = players[0]
	if _frame % 40 == 1 and i < plats.size():
		var r: Rect2 = plats[i]
		p.global_position = Vector2(r.get_center().x, r.position.y - 6.0)
		p.velocity = Vector2.ZERO
	if _frame % 40 == 39 and i < plats.size():
		var r: Rect2 = plats[i]
		print("[plat] %d %s floor=%s y=%.1f ok=%s" % [i, r, p.is_on_floor(), p.global_position.y, absf(p.global_position.y - r.position.y) < 1.0])
	if i >= plats.size():
		get_tree().quit()


func _single() -> void:
	var s: Array = SHOTS[shot]
	var lvl := get_parent()
	if _frame == 2 and shot == "tube":
		var encs: Array = lvl.get("_encounters")
		encs[0].cleared = true
	if _frame == 2 and shot == "sign_exit":
		var e4: Node = lvl.get("_encounters")[3]
		e4.started = true
		e4.cleared = true
		e4.finished.emit()
	if _frame == 2 and shot == "exit":
		var encs: Array = lvl.get("_encounters")
		encs[3].cleared = true
	if shot == "E4watch" and _frame > 10:
		for n in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(n) or n.get("dead"):
				continue
			if n is EliteBase:
				if _frame % 120 == 0:
					var body := n as CharacterBody2D
					print("[watch] f%d %s pos=%s floor=%s vel=%s" % [_frame, n.get_script().resource_path.get_file(), (n as Node2D).global_position.round(),
						body.is_on_floor() if body else "?", body.velocity.round() if body else "?"])
			elif _frame % 30 == 0 and n.has_method("hurt"):
				n.hurt(99999.0, Vector2.UP, true)
		if _frame > 4000:
			get_tree().quit()
	if _frame == 20 and shot == "exit":
		Input.action_press("solo_right")
	if _frame == 140 and shot == "exit":
		print("[l2shot] pressing R while leaving=%s, pause can_open=%s" % [lvl.get("_leaving"), Game.pause_menu.can_open()])
		lvl.call("_retry")
		print("[l2shot] after R retrying=%s" % lvl.get("_retrying"))
	if _frame % 30 == 0 and shot in ["banner", "exit"] and is_instance_valid(lvl) and lvl.is_inside_tree():
		var hud: Node = lvl.get("hud")
		var b: Label = hud.get("_banner")
		print("[l2shot] f%d banner visible=%s alpha=%.2f text=%s" % [_frame, b.visible, b.modulate.a, b.text])
	if shot == "bridgecp":
		if _cp_phase == 0 and _frame == 80:
			print("[cp] saved=%s pos=%s state=%d" % [Run.checkpoint.get("cleared"), Run.checkpoint.get("pos"), lvl.get("_state")])
			_cp_phase = 1
			lvl.call("_retry")
			return
		if _cp_phase == 1:
			if _frame == 240:
				var ps := get_tree().get_nodes_in_group("player")
				print("[cp] after retry state=%d player=%s scrolling=%s burn=%s" % [lvl.get("_state"), (ps[0] as Node2D).global_position.round(),
					lvl.get("_cam").get("scrolling"), lvl.get("_burn").visible])
				get_tree().quit()
			return
	if _frame == 3:
		_run([0, "teleport", s[0]])
		if s[1] >= 0:
			var cam: Node = lvl.get("_cam")
			lvl.set("_state", s[1])
			if s[1] in [2, 4]:
				cam.set("scrolling", true)
				cam.set("scroll_x", s[2])
				cam.set("scroll_y", 262.0)
				cam.call("set_wide", true)
				cam.set("zoom", Vector2.ONE)
				cam.set("global_position", Vector2(s[2], 262.0))
				lvl.get("_burn").set("visible", true)
			else:
				cam.call("snap")
		else:
			lvl.get("_cam").call("snap")
	if shot == "moth" and _frame == s[3] - 8:
		# 飞蛾影子：不等它自己来，直接摆到画面中间
		for n in lvl.find_children("*", "Node2D", true, false):
			if n.get("_size") != null and n.get("_on") != null:
				var cam: Camera2D = lvl.get("_cam")
				n.set("_on", true)
				n.set("_t", 0.2)
				n.set("_pos", cam.get_screen_center_position() + Vector2(-40, -10))
				n.set("_vel", Vector2(-260, 0))
	if shot == "knock":
		_knock_test(lvl)
	if shot == "screen" and _frame == s[3] - 4:
		var cam: Camera2D = lvl.get("_cam")
		cam.set_process(false)
		cam.set_physics_process(false)
		cam.zoom = Vector2.ONE
		cam.global_position = Vector2(3500, 300)
		cam.reset_smoothing()
	if _frame == s[3]:
		for n in lvl.get_children():
			if n is Encounter:
				print("[l2shot] encounter %d..%d started=%s cleared=%s" % [n.left, n.right, n.started, n.cleared])
		_run([0, "shot", shot])
	if _frame == s[3] + 6:
		get_tree().quit()


## "knock" 单拍：在目标旁边放铆钉往目标飞，看油灯碎没碎、掉没掉灯油，电话吐没吐零件
func _knock_test(lvl: Node) -> void:
	if _frame == 2:
		for i in 3:
			lvl.get("_encounters")[i].cleared = true
	var shots := {
		100: [Vector2(590, 372), Vector2.RIGHT], 140: [Vector2(92, 178), Vector2.LEFT], 180: [Vector2(574, 236), Vector2.LEFT],
		220: [Vector2(230, 450), Vector2.RIGHT],
		300: [Vector2(250, 206), Vector2.RIGHT], 450: [Vector2(250, 206), Vector2.RIGHT], 600: [Vector2(250, 206), Vector2.RIGHT],
	}
	if shots.has(_frame):
		var r := Rivet.new()
		r.setup(shots[_frame][0] - shots[_frame][1] * 30.0, shots[_frame][1], Color.WHITE)
		lvl.add_child(r)
	if _frame == 300:
		for i in 3:
			lvl.get("_encounters")[i].started = false
	if _frame == 740:
		var oils := 0
		var parts := 0
		var broken := 0
		for n in lvl.find_children("*", "", true, false):
			if n is LampOil:
				oils += 1
			if n.get("kind") == "part" and (n as Node2D).global_position.distance_to(Vector2(258, 250)) < 4.0:
				parts += 1
			if n.get("_broken") == true:
				broken += 1
		print("[knock] broken lamps=%d lamp oil drops=%d payphone part=%d" % [broken, oils, parts])


func _run(step: Array) -> void:
	var players := get_tree().get_nodes_in_group("player")
	match step[1]:
		"press":
			Input.action_press(step[2])
		"release":
			Input.action_release(step[2])
		"shot":
			if players.is_empty():
				print("[l2tour] f%d %s (no players: scene changed?) %s" % [_frame, step[2], get_tree().current_scene])
				return
			var p: Node2D = players[0]
			var cam := get_viewport().get_camera_2d()
			print("[l2tour] f%d %s player=%s floor=%s cam=%s zoom=%s state=%s" % [_frame, step[2], p.global_position,
				p.call("is_on_floor"), cam.get_screen_center_position(), cam.zoom.x, get_parent().get("_state")])
			if DisplayServer.get_name() == "headless":
				return
			var path := out_dir.path_join(step[2] + ".png")
			RenderingServer.frame_post_draw.connect(func() -> void:
				get_viewport().get_texture().get_image().save_png(path), CONNECT_ONE_SHOT)
		"teleport":
			for p in players:
				p.global_position = step[2]
				p.velocity = Vector2.ZERO
		"clear":
			for n in get_parent().get_children():
				if n is Encounter and n.started and not n.cleared:
					for e in n._alive:
						if is_instance_valid(e):
							e.queue_free()
					n._alive.clear()
					n._queue.clear()
					n._finish()
					print("[l2tour] cleared ", n.left, "..", n.right)
		"quit":
			get_tree().quit()
