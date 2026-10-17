extends Node
## Boss 战自动试玩截图：走进去触发开场 → 看它出几轮招 → 切到二阶段 → 三阶段 → 打死，沿途截图。
## 主角一直无敌（免得中途水晶碎了重开）。按画面帧数走（每秒 60 帧）。
## 用法：Godot --path . -w --write-movie x.avi --fixed-fps 60 -- --bossshots=<目录>

var out_dir := ""
var _frame := 0
var _i := 0
var _steps: Array = [
	[5, "press", "solo_right"],
	[30, "shot", "b00_enter"],
	[48, "release", "solo_right"],
	[62, "shot", "b01_gate"],
	[120, "shot", "b02_zoom"],
	[200, "shot", "b03_wake"],
	[270, "shot", "b04_card"],
	[400, "shot", "b05_fight"],
	[460, "shot", "b06"],
	[520, "shot", "b07"],
	[580, "shot", "b08"],
	[640, "shot", "b09"],
	[700, "shot", "b10"],
	[760, "shot", "b11"],
	[800, "phase", 0.6],
	[860, "shot", "b20_p2"],
	[940, "shot", "b21"],
	[1020, "shot", "b22"],
	[1100, "shot", "b23"],
	[1180, "shot", "b24"],
	[1220, "phase", 0.3],
	[1290, "shot", "b30_p3"],
	[1370, "shot", "b31"],
	[1450, "shot", "b32"],
	[1530, "shot", "b33"],
	[1610, "shot", "b34"],
	[1690, "shot", "b35"],
	[1720, "kill", null],
	[1735, "shot", "b40_kill"],
	[1780, "shot", "b41"],
	[1840, "shot", "b42"],
	[1960, "shot", "b43_memories"],
	[2100, "shot", "b44"],
	[2400, "shot", "b45_open"],
	[2420, "quit", null],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -10
	DirAccess.make_dir_recursive_absolute(out_dir)


func _process(_delta: float) -> void:
	_frame += 1
	for p in get_tree().get_nodes_in_group("player"):
		p.set("_invuln", 0.5)
	var boss: Stoker = get_parent().get("boss")
	while _i < _steps.size() and _frame >= _steps[_i][0]:
		var s: Array = _steps[_i]
		_i += 1
		match s[1]:
			"press":
				Input.action_press(s[2])
			"release":
				Input.action_release(s[2])
			"shot":
				_shot(s[2])
			"phase":
				boss.hurt(boss.hp - boss.max_hp * float(s[2]) + 1.0, Vector2.LEFT, true)
			"kill":
				boss.hurt(boss.hp + 10.0, Vector2.LEFT, true)
			"quit":
				get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
