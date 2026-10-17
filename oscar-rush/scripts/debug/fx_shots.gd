extends Node
## 慢动作连拍，看一闪而过的特效（蓄力缩一下、起跳尘土）。
## 用法：Godot --path . -w --write-movie <任意>.avi --fixed-fps 60 -- --fx=<截图目录>
## 时间放慢到 0.15 倍，按画面帧数（每秒 60 帧）走时间表，截下来的是主角附近放大的局部。
## 一定要带 --write-movie：窗口被挡住时普通截图拿到的是旧画面。

const SLOW := 0.15
var out_dir := ""
var _start := 0
var _i := 0
var _steps: Array = [
	[0.1, "press", "solo_right"],
	[0.25, "release", "solo_right"],
	[0.3, "press", "solo_jump"],
	[0.75, "shot", "jet_n0"],
	[0.9, "shot", "jet_n1"],
	[1.05, "shot", "jet_n2"],
	[1.2, "release", "solo_jump"],
	[1.25, "shot", "jet_n3"],
	[1.5, "quit", null],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)


func _process(_delta: float) -> void:
	_start += 1
	var t := _start / 60.0
	while _i < _steps.size() and t >= _steps[_i][0]:
		var s: Array = _steps[_i]
		_i += 1
		match s[1]:
			"slow":
				Engine.time_scale = SLOW
			"press", "release":
				# solo_xxx 同时按给多人的各个方案，--players=4 时四个人一起动
				var act: String = s[2]
				for prefix in ["solo", "kb_left", "kb_right", "pad0", "pad1"]:
					var a := act.replace("solo_", prefix + "_")
					if s[1] == "press":
						Input.action_press(a)
					else:
						Input.action_release(a)
			"shot":
				_shot(s[2])
			"hide", "show":
				for n in get_tree().get_nodes_in_group(s[2]):
					(n as CanvasItem).visible = s[1] == "show"
			"quit":
				get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var p0: Player = get_tree().get_nodes_in_group("player")[0]
	print("[fx] %s charging=%s charge=%.2f squash=%.2f scale=%s attack_held=%s ts=%.2f" % [name, p0.charging, p0.charge,
		p0.get("_squash"), p0.get("_body").scale, Input.is_action_pressed("solo_attack"), Engine.time_scale])
	var img := get_viewport().get_texture().get_image()
	var pl: Node2D = get_tree().get_nodes_in_group("player")[0]
	var screen := pl.get_global_transform_with_canvas().origin
	var k := img.get_width() / 480.0
	var r := Rect2i(Vector2i((screen + Vector2(-30, -55)) * k), Vector2i(Vector2(110, 90) * k))
	var crop := img.get_region(r)
	crop.resize(110 * 4, 90 * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png(out_dir.path_join(name + ".png"))
