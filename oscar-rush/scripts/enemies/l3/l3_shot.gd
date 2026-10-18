class_name L3Shot
extends Area2D
## 第三关精英的主题子弹（10-18 作者："第三关好多弹幕都长的一样"）：每只精英打自己那一种，
## 颜色、形状、飞法都跟它的主题走——水塔喷水团、末班车打车灯、落地钟甩齿轮、鮟鱇吐泡泡……
## 一格一格画（1×1 的方块，位置取整），不吃屏幕色调映射和光照，单色屏幕里也认得出。
## 飞法：
##   line  直线
##   arc   抛物线（往下落时才会被地面、平台挡住，和余烬一样）
##   roll  抛物线，落地以后贴着地面往前滚（齿轮、橡子、弹珠），撞墙或滚到台子边掉下去
##   wave  直线往前，上下摆（音符）
##   rise  先往前慢慢漂，再往上浮（泡泡），穿过地形，飘一会儿自己破
##   home  慢、稍微追人（飞蛾）
##   fall  从上往下掉，越掉越快（雨点、碎块）
## 伤害和 Boss 子弹一样走 Player.hurt（有无敌时间）、Crystal.take_hit。

const DAMAGE := 8.0
const GRAVITY := 170.0
const MAX_FALL := 130.0
const ROLL_SPEED := 55.0
const FALL_GRAVITY := 420.0

## 每种子弹：飞法、三档颜色（亮 → 暗）、形状（字符画，数字是颜色档，"." 空；两帧的会交替）、拖尾长度、速度倍数
const STYLES := {
	"water": {"move": "arc", "cols": [Color(0.86, 0.95, 1.0), Color(0.45, 0.7, 1.0), Color(0.25, 0.42, 0.85)],
		"shape": [[".1.", "121", ".3."]], "trail": 3},
	"headlight": {"move": "line", "speed": 1.45, "cols": [Color(1.0, 1.0, 0.85), Color(1.0, 0.88, 0.4), Color(0.95, 0.6, 0.2)],
		"shape": [["2111", "3211"]], "trail": 6, "orient": true},
	"snow": {"move": "arc", "cols": [Color(1, 1, 1), Color(0.82, 0.9, 1.0), Color(0.6, 0.72, 0.9)],
		"shape": [[".1.", "112", ".2."]], "trail": 0},
	"cinder": {"move": "arc", "cols": [Color(1.0, 0.9, 0.5), Color(1.0, 0.55, 0.15), Color(0.6, 0.55, 0.5)],
		"shape": [["12", "21"], ["21", "12"]], "trail": 3, "trail_col": 2},
	"marble": {"move": "roll", "cols": [Color(1, 1, 1), Color(0.95, 0.3, 0.35), Color(0.55, 0.12, 0.2)],
		"shape": [[".1.", "222", ".3."]], "trail": 0, "tint_cycle": true},
	"bulb": {"move": "arc", "cols": [Color(1, 1, 0.9), Color(1.0, 0.85, 0.3), Color(0.55, 0.5, 0.45)],
		"shape": [[".1.", "121", ".3."]], "trail": 2, "tint_cycle": true},
	"ink": {"move": "arc", "cols": [Color(0.95, 0.4, 0.85), Color(0.35, 0.18, 0.45), Color(0.15, 0.08, 0.2)],
		"shape": [[".2.", "232", "1.1"]], "trail": 2},
	"acorn": {"move": "roll", "cols": [Color(0.85, 0.65, 0.35), Color(0.62, 0.42, 0.22), Color(0.35, 0.24, 0.14)],
		"shape": [[".3.", "121", ".2."], [".2.", "123", ".2."]], "trail": 0},
	"flame": {"move": "line", "cols": [Color(1.0, 0.95, 0.6), Color(1.0, 0.6, 0.2), Color(0.85, 0.25, 0.15)],
		"shape": [["12", "23"], ["21", "32"]], "trail": 4, "trail_col": 2},
	"rain": {"move": "fall", "cols": [Color(0.85, 0.95, 1.0), Color(0.5, 0.75, 1.0), Color(0.3, 0.5, 0.85)],
		"shape": [["1", "2", "3"]], "trail": 2},
	## 斜着飞的雨丝：风暴云扇射用（雨点是往下掉的，不管瞄哪；扇射要照预警的射线飞，10-18 自查）
	"drizzle": {"move": "line", "speed": 1.1, "cols": [Color(0.85, 0.95, 1.0), Color(0.5, 0.75, 1.0), Color(0.3, 0.5, 0.85)],
		"shape": [["3..", ".2.", "..1"]], "trail": 3, "orient": true},
	"bubble": {"move": "rise", "cols": [Color(1, 1, 1), Color(0.55, 0.9, 1.0), Color(0.3, 0.6, 0.8)],
		"shape": [[".2.", "2.1", ".2."], [".2.", "1.2", ".3."]], "trail": 0},
	"dust": {"move": "wave", "speed": 0.75, "cols": [Color(0.85, 0.83, 0.78), Color(0.62, 0.6, 0.56), Color(0.42, 0.4, 0.38)],
		"shape": [["121", "2.2"], ["212", ".2."]], "trail": 2, "trail_col": 2},
	"nail": {"move": "line", "speed": 1.3, "cols": [Color(0.95, 0.95, 0.95), Color(0.65, 0.66, 0.7), Color(0.35, 0.35, 0.4)],
		"shape": [["3221", "3..."]], "trail": 2, "orient": true},
	"chalk": {"move": "line", "cols": [Color(1, 1, 1), Color(0.88, 0.88, 0.82), Color(0.6, 0.6, 0.55)],
		"shape": [["112"], ["1.", "1.", "2."]], "trail": 3, "trail_col": 2},
	"ice": {"move": "line", "cols": [Color(1, 1, 1), Color(0.7, 0.92, 1.0), Color(0.4, 0.65, 0.85)],
		"shape": [["12", "23"]], "trail": 2},
	"sand": {"move": "arc", "cols": [Color(1.0, 0.92, 0.7), Color(0.85, 0.72, 0.45), Color(0.6, 0.48, 0.3)],
		"shape": [["12", "23"]], "trail": 2, "trail_col": 1},
	"hanger": {"move": "arc", "cols": [Color(0.92, 0.9, 0.85), Color(0.7, 0.68, 0.62), Color(0.45, 0.43, 0.4)],
		"shape": [[".1.", "2.2", "222"], ["2..", "21.", "222"]], "trail": 0},
	"noise": {"move": "line", "cols": [Color(1, 1, 1), Color(0.7, 0.7, 0.7), Color(0.4, 0.4, 0.4)],
		"shape": [["121", "2.3", "312"], ["213", ".1.", "232"]], "trail": 0, "jitter": true},
	"bars": {"move": "line", "cols": [Color(1.0, 0.95, 0.3), Color(0.3, 0.95, 1.0), Color(1.0, 0.3, 0.8)],
		"shape": [["123", "123", "123"], ["231", "231", "231"]], "trail": 2},
	"moth": {"move": "home", "speed": 0.8, "cols": [Color(1.0, 0.95, 0.75), Color(0.85, 0.78, 0.6), Color(0.5, 0.45, 0.38)],
		"shape": [["1.1", ".3.", "2.2"], [".1.", "131", ".2."]], "trail": 0},
	"gear": {"move": "roll", "cols": [Color(1.0, 0.9, 0.55), Color(0.78, 0.62, 0.3), Color(0.45, 0.35, 0.18)],
		"shape": [[".2.2.", "22222", ".2.2.", "22322", ".2.2."], ["2.2.2", ".222.", "22322", ".222.", "2.2.2"]], "trail": 0},
	"note": {"move": "wave", "cols": [Color(1.0, 0.55, 0.9), Color(0.4, 0.95, 1.0), Color(0.7, 0.3, 0.75)],
		"shape": [["..1", "..1", ".11", "33."]], "trail": 2, "trail_col": 1},
	"rock": {"move": "fall", "cols": [Color(0.8, 0.76, 0.7), Color(0.55, 0.52, 0.48), Color(0.35, 0.33, 0.3)],
		"shape": [[".12", "123", "23."]], "trail": 1},
}
const CYCLE := [Color(0.95, 0.3, 0.35), Color(0.35, 0.6, 1.0), Color(1.0, 0.85, 0.3), Color(0.4, 0.9, 0.5)]

