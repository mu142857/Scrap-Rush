class_name HoodedOperator
extends EnemyBase
## 接线员（第二关披袍人形小怪，近战，血 200）：灰紫长袍拖地、尖帽兜前面伸着一个老式接线员话筒，
## 袖子里垂着一盘电话线。慢慢朝主角飘过去，够得着就把电话线当鞭子甩出去。
## - 甩：主角在前方 56 像素、上下 20 像素以内 → 抡起来 0.45 秒（手举到脑后，线在头顶绕一圈）
##   → 往前甩直 0.3 秒，线贴着腰的高度伸出去（地面往上 9～15 格），碰到伤 10。跳过去或者退开都能躲。
## - 抡的时候挨一下蓄满的光球就打断。
## 帧：0~3 走（下摆拖地飘），4 抡，5 甩。贴图由 草图/小怪/l2_robed.py 导出。
## 电话线甩出去那一下是代码画的（不吃压暗，暗处也看得见要躲的东西）。

enum { WALK, WINDUP, LASH, RECOVER }

const WALK_SPEED := 26.0
const WALK_FRAME_TIME := 0.15
const REACH := 56.0
const REACH_Y := 20.0
const WINDUP_TIME := 0.45
const LASH_TIME := 0.3
const RECOVER_TIME := 0.5
const COOLDOWN := 1.4
const LASH_DAMAGE := 10.0
## 甩直时手的位置（原图朝左，相对脚底中点），线的高度范围（地面往上）
const HAND := Vector2(-11, -13)
const CORD_Y := Vector2(-15, -9)
const CORD_COLOR := Color(0.78, 0.72, 0.8)
const PLUG_COLOR := Color(1.0, 0.8, 0.45)

var _state := WALK
var _timer := 0.0
var _cool := 0.6
var _hit_done := false
var _cord: Node2D


func _setup() -> void:
	texture_path = "res://art/enemies/hooded_operator.png"
	hframes = 8
	frame_size = Vector2i(22, 27)
	body_rect = Rect2(-7, -24, 14, 24)
	# led_pixel 是前面那只眼睛：LivingFx 把红灯换成两只会眨、会看人的暖白眼睛（是活人，不是机器）
	led_pixel = Vector2i(8, 6)
	led_by_frame = {1: Vector2i(8, 5), 2: Vector2i(8, 5), 4: Vector2i(9, 6), 5: Vector2i(7, 6), 6: Vector2i(9, 6),
			7: Vector2i(8, 18)}
	max_hp = 130.0  # 10-18 按每场同屏怪数重平衡（作者：一关比一关难），原来 200；表见 夜间打磨/商店经济压力马灯_报告.md 第 27 节
	contact_damage = 10.0
	knockback = Vector2(60.0, 25.0)
	# 活人：死的时候是倒地的闷响，溅出来的是灰紫的袍子碎片和灰（不是金属碎屑）
	death_sfx = "land"
	death_sfx_pitch = 0.6
	death_spark_colors = [Color8(132, 120, 136), Color8(104, 96, 92)]


func _after_ready() -> void:
	_unstick()
	# 活物感：会眨的眼睛、挨打后仰（帧 6）、死了瘫倒（帧 7）、暗处亮层
	LivingFx.attach(self, 6, 7)
	_cord = Node2D.new()
	_cord.z_index = 3
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_cord.material = unshaded
	_cord.draw.connect(_draw_cord)
	add_child(_cord)


## 出生时头顶卡在天花板里就往下挪（遭遇战有统一处理，天桥画框里走出来的也保险一下）
func _unstick() -> void:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _shape.shape
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	# 往下最多挪到原来脚底下那块地面（不能穿过地板，碰撞会话 10-18 报过整只掉出地图）
	var floor_d := 80.0
	var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -1), global_position + Vector2(0, 82), 1)
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		floor_d = (hit.position as Vector2).y - global_position.y
	# 先原地、往上一点（脚压进了地面、斜坡），再左右挪（身子侧面插进柱子、墙），最后往下（头顶卡进天花板）
	var tries: Array[Vector2] = []
	for dy in [0.0, -1.0, -2.0, -3.0, -4.0, -6.0, -8.0]:
		tries.append(Vector2(0, dy))
	for dx in [2.0, 4.0, 6.0, 8.0, 12.0, 16.0]:
		for dy in [0.0, -2.0, -4.0]:
			tries.append(Vector2(dx, dy))
			tries.append(Vector2(-dx, dy))
	var d := 2.0
	while d <= floor_d:
		tries.append(Vector2(0, d))
		d += 2.0
	for t in tries:
		q.transform = Transform2D(0.0, global_position + t + _shape.position)
		if space.intersect_shape(q, 1).is_empty():
			global_position += t
			return
	# 都不行：留在原地，交给物理把它挤出来


