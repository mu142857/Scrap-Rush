class_name Kettle
extends EnemyBase
## 汽壶（策划案第九节 3）：固定在原地，隔一段时间从壶嘴往上喷一柱蒸汽。
## 蒸汽不伤人，但会把人往上顶，挡住飞行路线。喷汽间隔跟着情绪档位变短（"机关触发频率"）。
## 大怪：血量 300，打死情绪 -3。碰到壶身伤人。
## 贴图 kettle.png：0 平时，1、2 壶盖来回抖（喷汽前摇）。

const INTERVAL := 2.6
const WARN_TIME := 0.6
const STEAM_TIME := 1.0
const STEAM_HEIGHT := 64.0
const STEAM_WIDTH := 10.0
const STEAM_PUSH := 170.0
## 原图（朝左）里壶嘴口的像素
const SPOUT_PIXEL := Vector2i(15, 10)

enum State { IDLE, WARN, STEAM }

## 摆在关卡里时想让壶嘴朝左（默认壶嘴在右边）就勾上
@export var flip := false

var state := State.IDLE
var _state_t := 0.0
var _steam_area: Area2D
var _steam: CPUParticles2D
var _hiss: CPUParticles2D


func _setup() -> void:
	texture_path = "res://art/enemies/kettle.png"
	hframes = 3
	frame_size = Vector2i(16, 22)
	body_rect = Rect2(-6, -11, 12, 11)
	led_pixel = Vector2i(6, 15)
	max_hp = 300.0
	contact_damage = 10.0
	big = true
	knockback = Vector2.ZERO
	dir = 1 if flip else -1
	_state_t = randf() * INTERVAL          # 几个汽壶不要同时喷


func _after_ready() -> void:
	var spout := _spout_local()
	_steam_area = Area2D.new()
	_steam_area.collision_layer = 0
	_steam_area.collision_mask = 2
	_steam_area.monitoring = false
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(STEAM_WIDTH, STEAM_HEIGHT)
	cs.shape = rect
	cs.position = spout + Vector2(0, -STEAM_HEIGHT / 2.0)
	_steam_area.add_child(cs)
	add_child(_steam_area)

	_steam = _make_particles(spout, 48, 0.55, 120.0, 8.0, Vector2(2, 4), 0.5)
	_hiss = _make_particles(spout, 6, 0.3, 30.0, 40.0, Vector2(1, 2), 0.35)
	# 夜间打磨：挨打顿一格、死时抖一下碎几块（见 elite_fx.gd，和第二关的小怪一样）
	EliteFx.attach_small(self, 7)


func _tick(delta: float) -> void:
	_state_t += delta
	velocity.x = 0.0
	move_and_slide()
	match state:
		State.IDLE:
			set_frame(0)
			if _state_t >= INTERVAL * interval_mult():
				_enter(State.WARN)
		State.WARN:
			set_frame(1 + int(_state_t / 0.06) % 2)
			if _state_t >= WARN_TIME:
				_enter(State.STEAM)
		State.STEAM:
			set_frame(1)
			for b in _steam_area.get_overlapping_bodies():
				var p := b as Player
				if p:
					p.velocity.y = minf(p.velocity.y, -STEAM_PUSH)
			if _state_t >= STEAM_TIME:
				_enter(State.IDLE)


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	_hiss.emitting = s == State.WARN
	_steam.emitting = s == State.STEAM
	_steam_area.set_deferred("monitoring", s == State.STEAM)
	if s == State.WARN:
		Game.sfx("jet", -22.0, 1.8, 0.1)
	elif s == State.STEAM:
		Game.sfx("jet", -12.0, 1.4, 0.1)


func _on_die() -> void:
	_steam.emitting = false
	_hiss.emitting = false
	state = State.IDLE


func _on_respawn() -> void:
	_enter(State.IDLE)


## 壶嘴口相对原点（脚底中间）的位置，翻转时跟着镜像
func _spout_local() -> Vector2:
	var col := SPOUT_PIXEL.x if dir < 0 else frame_size.x - 1 - SPOUT_PIXEL.x
	return Vector2(col - frame_size.x / 2, SPOUT_PIXEL.y - frame_size.y)


func _make_particles(pos: Vector2, amount: int, life: float, speed: float, spread: float,
		size: Vector2, alpha: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.direction = Vector2.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.7
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, -20)
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.83, 0.8, alpha))
	ramp.set_color(1, Color(0.6, 0.58, 0.58, 0.0))
	p.color_ramp = ramp
	# 黑暗里也要看得见蒸汽在哪（它挡路），所以不吃光照，用半透明压着
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	add_child(p)
	return p
