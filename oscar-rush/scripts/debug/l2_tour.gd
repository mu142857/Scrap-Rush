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
	"A1": [Vector2(420, 96), -1, 0.0, 70],
	"A3": [Vector2(600, 200), -1, 0.0, 40],
	"A2": [Vector2(500, 300), -1, 0.0, 40],
	"bridge": [Vector2(1340, 300), 2, 1360.0, 50],
	"burn": [Vector2(1135, 300), 2, 1360.0, 40],
	"reel": [Vector2(1660, 300), 2, 1636.0, 90],
	"booth": [Vector2(2960, 300), 5, 0.0, 60],
	"hall": [Vector2(3290, 388), 5, 0.0, 60],
	"E4": [Vector2(3580, 520), 5, 0.0, 90],
}
var _frame := 0
var _i := 0
## 走完整条路线。遭遇战开打 150 帧以后自动打完（autoclear），换卷也一样，所以只管按方向键
var _steps: Array = [
	[40, "shot", "01_A1_start"],
	[42, "press", "solo_right"],
	[700, "shot", "02_A1_fight"],
	[1200, "shot", "03_A1_end"],
	[1202, "release", "solo_right"],
	[1204, "teleport", Vector2(790, 96)],
	[1206, "press", "solo_right"],
	[1300, "release", "solo_right"],
	[1302, "press", "solo_left"],
	[1400, "shot", "04_A3"],
	[2300, "shot", "05_A3_end"],
	[2302, "release", "solo_left"],
	[2304, "press", "solo_right"],
	[2400, "shot", "06_A2"],
	[3400, "shot", "07_A2_end"],
	[3700, "shot", "08_bridge"],
	[4400, "shot", "09_rolling"],
	[5400, "shot", "10_rolling"],
	[6400, "shot", "11_rolling"],
	[7400, "shot", "12_rolling"],
	[8400, "shot", "13_after"],
	[9400, "shot", "14_after"],
	[10400, "shot", "15_after"],
	[10402, "teleport", Vector2(3630, 500)],
	[10600, "shot", "16_exit"],
	[10800, "shot", "17_shop"],
	[10900, "quit", null],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.invincible = true
	get_parent().set("_debug", true)
	get_parent().queue_redraw()


var _fight_start := {}


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
			elif _frame - _fight_start[n] > 150:
				_run([0, "clear", null])
	while _i < _steps.size() and _frame >= _steps[_i][0]:
		_run(_steps[_i])
		_i += 1


func _single() -> void:
	var s: Array = SHOTS[shot]
	var lvl := get_parent()
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
