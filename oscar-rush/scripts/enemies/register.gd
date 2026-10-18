class_name CashRegister
extends EliteBase
## 收银机（策划案第九节精英怪 4）：朝主角走。
## 招一"咬"：主角在身前约 40 像素内时冒"!"（0.35 秒，抽屉松开一点在抖），
## 钱箱抽屉猛地弹出去约 14 像素（整台机器同时往前窜 12 像素）再缩回来，抽屉上有判定。
## 招二"找零"：每 4 秒冒"!"、拉一下摇把，往主角那边抛 3 枚硬币，硬币走弧线，碰到伤 8。
## 奖励型：打死"叮"一声，多掉 1 个零件。
## 帧：0、1 走路，2 抽屉松开 3 格（预警），3 抽屉出来 8 格，4 抽屉全出来 14 格，5 抛硬币（摇把拉下）。
## 贴图由 草图/精英怪/export_clock_sew_cash.py 导出。

enum { WALK, BITE_WARN, BITE, TOSS_WARN, RECOVER }

const WALK_SPEED := 22.0
const STOP_DIST := 20.0
const SEE_DIST := 240.0
const WALK_FRAME_TIME := 0.15
# —— 咬 ——
const BITE_RANGE := 40.0
const BITE_HEIGHT := 20.0
const BITE_WARN_TIME := 0.35
## 弹出去、停住、缩回来
const BITE_OUT := 0.06
const BITE_HOLD := 0.14
const BITE_BACK := 0.1
const BITE_RECOVER := 0.45
const BITE_COOLDOWN := 0.9
## 抽屉的判定（朝左时）：全出来时前沿在 -26，半出来时在 -20；机身前脸在 -12
const BITE_RECT_FULL := Rect2(-27, -15, 15, 10)
const BITE_RECT_HALF := Rect2(-21, -15, 9, 10)
const BITE_DAMAGE := 12.0
## 弹抽屉时整台机器往前一窜，不然站在 30~40 像素的主角永远咬不到
const BITE_LUNGE := 12.0
# —— 找零 ——
const TOSS_INTERVAL := 1.6  # 10-18 作者：招和招之间停太久
const TOSS_WARN_TIME := 0.35
const COIN_DAMAGE := 8.0
## 三枚硬币：落点相对主角的水平偏移（往收银机这边为负）和飞行时间
const COINS := [[-16.0, 0.7], [0.0, 0.8], [16.0, 0.9]]
const COIN_REACH := 160.0
## 弹牌窗口（硬币出来的地方）
const COIN_FROM := Vector2(0, -30)

var _state := WALK
var _timer := 0.0
var _toss_t := 2.0
var _bite_cd := 0.0


func _setup() -> void:
	elite_name = "CASH REGISTER"
	intro_title = "NO REFUNDS"
	intro_frame = 4
	fill_alpha = 0.35
	death_time = 1.1
	death_frame = 4
	texture_path = "res://art/enemies/register.png"
	hframes = 6
	frame_size = Vector2i(53, 32)
	body_rect = Rect2(-12, -30, 25, 30)
	led_pixel = Vector2i(27, 4)
	max_hp = 2500.0  # 10-18 作者：血不够，三把武器 20～35 秒
	contact_damage = 10.0


func _tick(delta: float) -> void:
	_timer -= delta
	_bite_cd -= delta
	if _state != TOSS_WARN:
		_toss_t -= delta
	var p := nearest_player(SEE_DIST)
	match _state:
		WALK:
			_walk(p)
			if p and is_on_floor():
				if _bite_cd <= 0.0 and _in_bite_range(p):
					_state = BITE_WARN
					_timer = BITE_WARN_TIME
					velocity.x = 0.0
					warn(BITE_WARN_TIME)
				elif _toss_t <= 0.0:
					_state = TOSS_WARN
					_timer = TOSS_WARN_TIME
					velocity.x = 0.0
					warn(TOSS_WARN_TIME)
					pick_focus(p)      # 双人时每次抛硬币轮着冲一个人
		BITE_WARN:
			_brake(delta)
			set_frame(2 if int(_timer / 0.05) % 2 == 0 else 0)
			if _timer <= 0.0:
				_state = BITE
				_timer = BITE_OUT + BITE_HOLD + BITE_BACK
				Game.sfx("hit", -6.0, 0.6, 0.05)
		BITE:
			var t := BITE_OUT + BITE_HOLD + BITE_BACK - _timer
			if t < BITE_OUT and not is_on_wall() and ground_ahead(14.0):
				velocity.x = dir * BITE_LUNGE / BITE_OUT
			else:
				velocity.x = 0.0
			var full := t >= BITE_OUT and t < BITE_OUT + BITE_HOLD
			set_frame(4 if full else 3)
			_hit_rect(BITE_RECT_FULL if full else BITE_RECT_HALF, BITE_DAMAGE * damage_mult())
			if _timer <= 0.0:
				_state = RECOVER
				_timer = BITE_RECOVER
				_bite_cd = BITE_COOLDOWN * interval_mult()
		TOSS_WARN:
			_brake(delta)
			set_frame(5)
			if _timer <= 0.0:
				_toss(focus_player())
				_state = RECOVER
				_timer = 0.3
		RECOVER:
			_brake(delta)
			if frame != 5 or _timer < 0.15:
				set_frame(0)
			if _timer <= 0.0:
				_state = WALK
	move_and_slide()


