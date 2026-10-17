extends Node
## 沿路线走一遍，到点截图，看碰撞是不是贴着地面、提示牌对不对。
## 用法：Godot --path . -w --write-movie /tmp/x.avi --fixed-fps 60 -- --tour=<截图目录>
## 窗口被挡住时 frame_post_draw 不来、截图会是空的或旧的，那就从 avi 里按帧抽：
## 物理每秒 120 帧、录像 60 帧，第 N 个物理帧 ≈ 录像第 N/2 帧。
## 打开了 F3 碰撞框。按物理帧数走（每秒 120 帧），不看真实时间。

var out_dir := ""
var _frame := 0
var _i := 0
var _steps: Array = [
	# [物理帧, 动作, 参数]
	[40, "shot", "01_start"],
	[42, "teleport", Vector2(860, 118)],
	[44, "press", "solo_right"],
	[100, "shot", "02_right_end"],
	[220, "shot", "03_on_box"],
	[330, "shot", "04_dropping"],
	[400, "release", "solo_right"],
	[440, "shot", "05_mid_landed"],
	[442, "teleport", Vector2(140, 208)],
	[444, "press", "solo_left"],
	[520, "shot", "06_mid_left"],
	[640, "shot", "07_mid_drop"],
	[700, "release", "solo_left"],
	[760, "shot", "08_bottom_landed"],
	[762, "press", "solo_right"],
	[900, "shot", "09_pit"],
	[1080, "shot", "10_cabinet"],
	[1082, "release", "solo_right"],
	[1084, "teleport", Vector2(300, 405)],
	[1110, "shot", "11_machine"],
	[1112, "teleport", Vector2(395, 414)],
	[1150, "shot", "12_jet_hint"],
	[1152, "teleport", Vector2(436, 354)],
	[1180, "shot", "13_pillar"],
	[1182, "teleport", Vector2(500, 343)],
	[1210, "shot", "14_boss_top"],
	[1220, "quit", null],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_parent().set("_debug", true)
	get_parent().queue_redraw()


func _physics_process(_delta: float) -> void:
	_frame += 1
	while _i < _steps.size() and _frame >= _steps[_i][0]:
		_run(_steps[_i])
		_i += 1


func _run(step: Array) -> void:
	var players := get_tree().get_nodes_in_group("player")
	match step[1]:
		"press":
			Input.action_press(step[2])
		"release":
			Input.action_release(step[2])
		"shot":
			var p: Node2D = players[0]
			print("[tour] %s player=%s floor=%s" % [step[2], p.global_position, p.call("is_on_floor")])
			var path := out_dir.path_join(step[2] + ".png")
			RenderingServer.frame_post_draw.connect(func() -> void:
				get_viewport().get_texture().get_image().save_png(path), CONNECT_ONE_SHOT)
		"teleport":
			for p in players:
				p.global_position = step[2]
				p.velocity = Vector2.ZERO
		"quit":
			get_tree().quit()
