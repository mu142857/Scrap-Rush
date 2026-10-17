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
	"tube": [Vector2(412, 540), -1, 0.0, 60],
	"bridge": [Vector2(1340, 300), 2, 1360.0, 50],
	"burn": [Vector2(1135, 300), 2, 1360.0, 40],
	"reel": [Vector2(1660, 300), 2, 1636.0, 90],
	"booth": [Vector2(2960, 300), 5, 0.0, 60],
	"hall": [Vector2(3290, 388), 5, 0.0, 60],
	"E4": [Vector2(3580, 520), 5, 0.0, 90],
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if shot == "":
		var tree := get_tree()
		get_parent().tree_exiting.connect(func():
			print("[l2tour] f%d level left (exit reached or reload)" % _frame)
			tree.quit())
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.invincible = true
	get_parent().set("_debug", true)
	get_parent().queue_redraw()


var _fight_start := {}
var _wave_seen := {}
var _done := {}


func _physics_process(_delta: float) -> void:
	_frame += 1
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
	_autopilot()
	while _i < _steps.size() and _frame >= _steps[_i][0]:
		_run(_steps[_i])
		_i += 1


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
	if _frame % SHOT_EVERY == 0:
		var cam := get_viewport().get_camera_2d()
		print("[l2tour] f%d player=%s floor=%s cam=%s zoom=%.2f state=%s hp=%.0f" % [_frame, p.global_position,
			p.is_on_floor(), cam.get_screen_center_position().round(), cam.zoom.x, get_parent().get("_state"), Run.crystal_hp])
	if _frame > MAX_FRAMES:
		print("[l2tour] gave up")
		get_tree().quit()


func _single() -> void:
	var s: Array = SHOTS[shot]
	var lvl := get_parent()
	if _frame == 2 and shot == "tube":
		var encs: Array = lvl.get("_encounters")
		encs[0].cleared = true
	if _frame == 2 and shot == "exit":
		var encs: Array = lvl.get("_encounters")
		encs[3].cleared = true
	if _frame == 20 and shot == "exit":
		Input.action_press("solo_right")
	if _frame % 30 == 0 and shot in ["banner", "exit"] and is_instance_valid(lvl) and lvl.is_inside_tree():
		var hud: Node = lvl.get("hud")
		var b: Label = hud.get("_banner")
		print("[l2shot] f%d banner visible=%s alpha=%.2f text=%s" % [_frame, b.visible, b.modulate.a, b.text])
	if _frame == 3:
		_run([0, "teleport", s[0]])
		if s[1] >= 0:
			var cam: Node = lvl.get("_cam")
			lvl.set("_state", s[1])
			if s[1] == 2:
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
	if _frame == s[3]:
		for n in lvl.get_children():
			if n is Encounter:
				print("[l2shot] encounter %d..%d started=%s cleared=%s" % [n.left, n.right, n.started, n.cleared])
		_run([0, "shot", shot])
	if _frame == s[3] + 6:
		get_tree().quit()


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