func _walk(p: Player) -> void:
	var move := false
	if p:
		var dx := p.global_position.x - global_position.x
		if absf(dx) > 2.0:
			dir = 1 if dx > 0.0 else -1
		move = absf(dx) > STOP_DIST and is_on_floor() and not is_on_wall() and ground_ahead(14.0)
	velocity.x = dir * WALK_SPEED * speed_mult() if move else 0.0
	set_frame(int(_time / WALK_FRAME_TIME) % 2 if move else 0)


## 主角在身前（朝向那边）40 像素内、高度差 20 内
func _in_bite_range(p: Player) -> bool:
	var d := p.global_position - global_position
	return d.x * dir >= 0.0 and absf(d.x) <= BITE_RANGE and absf(d.y) <= BITE_HEIGHT


func _toss(p: Player) -> void:
	_toss_t = TOSS_INTERVAL * interval_mult()
	if p == null or not is_instance_valid(p):
		return
	var dx := p.global_position.x - global_position.x
	if absf(dx) > 2.0:
		dir = 1 if dx > 0.0 else -1
	var from := global_position + COIN_FROM
	for c in COINS:
		var tx := clampf(p.global_position.x + c[0] * dir, global_position.x - COIN_REACH, global_position.x + COIN_REACH)
		var coin := Coin.new()
		coin.position = from
		coin.velocity = Coin.launch(from, Vector2(tx, p.global_position.y - 6.0), c[1])
		coin.damage = COIN_DAMAGE * damage_mult()
		get_parent().add_child(coin)
	Game.sfx("ready", -4.0, 2.4)
	Game.sfx("jump", -12.0, 2.0)


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)


## 朝左时的判定框 r（朝右时镜像），碰到的主角、地上的马灯都挨打
func _hit_rect(r: Rect2, dmg: float) -> void:
	if dir > 0:
		r.position.x = -r.position.x - r.size.x
	var shape := RectangleShape2D.new()
	shape.size = r.size
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, global_position + r.get_center())
	q.collision_mask = 2 | 8
	for hit in get_world_2d().direct_space_state.intersect_shape(q, 8):
		var b: Object = hit["collider"]
		if b is Player:
			(b as Player).hurt(global_position, dmg)
		elif b is Crystal:
			(b as Crystal).take_hit(global_position, dmg)


## 奖励型：打死"叮"一声，多掉 1 个零件
func _on_die() -> void:
	Game.sfx("ready", -2.0, 2.6)
	var part := Encounter.Part.new()
	part.position = aim_point() + Vector2(-dir * 6, 0)
	get_parent().add_child(part)


func _on_respawn() -> void:
	_state = WALK
	_toss_t = 2.0
	_bite_cd = 0.0


## 抛出来的硬币：走抛物线，碰到人或马灯伤一下就没，掉到地上或撞墙就碎，最多飞 3 秒
class Coin:
	extends Area2D

	const GRAVITY := 500.0
	const LIFE := 3.0
	const FACE := Color8(214, 182, 112)
	const EDGE := Color8(140, 112, 70)

	var velocity := Vector2.ZERO
	var damage := 8.0
	var _t := 0.0
	var _done := false

	## 从 from 出发、t 秒后正好到 to 的初速度
	static func launch(from: Vector2, to: Vector2, t: float) -> Vector2:
		return Vector2((to.x - from.x) / t, (to.y - from.y - 0.5 * GRAVITY * t * t) / t)

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1 | 2 | 8
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(3, 3)
		cs.shape = r
		add_child(cs)
		body_entered.connect(_on_body)
		# 黑暗里也要看得见往哪飞：不吃场景压暗
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		velocity.y = minf(velocity.y + GRAVITY * delta, 400.0)
		global_position += velocity * delta
		queue_redraw()

	func _on_body(b: Node) -> void:
		if _done:
			return
		_done = true
		if b is Player:
			(b as Player).hurt(global_position, damage)
		elif b is Crystal:
			(b as Crystal).take_hit(global_position, damage)
		else:
			Game.sparks(get_parent(), global_position, FACE, 3, 40.0)
			Game.sfx("hit", -20.0, 2.6, 0.2)
		queue_free()

	func _draw() -> void:
		# 翻着飞：正面 3×3 和侧面 1×3 来回切
		var o := global_position.round() - global_position
		if int(_t * 12.0) % 2 == 0:
			draw_rect(Rect2(o + Vector2(-1, -1), Vector2(3, 3)), EDGE)
			draw_rect(Rect2(o + Vector2(-1, -1), Vector2(2, 2)), FACE)
		else:
			draw_rect(Rect2(o + Vector2(0, -1), Vector2(1, 3)), FACE)
