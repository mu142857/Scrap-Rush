extends Node
## 开始界面截图：标题动画 → 菜单 → 选 CO-OP → 两个人加入。
## 用法：Godot --path . -w --write-movie x.avi --fixed-fps 60 -- --titleshots=<目录>
## 按画面帧数走（每秒 60 帧）。

var out_dir := ""
var _frame := 0
var _i := 0
var _steps: Array = [
	[40, "shot", "t0_dark"],
	[48, "shot", "t1_flicker"],
	[75, "shot", "t2_title"],
	[200, "shot", "t3_menu"],
	[210, "tap", "ui_down"],
	[230, "shot", "t4_coop"],
	[240, "tap", "ui_accept"],
	[300, "shot", "t5_lobby"],
	[310, "tap", "kb_left_jump"],
	[340, "tap", "pad0_jump"],
	[380, "shot", "t6_two_joined"],
	[390, "quit", null],
]
var _release: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 比开始界面先处理，按下的那一帧开始界面才能读到"刚按下"
	process_priority = -10
	DirAccess.make_dir_recursive_absolute(out_dir)


func _process(_delta: float) -> void:
	_frame += 1
	# 按住 3 帧再松开
	for r in _release.duplicate():
		if _frame >= r[1]:
			Input.action_release(r[0])
			_release.erase(r)
	while _i < _steps.size() and _frame >= _steps[_i][0]:
		var s: Array = _steps[_i]
		_i += 1
		match s[1]:
			"tap":
				Input.action_press(s[2])
				_release.append([s[2], _frame + 3])
			"shot":
				_shot(s[2])
			"quit":
				get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
