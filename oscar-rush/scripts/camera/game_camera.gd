class_name GameCamera
extends Camera2D
## 跟所有玩家的镜头。像素画不缩放，只平移。
## - 主角放在画面中间略偏上，往移动方向多看 60 像素
## - 跳起来时镜头不上下晃（照 Phage：只跟落地时的高度）
## - 往下掉得快时镜头提前往下看 60 像素，先看到落点
## - 多人时跟所有人的中心，提灯的人权重加倍

const LOOK_AHEAD := 60.0
const LOOK_AHEAD_SPEED := 3.0
const FOCUS_OFFSET := Vector2(0, 15)
const FOLLOW_X_SPEED := 9.0
const FOLLOW_Y_SPEED := 5.0
const FALL_CATCHUP := 16.0
const FALL_LOOK_DOWN := 60.0
const FALL_LOOK_SPEED := 160.0
const EDGE_MARGIN := 24.0

var bounds := Rect2(0, 0, 480, 270)

var _look := 0.0
var _look_down := 0.0
var _ground_y := 0.0
var _has_ground := false


func _ready() -> void:
	make_current()


## 第一帧直接对准，不从原点滑过来
func snap() -> void:
	_has_ground = false
	_process(0.0)
	global_position = _target_position()


func _process(delta: float) -> void:
	var players := _players()
	if players.is_empty():
		return
	var lead := _lead(players)
	var k_look := 1.0 - exp(-LOOK_AHEAD_SPEED * delta)
	_look = lerpf(_look, lead.facing * LOOK_AHEAD, k_look)

	var falling := not lead.is_on_floor() and lead.velocity.y > FALL_LOOK_SPEED
	_look_down = move_toward(_look_down, FALL_LOOK_DOWN if falling else 0.0, delta * (180.0 if falling else 90.0))

	var target := _target_position()
	var pos := global_position
	pos.x = lerpf(pos.x, target.x, 1.0 - exp(-FOLLOW_X_SPEED * delta))
	var y_speed := FOLLOW_Y_SPEED * (2.0 if falling else 1.0)
	pos.y = lerpf(pos.y, target.y, 1.0 - exp(-y_speed * delta))

	# 保底：不管镜头追得多慢，玩家都不能出画面
	var half := get_viewport_rect().size * 0.5
	for p in players:
		var feet := p.global_position.y
		pos.y = clampf(pos.y, feet - half.y + EDGE_MARGIN, feet - 20.0 + half.y - EDGE_MARGIN)
	global_position = _clamp_to_bounds(pos, half)
	offset = (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * Game.shake).round()


func _target_position() -> Vector2:
	var players := _players()
	if players.is_empty():
		return global_position
	var lead := _lead(players)
	var focus := Vector2.ZERO
	var weight := 0.0
	for p in players:
		var w := 2.0 if p.crystal else 1.0
		focus += p.global_position * w
		weight += w
	focus /= weight

	var target_y: float
	if players.size() == 1:
		var grounded := lead.is_on_floor()
		if grounded or not _has_ground:
			_ground_y = lead.global_position.y
			_has_ground = true
		target_y = _ground_y
		if not grounded and lead.global_position.y - _ground_y > FALL_CATCHUP:
			target_y = lead.global_position.y - FALL_CATCHUP
	else:
		target_y = focus.y
	var half := get_viewport_rect().size * 0.5
	return _clamp_to_bounds(Vector2(focus.x + _look, target_y + _look_down) + FOCUS_OFFSET, half)


func _clamp_to_bounds(pos: Vector2, half: Vector2) -> Vector2:
	var out := pos
	if bounds.size.x <= half.x * 2.0:
		out.x = bounds.get_center().x
	else:
		out.x = clampf(out.x, bounds.position.x + half.x, bounds.end.x - half.x)
	if bounds.size.y <= half.y * 2.0:
		out.y = bounds.get_center().y
	else:
		out.y = clampf(out.y, bounds.position.y + half.y, bounds.end.y - half.y)
	return out


func _players() -> Array[Player]:
	var out: Array[Player] = []
	for n in get_tree().get_nodes_in_group("player"):
		if n is Player:
			out.append(n)
	return out


## 镜头的朝向和落地高度跟谁：提灯的人，没人提灯就第一个玩家
func _lead(players: Array[Player]) -> Player:
	for p in players:
		if p.crystal:
			return p
	return players[0]
