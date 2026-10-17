extends Node
## 量跳跃弧线：在底层地面上先跑到满速，再按住跳跃一段时间松开，记录跳多高、飞多远。
## 用法：Godot --headless --path . -- --arc

## 中层桁架走道，又长又平
const START := Vector2(200, 208)
## [名字, 按住跳跃多少秒, 提不提灯]
const CASES := [
	["空手 点一下", 0.0, false],
	["空手 满按", 0.25, false],
	["提灯 点一下", 0.0, true],
	["提灯 满按", 0.25, true],
]

var _case := -1
var _t := 0.0
var _phase := 0
var _player: Player
var _crystal: Crystal
var _x0 := 0.0
var _y0 := 0.0
var _top := 0.0
var _air := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().physics_frame
	_player = get_tree().get_nodes_in_group("player")[0]
	_crystal = get_tree().get_nodes_in_group("crystal")[0]
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	_next()


func _next() -> void:
	Input.action_release("solo_right")
	Input.action_release("solo_jump")
	_case += 1
	if _case >= CASES.size():
		get_tree().quit()
		return
	if CASES[_case][2] and _crystal.carrier == null:
		_crystal.pick_up(_player, true)
	elif not CASES[_case][2] and _crystal.carrier != null:
		_crystal.drop()
		_crystal.global_position = Vector2(150, 400)
	_player.global_position = START
	_player.velocity = Vector2.ZERO
	_t = 0.0
	_phase = 0
	Input.action_press("solo_right")


func _physics_process(delta: float) -> void:
	if _player == null or _case >= CASES.size():
		return
	_t += delta
	match _phase:
		0:  # 先跑 0.4 秒到满速
			if _t > 0.4 and _player.is_on_floor():
				_x0 = _player.global_position.x
				_y0 = _player.global_position.y
				_top = _y0
				_air = 0.0
				Input.action_press("solo_jump")
				_phase = 1
				_t = 0.0
		1:
			_air += delta
			_top = minf(_top, _player.global_position.y)
			if _t >= CASES[_case][1] and Input.is_action_pressed("solo_jump"):
				Input.action_release("solo_jump")
			if _t > 0.05 and _player.is_on_floor():
				var h := _y0 - _top
				var w := _player.global_position.x - _x0
				print("%-10s 高 %5.1f  远 %5.1f  空中 %.2f 秒  宽/高 %.1f  跑速 %.0f" % [
					CASES[_case][0], h, w, _air, w / maxf(h, 0.1), absf(_player.velocity.x)])
				_next()
