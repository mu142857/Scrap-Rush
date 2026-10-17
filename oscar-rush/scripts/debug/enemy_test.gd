extends Node2D
## 新怪的测试场景：把手感测试关（test_level.tscn）整个搬进来，再在上层传送带上放新怪。
## 不改 test_level 本身。哪只怪的脚本已经写好（文件存在）就放哪只。
## 直接打开 scenes/enemy_test.tscn 运行就能玩。
## 自动截图：Godot --path . --write-movie <任意>.avi --fixed-fps 60 res://scenes/enemy_test.tscn -- --enemyshots=<目录>

## [脚本路径, 位置, 额外属性]
const SPAWNS := [
	["res://scripts/enemies/moth.gd", Vector2(230, 70), {}],
	["res://scripts/enemies/moth.gd", Vector2(420, 50), {}],
	["res://scripts/enemies/kettle.gd", Vector2(300, 118), {}],
	["res://scripts/enemies/kettle.gd", Vector2(470, 118), {"flip": true}],
	["res://scripts/enemies/shaver.gd", Vector2(680, 118), {}],
	["res://scripts/enemies/flea.gd", Vector2(780, 118), {}],
]

var level: Node2D
var out_dir := ""
var _i := 0
var _steps: Array = [
	# [秒, 动作, 参数]
	[0.3, "teleport", Vector2(250, 118)],
	[0.6, "shot", "01_start"],
	[1.0, "press", "solo_attack"],
	[2.2, "shot", "02_charging_moth"],
	[2.6, "release", "solo_attack"],
	[2.75, "shot", "03_fire"],
	[3.5, "shot", "04_after"],
	[3.8, "teleport", Vector2(309, 118)],
	[3.85, "kettle_warn", null],
	[4.2, "shot", "05_kettle_warn"],
	[4.75, "shot", "06_steam"],
	[5.1, "shot", "07_steam_push"],
	[5.6, "teleport", Vector2(380, 118)],
	[5.65, "press", "solo_crystal"],
	[5.7, "release", "solo_crystal"],
	[5.75, "press", "solo_right"],
	[6.1, "release", "solo_right"],
	[7.0, "shot", "08_lamp_dropped"],
	[8.0, "shot", "09_moth_on_lamp"],
	[8.4, "teleport", Vector2(600, 118)],
	[9.0, "shot", "10_shaver_flea"],
	[10.0, "shot", "11_shaver_flea"],
	[11.0, "shot", "12_shaver_flea"],
	[11.5, "quit", null],
]


func _ready() -> void:
	level = load("res://scenes/test_level.tscn").instantiate()
	add_child(level)
	for s in SPAWNS:
		if not ResourceLoader.exists(s[0]):
			continue
		var e: Node2D = (load(s[0]) as GDScript).new()
		e.position = s[1]
		e.set("respawn_time", 4.0)
		for k in (s[2] as Dictionary):
			e.set(k, s[2][k])
		level.add_child(e)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--enemyshots="):
			out_dir = arg.trim_prefix("--enemyshots=")
	if out_dir != "":
		process_mode = Node.PROCESS_MODE_ALWAYS
		DirAccess.make_dir_recursive_absolute(out_dir)
	else:
		set_process(false)


func _process(_delta: float) -> void:
	# --fixed-fps 60 下按画面帧数算时间
	var t := Engine.get_process_frames() / 60.0
	while _i < _steps.size() and t >= _steps[_i][0]:
		_run(_steps[_i], t)
		_i += 1


func _run(step: Array, t: float) -> void:
	match step[1]:
		"press":
			Input.action_press(step[2])
		"release":
			Input.action_release(step[2])
		"teleport":
			for p in get_tree().get_nodes_in_group("player"):
				p.global_position = step[2]
				p.velocity = Vector2.ZERO
		"kettle_warn":
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Kettle:
					e.set("_state_t", 99.0)
		"shot":
			_shot(step[2], t)
		"quit":
			await RenderingServer.frame_post_draw
			get_tree().quit()


func _shot(name: String, t: float) -> void:
	var pl: Node2D = get_tree().get_nodes_in_group("player")[0]
	var line := "[enemytest] %s t=%.2f player=%s v=%s emotion=%.0f |" % [
		name, t, pl.global_position.round(), (pl as CharacterBody2D).velocity.round(), Run.emotion]
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is EnemyBase:
			line += " %s%s st=%s f=%d hp=%.0f%s" % [e.get_script().resource_path.get_file().get_basename(),
				(e as Node2D).global_position.round(), e.get("state"), e.frame, e.hp, " dead" if e.dead else ""]
	print(line)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
