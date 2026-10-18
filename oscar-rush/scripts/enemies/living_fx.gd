class_name LivingFx
extends Node
## 第二关人形怪（接线员、引座员、观众，两个人形精英）共用的"活物感"（夜间打磨，10-18）。
## 作者："加一些不是机器的，是有生命的"。挂上以后：
## - 眼睛：把 EnemyBase 那颗红色指示灯换成两只暖白的眼睛（_led 的位置是前面那只眼睛），会眨、会往主角那边看。
## - 挨打后仰：EnemyBase.hurt 把 _flash 置 1 的那一帧起，FLINCH 秒内贴图换成后仰那一帧（flinch_frame），往后顿 1 格。
##   只改画面，不改怪自己的状态和出招。
## - 倒下：怪一死（dead 变真、整只藏起来），原地留一个"瘫倒"那一帧（collapse_frame）的身子，扬一点灰，慢慢淡掉。
## - 暗处亮层：叠一层不吃光照的同一张贴图（半透明），暗处也看得出袍子的轮廓（和总机台、留声机一样的做法）。
## 用法：在怪的 _after_ready() 里 LivingFx.attach(self, 后仰帧, 倒下帧)；不要哪一样就传 -1 / with_eyes=false。
## 两个人形精英不挂：眼睛、后仰、倒下自己管，亮层用 EliteBase 自带的 fill_alpha。
## 放在物理帧里、怪自己 _update_visual 之后改贴图（子节点后处理），不会越加越多。

const EYE_COLOR := Color(1.0, 0.86, 0.62)
const FLINCH := 0.22
const HUSK_TIME := 0.7
const FILL_ALPHA := 0.32

var enemy: EnemyBase
var flinch_frame := -1
var collapse_frame := -1
var eyes := true
var fill := true
var eye_gap := 2

var _flinch := 0.0
var _last_flash := 0.0
var _blink := 0.0
var _blink_cd := 2.0
var _look := Vector2.ZERO
var _was_dead := false
var _fill: Sprite2D


static func attach(e: EnemyBase, flinch := -1, collapse := -1, with_eyes := true, gap := 2) -> LivingFx:
	var w := LivingFx.new()
	w.enemy = e
	w.flinch_frame = flinch
	w.collapse_frame = collapse
	w.eyes = with_eyes
	w.eye_gap = gap
	e.add_child(w)
	return w


func _ready() -> void:
	_blink_cd = randf_range(1.0, 4.0)
	var spr: Sprite2D = enemy.get("_sprite")
	var led: Node2D = enemy.get("_led")
	if eyes and led:
		# 换掉红灯的画法：断开 EnemyBase._draw_led，接自己的眼睛
		for c in led.draw.get_connections():
			led.draw.disconnect(c["callable"])
		led.draw.connect(_draw_eyes.bind(led))
		var glow := led.get_child(0) as PointLight2D
		if glow:
			glow.color = EYE_COLOR
			glow.energy = 0.35
			glow.texture_scale = 0.3
	if fill and spr:
		_fill = Sprite2D.new()
		_fill.texture = spr.texture
		_fill.hframes = spr.hframes
		_fill.centered = false
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_fill.material = unshaded
		_fill.modulate = Color(1, 1, 1, FILL_ALPHA)
		enemy.add_child(_fill)
		enemy.move_child(_fill, spr.get_index() + 1)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(enemy):
		return
	var spr: Sprite2D = enemy.get("_sprite")
	if enemy.dead:
		if not _was_dead:
			_was_dead = true
			_spawn_husk(spr)
		return
	# EnemyBase 每帧按情绪档位把小怪的红光调亮调大（机器被惹毛了）；活人的眼神光压回微弱的暖光
	var led: Node2D = enemy.get("_led")
	if eyes and led and led.get_child_count() > 0:
		var glow := led.get_child(0) as PointLight2D
		if glow:
			glow.energy = 0.35
			glow.texture_scale = 0.3
	# 挨打：_flash 跳回 1 的那一帧
	var f: float = enemy.get("_flash")
	if f > _last_flash + 0.5 and flinch_frame >= 0:
		_flinch = FLINCH
	_last_flash = f
	_flinch = maxf(_flinch - delta, 0.0)
	if _flinch > 0.0 and spr:
		if flinch_frame >= 0:
			spr.frame = flinch_frame
		# 往背离主角的方向（也就是身后）顿 1 格
		spr.position.x += -enemy.dir
		# 眼睛跟着换到后仰那一帧的位置（EnemyBase 按原来的帧放的，不挪的话眼睛会飘在脸外面）
		_place_led(spr, flinch_frame)
	# 眨眼、看人
	_blink = maxf(_blink - delta, 0.0)
	_blink_cd -= delta
	if _blink_cd <= 0.0:
		_blink = 0.12
		_blink_cd = randf_range(2.0, 4.5)
	_look = Vector2.ZERO
	var p := enemy.nearest_player()
	if p:
		if p.global_position.y < enemy.global_position.y - 30.0:
			_look.y = -1.0
		# 主角在身后：眼睛往后瞟一格
		if signf(p.global_position.x - enemy.global_position.x) == -float(enemy.dir):
			_look.x = -enemy.dir