var style := "water"
var velocity := Vector2.ZERO
var arena := Rect2(0, 0, 4000, 2000)
var target: Node2D

var _s: Dictionary
var _life := 0.0
var _done := false
var _rolling := false
var _trail: Array[Vector2] = []
var _seed := 0.0
var _tint := Color.WHITE
var _base_y := 0.0


## from 到 target：line / wave / home / rise 直线瞄过去；arc / roll 算一条 0.9 秒到的抛物线；fall 直接往下
static func fire(parent: Node, style_name: String, from: Vector2, to: Vector2, speed := 88.0) -> L3Shot:
	var b := L3Shot.new()
	b.style = style_name if STYLES.has(style_name) else "water"
	var s: Dictionary = STYLES[b.style]
	var sp: float = speed * s.get("speed", 1.0)
	match s["move"]:
		"arc", "roll":
			var t := 0.9
			b.velocity = Vector2(clampf((to.x - from.x) / t, -140.0, 140.0), (to.y - from.y) / t - 0.5 * GRAVITY * t)
		"fall":
			b.velocity = Vector2(0, 30.0)
		_:
			b.velocity = (to - from).normalized() * sp
	b.position = from
	parent.add_child(b)
	return b


func _ready() -> void:
	_s = STYLES[style]
	collision_layer = 0
	z_index = 8
	_seed = randf() * 10.0
	_base_y = position.y
	if _s.get("tint_cycle", false):
		_tint = CYCLE[randi() % CYCLE.size()]
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 3.0 if style == "gear" else 2.5
	shape.shape = c
	add_child(shape)
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m
	_set_mask()
	body_entered.connect(_on_body)


