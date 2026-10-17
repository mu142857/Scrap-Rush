extends Node
## 第三关自检：把 1P 依次放到起点、第一块屏幕、第一个洞底下（按住跳往上爬）、家门口，打印位置。
## 配合录像截图：Godot --path . -w --write-movie /tmp/l3.avi --fixed-fps 60 scenes/level3.tscn -- --l3check
## 然后 ffmpeg 按帧抽图（每一步停 90 帧，截图在每步的第 80 帧左右）。

const D := preload("res://scripts/levels/level3_data.gd")
const STEP := 90

var _f := 0
var _p: Player
var _climb_from := 0.0


func _process(_delta: float) -> void:
	if _p == null:
		for n in get_tree().get_nodes_in_group("player"):
			_p = n as Player
		return
	_f += 1
	var step := _f / STEP
	var t := _f % STEP
	var jump := _p.input_prefix + "_jump"
	var right := _p.input_prefix + "_right"
	if t == 1:
		match step:
			1:
				var r: Array = D.SCREENS[0]["rect"]
				_put(Vector2((r[0] + r[2]) * 0.5, D.SCREENS[0]["floor"]))
			2:
				var sh: Rect2 = D.SHAFTS[0]
				_put(Vector2(sh.get_center().x, sh.end.y))
				_climb_from = sh.end.y
				Input.action_press(jump)
			4:
				Input.action_release(jump)
				print("climb: from y=%d to y=%d (shaft top %d)" % [_climb_from, _p.global_position.y, D.SHAFTS[0].position.y])
				var r2: Array = D.SCREENS[D.SCREENS.size() - 1]["rect"]
				_put(Vector2(D.END.x - 60, D.END.y))
			5:
				Input.action_press(right)
			7:
				Input.action_release(right)
				print("end step: player at ", _p.global_position, " exit ", D.END)
	if t == 45 or t == 85:
		var cam := get_viewport().get_camera_2d()
		print("step %d frame %d pos %s on_floor %s | cam %s zoom %.2f" % [step, _f, _p.global_position, _p.is_on_floor(), cam.global_position.round(), cam.zoom.x])


func _put(pos: Vector2) -> void:
	_p.global_position = pos + Vector2(0, -2)
	_p.velocity = Vector2.ZERO
	if _p.crystal:
		_p.crystal.global_position = _p.global_position
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("snap"):
		cam.snap()