## 照 EnemyBase._update_visual 的算法，把眼睛（_led）放到第 f 帧的位置
func _place_led(spr: Sprite2D, f: int) -> void:
	var led: Node2D = enemy.get("_led")
	if led == null or f < 0:
		return
	var by: Dictionary = enemy.led_by_frame
	var px: Vector2i = by.get(f, enemy.led_pixel)
	led.visible = px.x >= 0
	if led.visible:
		var fs := enemy.frame_size
		var col := px.x if enemy.dir < 0 else fs.x - 1 - px.x
		led.position = spr.position + Vector2(col - fs.x / 2, px.y - fs.y)
		led.queue_redraw()


## 亮层跟着贴图（_process：精英出场动画会在物理帧之后再改帧和位置）
func _process(_delta: float) -> void:
	if _fill == null or not is_instance_valid(enemy):
		return
	var spr: Sprite2D = enemy.get("_sprite")
	_fill.visible = spr.visible and enemy.visible
	_fill.frame = spr.frame
	_fill.flip_h = spr.flip_h
	_fill.offset = spr.offset
	_fill.position = spr.position
	_fill.modulate = Color(1, 1, 1, FILL_ALPHA)


func _draw_eyes(led: Node2D) -> void:
	if _blink > 0.0 or not led.visible:
		return
	var f: float = enemy.get("_flash")
	var c := EYE_COLOR.lerp(Color.WHITE, f)
	var lk := _look.round()
	led.draw_rect(Rect2(lk, Vector2.ONE), c)
	if eye_gap > 0:
		led.draw_rect(Rect2(lk + Vector2(-eye_gap * enemy.dir, 0), Vector2.ONE), Color(c, 0.75))


## 原地留一个瘫倒的身子：照着死前的朝向和位置，扬一点灰，慢慢沉一格、淡掉
func _spawn_husk(spr: Sprite2D) -> void:
	if collapse_frame < 0 or spr == null:
		return
	var parent := enemy.get_parent()
	if parent == null:
		return
	var h := Husk.new()
	h.texture = spr.texture
	h.hframes = spr.hframes
	h.frame = collapse_frame
	h.centered = false
	h.flip_h = spr.flip_h
	h.offset = spr.offset
	h.global_position = enemy.global_position.round()
	parent.add_child(h)
	Game.dust(parent, enemy.global_position, 5)


class Husk:
	extends Sprite2D

	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		var k := _t / LivingFx.HUSK_TIME
		modulate = Color(1, 1, 1, 1.0 - clampf((k - 0.4) / 0.6, 0.0, 1.0))
		if k >= 1.0:
			queue_free()
