extends Node
## 结局演出自测（游戏剧情主题讨论会话）：把 boss3 房间当子节点加进来，主角无敌，
## 一直往右走到 Boss 战开始，2 秒后直接打死老电视，一路放到 THE END。截图编号是打死以后的帧数。配合录像看每个镜头：
## Godot --path . -w --write-movie x.avi --fixed-fps 60 scenes/ending_test.tscn
## 加 -- --hp=0.5 或 --hp=0.1 看中档、低档血量的雪花和旁白；加 --shots=<目录> 从打死起每 2 秒截一张；
## 加 --chain 测整条链：结局 → 结算 → 回标题，统计要清零。

## 打死以后再跑多少帧（结局约 40 秒放完）
const AFTER_KILL := 3200

var room: Node
var out_dir := ""
var _f := 0
var _kill_at := -1
## 打死以后这么多帧就退出（只看录像那段时用），默认放完整个结局
var _stop := AFTER_KILL
## --fight=<帧数>：开打以后先让 Boss 打这么多帧再打死，期间每 60 帧截一张（看 Boss 房美术和弹幕）
var _fight := 120


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			out_dir = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(out_dir)
		if arg.begins_with("--fight="):
			_fight = arg.trim_prefix("--fight=").to_int()
		if arg.begins_with("--stop="):
			_stop = arg.trim_prefix("--stop=").to_int()
		if arg.begins_with("--hp="):
			Run.crystal_hp = Run.crystal_max * arg.trim_prefix("--hp=").to_float()
	room = load("res://scenes/boss3.tscn").instantiate()
	add_child(room)
	for arg in OS.get_cmdline_user_args():
		if arg == "--chain":
			# 测整条链：结局 → 结算 → 回标题，统计要清零。观察员挂在根节点上，切场景也不会被删
			Game.run_stats["deaths"] = 2
			Game.run_stats["time"] = 321.0
			Run.parts = 5
			var w := ChainWatcher.new()
			w.room = room
			get_tree().root.add_child.call_deferred(w)
			_stop = 999999


func _process(_delta: float) -> void:
	_f += 1
	for p in get_tree().get_nodes_in_group("player"):
		p.set("_invuln", 0.5)
	var state: int = room.get("_state")
	# 一直往右走，直到 Boss 战真正开始（机器忙的时候加载慢，按固定帧数会落空）
	if _kill_at < 0:
		if state < 2:
			Input.action_press("solo_right")
		else:
			Input.action_release("solo_right")
			_kill_at = _f + _fight
	elif _f < _kill_at and out_dir != "" and (_kill_at - _f) % 60 == 0:
		_shot("f%04d" % (_fight - (_kill_at - _f)))
	if _f == _kill_at:
		var boss: Node = room.get("boss")
		boss.call("hurt", float(boss.get("hp")) + 10.0, Vector2.LEFT, true)
		print("ending_test: boss killed at frame ", _f)
	if _kill_at > 0 and _f >= _kill_at:
		var t := _f - _kill_at
		if out_dir != "" and t % 120 == 0:
			_shot("e%04d" % t)
		if t % 600 == 0:
			print("ending_test: +%d state %s can_quit %s" % [t, state, room.get("_can_quit")])
		if t == _stop:
			get_tree().quit()
	if _f > 20000:
		get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))



class ChainWatcher extends Node:
	var room: Node
	var _t := 0.0
	var _step := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		_t += delta
		var scene := get_tree().current_scene
		var path := scene.scene_file_path if scene else ""
		match _step:
			0:
				if is_instance_valid(room) and room.get("_can_quit"):
					_press()
					_step = 1
					_t = 0.0
					print("chain: THE END done, pressed a key")
			1:
				if path.ends_with("results.tscn") and _t > 1.0:
					print("chain: on results screen, deaths=%d time=%.0f parts=%d" % [Game.run_stats["deaths"], Game.run_stats["time"], Run.parts])
					_press()
					_step = 2
					_t = 0.0
			2:
				# 结算画面先要把一行行亮完、等确认键松开，所以隔一会儿按一下，直到回标题
				if _t > 0.8:
					_press()
					_t = 0.0
				if path.ends_with("title.tscn"):
					_step = 3
					_t = 0.0
			3:
				if _t > 1.0:
					print("chain: back on title, deaths=%d time=%.0f parts=%d crystal=%.0f/%.0f" % [Game.run_stats["deaths"], Game.run_stats["time"], Run.parts, Run.crystal_hp, Run.crystal_max])
					print("chain: OK" if Game.run_stats["deaths"] == 0 and Run.parts == 0 else "chain: STATS NOT RESET")
					get_tree().quit()
		if _t > 60.0:
			print("chain: TIMEOUT at step %d scene %s" % [_step, path])
			get_tree().quit()

	func _press() -> void:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ENTER
		ev.physical_keycode = KEY_ENTER
		ev.pressed = true
		Input.parse_input_event(ev)
		var up := ev.duplicate()
		up.pressed = false
		Input.parse_input_event.call_deferred(up)