func _set_mask() -> void:
	var mv: String = _s["move"]
	var terrain := true
	if mv == "rise" or _rolling:
		terrain = false
	elif mv == "arc" or mv == "roll":
		terrain = velocity.y > 0.0
	collision_mask = (1 if terrain else 0) | 2 | 8


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life += delta
	var mv: String = _s["move"]
	match mv:
		"arc", "roll":
			if _rolling:
				_roll(delta)
			else:
				velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
				velocity.x *= 1.0 - 0.15 * delta
		"wave":
			pass
		"rise":
			velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
			velocity.y = move_toward(velocity.y, -45.0, 60.0 * delta)
		"home":
			if is_instance_valid(target):
				var want := (target.global_position + Vector2(0, -8) - global_position).normalized() * velocity.length()
				velocity = velocity.lerp(want, clampf(1.2 * delta, 0.0, 1.0))
		"fall":
			velocity.y = minf(velocity.y + FALL_GRAVITY * delta, 260.0)
	_set_mask()
	_trail.push_front(position)
	if _trail.size() > int(_s.get("trail", 0)) + 1:
		_trail.pop_back()
	position += velocity * delta
	if mv == "wave":
		# 上下摆：只改画的位置不改速度，碰撞跟着走
		position.y += cos(_life * 9.0 + _seed) * 9.0 * 9.0 * delta
	var life_max := 8.0
	if mv == "rise":
		life_max = 3.2
	elif _rolling:
		life_max = 6.0
	if not arena.grow(24.0).has_point(position) or _life > life_max:
		if mv == "rise":
			_pop()
		else:
			queue_free()
	queue_redraw()


## 滚：贴着地面往前，前面是墙就碎，脚下没地就掉下去
func _roll(delta: float) -> void:
	var space := get_world_2d().direct_space_state
	var down := PhysicsRayQueryParameters2D.create(position + Vector2(0, -4), position + Vector2(0, 8), 1)
	var hit := space.intersect_ray(down)
	if hit.is_empty():
		_rolling = false
		velocity.y = 20.0
		return
	position.y = (hit["position"] as Vector2).y - 3.0
	var side := signf(velocity.x) if velocity.x != 0.0 else 1.0
	var wall := PhysicsRayQueryParameters2D.create(position, position + Vector2(side * 5.0, 0), 1)
	if not space.intersect_ray(wall).is_empty():
		_pop()
		return
	velocity = Vector2(side * ROLL_SPEED, 0)


func _on_body(body: Node) -> void:
	if _done:
		return
	var dmg := DAMAGE * EnemyBase.damage_mult()
	if body is Player:
		if not (body as Player).hurt(global_position, dmg):
			return
	elif body is Crystal:
		(body as Crystal).take_hit(global_position, dmg)
	elif _s["move"] == "roll" and not _rolling:
		# 落地开始滚
		_rolling = true
		velocity = Vector2(signf(velocity.x) * ROLL_SPEED if velocity.x != 0.0 else ROLL_SPEED, 0)
		Game.sfx("land", -18.0, 1.8, 0.1)
		return
	_pop()


## 被清场时调（和 BossBullet 一样）
func fizzle(_dir := Vector2.ZERO) -> void:
	if _done:
		return
	_done = true
	Game.sparks(get_parent(), global_position, Color(0.85, 0.85, 0.9), 2, 30.0)
	queue_free()


func _pop() -> void:
	if _done:
		return
	_done = true
	var cols: Array = _s["cols"]
	Game.sparks(get_parent(), global_position, _col(cols[1]), 4, 50.0)
	queue_free()


func _col(c: Color) -> Color:
	if _s.get("tint_cycle", false):
		return c * _tint if c.v < 0.99 else c
	return c


func _draw() -> void:
	var cols: Array = _s["cols"]
	var frames: Array = _s["shape"]
	var fr: Array = frames[int(_life * 10.0 + _seed) % frames.size()]
	var flip: bool = _s.get("orient", false) and velocity.x < 0.0
	# 拖尾：从近到远越来越淡，一格一点
	var tc: int = _s.get("trail_col", 1)
	var snap := position.round() - position
	for i in range(1, _trail.size()):
		var p := (_trail[i] - position).round() + snap
		draw_rect(Rect2(p, Vector2.ONE), Color(_col(cols[tc]), 0.7 * (1.0 - float(i) / _trail.size())))
	var h := fr.size()
	var w: int = (fr[0] as String).length()
	var jit := Vector2.ZERO
	if _s.get("jitter", false):
		jit = Vector2(randi() % 3 - 1, randi() % 3 - 1)
	var origin := Vector2(-w / 2, -h / 2) + jit + snap
	for y in h:
		var row: String = fr[y]
		for x in w:
			var ch := row[w - 1 - x] if flip else row[x]
			if ch == ".":
				continue
			var k := int(ch) - 1
			draw_rect(Rect2(origin + Vector2(x, y), Vector2.ONE), _col(cols[clampi(k, 0, 2)]))
