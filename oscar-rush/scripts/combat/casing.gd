class_name Casing
extends Node2D
## 铆钉枪抛出来的一颗弹壳（照合金弹头重机枪的手感）：往身后上方弹出去，落地弹一下、轻轻"叮"一声，躺一会儿淡掉。
## 不做物理碰撞：落地高度就是开枪时主角脚底的高度，便宜。

const GRAVITY := 520.0
const LIFE := 1.1
## 每隔几颗才响一次"叮"，连发时不吵
const SOUND_EVERY := 3

static var _count := 0

var velocity := Vector2.ZERO
var ground_y := 0.0
## 颜色和大小（10-18：霰弹枪抛的是大红弹壳，每颗都"叮"）
var brass := Color(0.86, 0.68, 0.32)
var dark := Color(0.55, 0.4, 0.18)
var big := false
var ding_always := false
var _t := 0.0
var _bounces := 0
var _spin := 0


func _ready() -> void:
	z_index = 6
	_count += 1


func _process(delta: float) -> void:
	_t += delta
	if _bounces < 2:
		velocity.y += GRAVITY * delta
		position += velocity * delta
		_spin += 1
		if position.y >= ground_y and velocity.y > 0.0:
			position.y = ground_y
			_bounces += 1
			velocity = Vector2(velocity.x * 0.45, -absf(velocity.y) * 0.35)
			if _bounces == 1 and (ding_always or _count % SOUND_EVERY == 0):
				Game.sfx("casing", -24.0 if not big else -18.0, 1.0 if not big else 0.75, 0.12)
			if _bounces >= 2:
				velocity = Vector2.ZERO
				# 10-19：躺到地上以后退到角色后面（和血迹斑点同一层，见 splatter.gd）
				z_as_relative = false
				z_index = Splatter.FLOOR_Z
	if _t > LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := clampf((LIFE - _t) / 0.3, 0.0, 1.0)
	var b := Color(brass, a)
	var d := Color(dark, a)
	var l := 3 if big else 2
	# 飞着的时候横竖交替（在转），落地以后横躺；大弹壳 3 格长、一头是黄铜底
	if _bounces < 2 and _spin / 3 % 2 == 1:
		draw_rect(Rect2(0, -1, 1, l), b)
		draw_rect(Rect2(0, l - 2, 1, 1), d)
	else:
		draw_rect(Rect2(-1, 0, l, 1), b)
		draw_rect(Rect2(l - 2, 0, 1, 1), d)
