class_name SteamVent
extends Node2D
## 地上的蒸汽格栅（Boss 二阶段起用）：先发红、冒小股白气预警 0.9 秒，
## 然后喷出一整根到天花板的汽柱，持续 0.8 秒；站在里面会被烫，还会被往上顶。
## 原点在格栅中间、地面那一行。

const WARN_TIME := 0.9
const BLAST_TIME := 0.8
const WIDTH := 14.0
const DAMAGE := 10.0
const LIFT := -260.0

## 汽柱有多高（到天花板）
var height := 150.0

var _state := 0          # 0 闲着，1 预警，2 喷
var _t := 0.0
var _area: Area2D
var _warn_fx: CPUParticles2D
var _blast_fx: CPUParticles2D
var _light: PointLight2D


func _ready() -> void:
	z_index = 6
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded

	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2 | 8
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH, height)
	shape.shape = rect
	shape.position = Vector2(0, -height * 0.5)
	_area.add_child(shape)
	add_child(_area)

	_warn_fx = _steam(6, 0.5, 20.0, 40.0, 1.0, 2.0)
	_blast_fx = _steam(70, 0.55, 260.0, 340.0, 2.0, 5.0)
	_blast_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_blast_fx.emission_rect_extents = Vector2(WIDTH * 0.35, 1)

	_light = PointLight2D.new()
	_light.texture = Game.light_texture()
	_light.color = Color(1.0, 0.4, 0.2)
	_light.energy = 0.0
	_light.texture_scale = 0.8
	_light.position = Vector2(0, -4)
	add_child(_light)


func _steam(amount: int, life: float, v0: float, v1: float, s0: float, s1: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.direction = Vector2.UP
	p.spread = 6.0
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = s0
	p.scale_amount_max = s1
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.add_point(0.4, Color(0.85, 0.82, 0.8, 0.6))
	ramp.set_color(1, Color(0.6, 0.58, 0.58, 0.0))
	p.color_ramp = ramp
	p.material = material
	add_child(p)
	return p


func trigger(delay := 0.0) -> void:
	if _state != 0:
		return
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	_state = 1
	_t = WARN_TIME
	_warn_fx.emitting = true
	Game.sfx("charge", -18.0, 0.6)


func is_busy() -> bool:
	return _state != 0


func _physics_process(delta: float) -> void:
	if _state == 0:
		_light.energy = move_toward(_light.energy, 0.0, delta * 4.0)
		return
	_t -= delta
	if _state == 1:
		_light.energy = 0.4 + 0.6 * (1.0 - _t / WARN_TIME) * (0.6 + 0.4 * sin(_t * 40.0))
		if _t <= 0.0:
			_state = 2
			_t = BLAST_TIME
			_warn_fx.emitting = false
			_blast_fx.emitting = true
			Game.sfx("vent", -4.0, 1.0, 0.1)
			Game.add_shake(2.0)
	elif _state == 2:
		_light.energy = 1.2
		for b in _area.get_overlapping_bodies():
			if b is Player:
				var p := b as Player
				p.hurt(global_position + Vector2(0, 10), DAMAGE * EnemyBase.damage_mult())
				p.velocity.y = minf(p.velocity.y, LIFT)
			elif b is Crystal:
				(b as Crystal).take_hit(global_position, DAMAGE)
		if _t <= 0.0:
			_state = 0
			_blast_fx.emitting = false
	queue_redraw()


func _draw() -> void:
	if _state == 1:
		# 格栅缝里透出红光，越来越亮
		var k := 1.0 - _t / WARN_TIME
		var col := Color(1.0, 0.35, 0.15, 0.4 + 0.6 * k)
		for x in range(-7, 8, 3):
			draw_rect(Rect2(x, 1, 1, 2), col)
	elif _state == 2:
		draw_rect(Rect2(-7, 0, 15, 3), Color(1.0, 0.8, 0.6, 0.8))
