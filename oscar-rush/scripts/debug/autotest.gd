extends Node
## 自动试玩 + 截图，给 Claude 看画面用。
## 用法：Godot --path . -- --autotest=<截图目录>
## 按时间表模拟按键，到点存一张截图，跑完自动退出。

var out_dir := ""
var _t := 0.0
var _start := -1
var _i := 0
var _steps: Array = [
	# [秒, 动作, 参数]
	[0.4, "shot", "01_start"],
	[0.5, "press", "solo_right"],
	[1.5, "shot", "02_walk"],
	[1.6, "press", "solo_attack"],
	[1.63, "shot", "03a_squash"],
	[1.68, "shot", "03b_squash"],
	[2.0, "shot", "03_charging"],
	[2.55, "shot", "04_full"],
	[2.6, "release", "solo_attack"],
	[2.68, "shot", "05_fire"],
	[2.85, "shot", "06_hit"],
	[3.15, "shot", "06b_after_hit"],
	[3.4, "press", "solo_jump"],
	[3.47, "shot", "07a_dust"],
	[3.6, "shot", "07_jump"],
	[4.2, "shot", "08_jet"],
	[4.6, "release", "solo_jump"],
	[4.7, "release", "solo_right"],
	[5.4, "press", "solo_crystal"],
	[5.45, "release", "solo_crystal"],
	[5.5, "press", "solo_left"],
	[6.2, "release", "solo_left"],
	[6.3, "shot", "09_dropped"],
	[6.35, "press", "solo_right"],
	[6.95, "release", "solo_right"],
	[7.0, "press", "solo_crystal"],
	[7.05, "release", "solo_crystal"],
	[7.1, "shot", "10_picked"],
	[7.2, "teleport", Vector2(950, 113)],
	[7.3, "press", "solo_right"],
	[7.75, "shot", "11_falling"],
	[8.3, "shot", "12_landed"],
	[8.35, "release", "solo_right"],
	[8.4, "near_enemy", null],
	[8.6, "shot", "13_hurt"],
	[9.1, "shot", "14_after_hurt"],
	[9.3, "quit", null],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)


func _process(_delta: float) -> void:
	# 用真实时间，顿帧不影响时间表
	if _start < 0:
		_start = Time.get_ticks_msec()
	_t = (Time.get_ticks_msec() - _start) / 1000.0
	while _i < _steps.size() and _t >= _steps[_i][0]:
		_run(_steps[_i])
		_i += 1


func _run(step: Array) -> void:
	match step[1]:
		"press":
			Input.action_press(step[2])
		"release":
			Input.action_release(step[2])
		"shot":
			_shot(step[2])
		"teleport":
			for p in get_tree().get_nodes_in_group("player"):
				p.global_position = step[2]
				p.velocity = Vector2.ZERO
		"near_enemy":
			var p: Node2D = get_tree().get_nodes_in_group("player")[0]
			var best: Node2D = null
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.call("is_targetable") and absf(e.global_position.y - p.global_position.y) < 4.0:
					if best == null or e.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position):
						best = e
			if best:
				p.global_position = best.global_position + Vector2(-16, 0)
		"quit":
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_tree().quit()


func _shot(name: String) -> void:
	var pl: Node2D = get_tree().get_nodes_in_group("player")[0]
	var cr = get_tree().get_nodes_in_group("crystal")[0]
	print("[autotest] %s t=%.2f time_scale=%.2f paused=%s player=%s carrier=%s fps=%d" % [
		name, _t, Engine.time_scale, get_tree().paused, pl.global_position.round(), cr.carrier != null, Engine.get_frames_per_second()])
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
