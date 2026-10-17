extends Node
## 碰撞探测：把主角放进各个角落，按住方向键/跳跃 1 秒，逐帧记录位置，
## 统计来回抖的次数。用法：Godot --headless --path . -- --probe

const CASES := [
	# [名字, 起点, 按住的动作]
	["上层走进铁箱台阶", Vector2(800, 118), ["solo_right"]],
	["中层顶右墙", Vector2(990, 208), ["solo_right"]],
	["底层顶左墙", Vector2(12, 414), ["solo_left"]],
	["底层顶 Boss 台", Vector2(400, 414), ["solo_right"]],
	["中层往上喷，顶传送带和铁箱的接缝", Vector2(830, 208), ["solo_jump"]],
	["中层往上喷，顶接缝同时往右", Vector2(820, 208), ["solo_jump", "solo_right"]],
	["中层往上喷，顶接缝同时往左", Vector2(840, 208), ["solo_jump", "solo_left"]],
	["右侧缺口往上喷，贴铁箱右面", Vector2(965, 208), ["solo_jump", "solo_left"]],
	["右侧缺口往上喷，贴右墙", Vector2(1000, 208), ["solo_jump", "solo_right"]],
	["上层往上喷顶天花板左角", Vector2(50, 118), ["solo_jump", "solo_left"]],
	["铁箱上往右跳进角落", Vector2(950, 113), ["solo_jump", "solo_right"]],
	["中层左缺口贴墙往上喷", Vector2(4, 300), ["solo_jump", "solo_left"]],
	["中层左缺口贴走道左面往上喷", Vector2(56, 300), ["solo_jump", "solo_right"]],
	["上层边跳边往右撞铁箱", Vector2(815, 118), ["solo_jump", "solo_right"]],
	["中层顶右墙放下马灯", Vector2(1000, 208), ["solo_right", "DROP"]],
	["底层顶Boss台放下马灯", Vector2(416, 414), ["solo_right", "DROP"]],
]

var _case := -1
var _frame := 0
var _log: Array[Vector2] = []
var _floor_flips := 0
var _last_floor := false
var _player: Player
var _drop_at := -1
var _clog: Array[Vector2] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_next()


func _next() -> void:
	if _case >= 0:
		for a in CASES[_case][2]:
			if a != "DROP":
				Input.action_release(a)
		_report()
	_case += 1
	if _case >= CASES.size():
		get_tree().quit()
		return
	_player = get_tree().get_nodes_in_group("player")[0]
	_player.global_position = CASES[_case][1]
	_player.velocity = Vector2.ZERO
	_player.fuel = 1.0
	_frame = 0
	_log.clear()
	_clog.clear()
	_floor_flips = 0
	var c: Crystal = get_tree().get_nodes_in_group("crystal")[0]
	if c.carrier == null:
		c.pick_up(_player, true)
	for a in CASES[_case][2]:
		if a == "DROP":
			_drop_at = 10
		else:
			Input.action_press(a)


func _physics_process(_delta: float) -> void:
	if _case >= CASES.size():
		return
	_frame += 1
	var c: Crystal = get_tree().get_nodes_in_group("crystal")[0]
	if _frame == _drop_at:
		c.drop()
		_drop_at = -1
	if _frame > 40:
		_clog.append(c.global_position)
		_log.append(_player.global_position)
		var f := _player.is_on_floor()
		if f != _last_floor:
			_floor_flips += 1
		_last_floor = f
	if _frame >= 160:
		_next()


func _report() -> void:
	var flips_x := 0
	var flips_y := 0
	var amp := Vector2.ZERO
	for i in range(2, _log.size()):
		var d1 := _log[i - 1] - _log[i - 2]
		var d2 := _log[i] - _log[i - 1]
		if absf(d1.x) > 0.01 and absf(d2.x) > 0.01 and signf(d1.x) != signf(d2.x):
			flips_x += 1
			amp.x = maxf(amp.x, absf(d2.x))
		if absf(d1.y) > 0.01 and absf(d2.y) > 0.01 and signf(d1.y) != signf(d2.y):
			flips_y += 1
			amp.y = maxf(amp.y, absf(d2.y))
	var cj := 0.0
	for i in range(1, _clog.size()):
		cj = maxf(cj, (_clog[i] - _clog[i - 1]).length())
	print("%-28s 马灯最大单帧位移 %.2f 末位置 %s" % ["", cj, _clog[-1].round() if _clog.size() else Vector2.ZERO])
	print("%-28s 末位置 %s  x来回 %d(%.2f)  y来回 %d(%.2f)  落地切换 %d" % [
		CASES[_case][0], _log[-1].round(), flips_x, amp.x, flips_y, amp.y, _floor_flips])