func _tick(delta: float) -> void:
	_timer -= delta
	_cool -= delta
	match _state:
		WALK:
			_walk(delta)
			var p := nearest_player()
			if p and _cool <= 0.0 and is_on_floor():
				var d := p.global_position - global_position
				if absf(d.x) <= REACH and absf(d.y) <= REACH_Y and signf(d.x) == float(dir):
					_state = WINDUP
					_timer = WINDUP_TIME
					velocity.x = 0.0
					Game.sfx("dial", -12.0, 1.6, 0.1)
		WINDUP:
			_brake(delta)
			set_frame(4)
			if _timer <= 0.0:
				_state = LASH
				_timer = LASH_TIME
				_hit_done = false
				Game.sfx("whistle", -10.0, 1.8, 0.1)
				Game.sfx("scrape", -12.0, 1.5)
		LASH:
			_brake(delta)
			set_frame(5)
			if not _hit_done:
				_lash_hit()
			if _timer <= 0.0:
				_state = RECOVER
				_timer = RECOVER_TIME
		RECOVER:
			_brake(delta)
			set_frame(0)
			if _timer <= 0.0:
				_state = WALK
				_cool = COOLDOWN * interval_mult()
	move_and_slide()
	_cord.queue_redraw()


func _walk(delta: float) -> void:
	var p := nearest_player()
	var move := 0.0
	if p:
		var dx := p.global_position.x - global_position.x
		if absf(dx) > 2.0:
			dir = 1 if dx > 0.0 else -1
		if absf(dx) > REACH * 0.6:
			move = dir
	if move != 0.0 and is_on_floor() and (not _ground_at(move) or _wall_at(move)):
		move = 0.0
	if not is_knocked():
		velocity.x = move_toward(velocity.x, move * WALK_SPEED * speed_mult(), 400.0 * delta)
	if absf(velocity.x) > 2.0:
		set_frame(int(_time / WALK_FRAME_TIME) % 4)
	else:
		set_frame(int(_time / (WALK_FRAME_TIME * 2.0)) % 2 * 3)


func _brake(delta: float) -> void:
	if not is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)


## 线伸出去多长（甩出去 0.08 秒伸满，最后 0.08 秒收回）
func _cord_len() -> float:
	var t := LASH_TIME - _timer
	return REACH * clampf(minf(t / 0.08, _timer / 0.08), 0.0, 1.0)


## 甩直时手的世界坐标（原图朝左，朝右时镜像）
func _hand() -> Vector2:
	return global_position.round() + Vector2(HAND.x * -dir, HAND.y)


func _lash_hit() -> void:
	var cl := _cord_len()
	if cl < 8.0:
		return
	var hand := _hand()
	var x0 := minf(hand.x, hand.x + dir * cl)
	var r := Rect2(x0, global_position.y + CORD_Y.x, cl, CORD_Y.y - CORD_Y.x)
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p and r.intersects(Rect2(p.global_position + Vector2(-3, -16), Vector2(6, 16))):
			if p.hurt(hand, LASH_DAMAGE * damage_mult()):
				_hit_done = true
				Game.sparks(get_parent(), p.global_position + Vector2(0, -10), PLUG_COLOR, 4, 50.0)


## 甩：一盘线从手里伸出去，一格上一格下像弹簧，线头是黄铜插头；抡的时候线在头顶甩一圈
func _draw_cord() -> void:
	if dead:
		return
	# 画的是世界坐标的点，换成 _cord 自己的坐标
	var o := -global_position
	if _state == WINDUP:
		# 线在脑后甩圈：6 个点沿着一段圆弧转，最后一个是插头
		var k := 1.0 - _timer / WINDUP_TIME
		var c := global_position.round() + Vector2(-dir * 6.0, -26.0)
		var a := -PI / 2.0 + dir * k * TAU * 1.2
		for i in 6:
			var ang := a - dir * i * 0.35
			var p := (c + Vector2(cos(ang), sin(ang)) * (4.0 + i * 1.2)).round()
			_cord.draw_rect(Rect2(p + o, Vector2.ONE), CORD_COLOR if i < 5 else PLUG_COLOR)
		return
	if _state != LASH:
		return
	var cl := _cord_len()
	var hand := _hand()
	for i in int(cl):
		var x := hand.x + dir * i
		var y := hand.y + (0.0 if i % 3 == 0 else (-1.0 if i % 3 == 1 else 1.0))
		_cord.draw_rect(Rect2(Vector2(x, y) + o, Vector2.ONE), CORD_COLOR)
	var tip := hand + Vector2(dir * cl, 0)
	_cord.draw_rect(Rect2(tip + o + Vector2(0 if dir > 0 else -2, -1), Vector2(3, 3)), PLUG_COLOR)


func _on_hurt(_damage: float, full: bool) -> void:
	if full and _state == WINDUP:
		_state = RECOVER
		_timer = RECOVER_TIME
		Game.sfx("hit", -10.0, 1.4)


func _ground_at(side: float) -> bool:
	var from := global_position + Vector2(side * 8.0, -2)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _wall_at(side: float) -> bool:
	var from := global_position + Vector2(0, -8)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(side * 10.0, 0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _on_respawn() -> void:
	_state = WALK
	_cool = 0.6
