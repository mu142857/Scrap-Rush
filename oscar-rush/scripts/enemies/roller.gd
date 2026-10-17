class_name SteamRoller
extends EliteBase
## 蒸汽压路机：第一关最强的精英怪，单独出现在最底层的桥上（桥上那场遭遇战的最后一波）。
## 招式：
## 1. 冲撞：主角和它差不多高时，原地蓄力（红"!"、烟囱冒汽、轰鸣）→ 朝锁定的方向直冲，
##    一路冲到撞墙（桥两头的闸门）为止 → 撞墙大震，晕 2 秒，晕的时候挨打 ×1.5。跳过去躲。
## 2. 喷汽：主角在它头顶（跳过去、飞在上面）时，先冒"!"，然后烟囱往上喷一柱蒸汽，顶人也伤人。
##    免得玩家一直飘在它头上打。
## 平时慢慢朝主角开。从天花板掉下来时落地一震。
## 贴图 roller.png（54×38）：0、1 开动，2 蓄力，3 冲撞，4 晕。由 草图/精英怪/export_roller.py 导出。

enum State { DRIVE, WINDUP, CHARGE, STUN, BLAST_WARN, BLAST }

const DRIVE_SPEED := 20.0
const CHARGE_SPEED := 175.0
const WINDUP_TIME := 0.8
const STUN_TIME := 2.0
const STUN_DAMAGE_MULT := 1.5
const CHARGE_COOLDOWN := 1.6
const SEE_HEIGHT := 28.0
const BLAST_WARN_TIME := 0.5
const BLAST_TIME := 0.8
const BLAST_HEIGHT := 70.0
const BLAST_DAMAGE := 10.0
const BLAST_PUSH := 200.0
const CHIMNEY_PIXEL := Vector2i(11, 3)

var state := State.DRIVE
var _state_t := 0.0
var _cooldown := 1.0
var _charge_dir := -1
var _landed := false
var _blast_area: Area2D
var _blast: CPUParticles2D
var _smoke: CPUParticles2D


func _setup() -> void:
	elite_name = "STEAM ROLLER"
	texture_path = "res://art/enemies/roller.png"
	hframes = 5
	frame_size = Vector2i(54, 38)
	body_rect = Rect2(-24, -30, 48, 30)
	led_pixel = Vector2i(7, 15)
	max_hp = 1500.0
	contact_damage = 12.0


func _after_ready() -> void:
	var p := nearest_player()
	if p:
		dir = 1 if p.global_position.x > global_position.x else -1
	_blast_area = Area2D.new()
	_blast_area.collision_layer = 0
	_blast_area.collision_mask = 2
	_blast_area.monitoring = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, BLAST_HEIGHT)
	cs.shape = r
	_blast_area.add_child(cs)
	add_child(_blast_area)
	_blast = _particles(60, 0.5, 160.0, 10.0, Vector2(2, 4), 0.6)
	_smoke = _particles(10, 0.6, 30.0, 25.0, Vector2(1, 3), 0.4)
	_smoke.emitting = true


func _tick(delta: float) -> void:
	_state_t += delta
	_cooldown -= delta
	var chimney := _chimney_local()
	_blast_area.position = chimney + Vector2(0, -BLAST_HEIGHT / 2.0)
	_blast.position = chimney
	_smoke.position = chimney
	if not _landed:
		if is_on_floor():
			_landed = true
			Game.add_shake(5.0)
			Game.sfx("land", -2.0, 0.5)
			Game.dust(get_parent(), global_position, 8)
		velocity.x = 0.0
		move_and_slide()
		set_frame(0)
		return

	var p := nearest_player()
	match state:
		State.DRIVE:
			if p:
				var dx := p.global_position.x - global_position.x
				var dy := p.global_position.y - global_position.y
				if absf(dx) > 6.0:
					dir = 1 if dx > 0.0 else -1
				if _cooldown <= 0.0 and absf(dx) < 40.0 and dy < -24.0:
					_enter(State.BLAST_WARN)
				elif _cooldown <= 0.0 and absf(dy) < SEE_HEIGHT and absf(dx) < 300.0:
					_enter(State.WINDUP)
			velocity.x = dir * DRIVE_SPEED * speed_mult()
			set_frame(int(_time / 0.15) % 2)
		State.WINDUP:
			velocity.x = 0.0
			set_frame(2)
			if _state_t >= WINDUP_TIME:
				_charge_dir = dir
				_enter(State.CHARGE)
		State.CHARGE:
			velocity.x = _charge_dir * CHARGE_SPEED * speed_mult()
			set_frame(3)
			if int(_state_t / 0.08) != int((_state_t - delta) / 0.08):
				Game.dust(get_parent(), global_position + Vector2(-_charge_dir * 20, 0), 2, -_charge_dir)
			if _state_t > 0.1 and is_on_wall():
				_crash()
			elif _state_t > 0.2 and not ground_ahead(28.0):
				# 前面没路了：刹住，不掉下去
				velocity.x = 0.0
				_enter(State.DRIVE)
			elif _state_t > 4.0:
				_enter(State.DRIVE)
		State.STUN:
			velocity.x = 0.0
			set_frame(4)
			if _state_t >= STUN_TIME:
				_enter(State.DRIVE)
		State.BLAST_WARN:
			velocity.x = 0.0
			set_frame(2)
			if _state_t >= BLAST_WARN_TIME:
				_enter(State.BLAST)
		State.BLAST:
			velocity.x = 0.0
			set_frame(2)
			for b in _blast_area.get_overlapping_bodies():
				var pl := b as Player
				if pl:
					pl.velocity.y = minf(pl.velocity.y, -BLAST_PUSH)
					pl.hurt(global_position + chimney, BLAST_DAMAGE * damage_mult())
			if _state_t >= BLAST_TIME:
				_enter(State.DRIVE)
	contact_damage = 16.0 if state == State.CHARGE else 12.0
	move_and_slide()


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	_blast.emitting = s == State.BLAST
	_blast_area.set_deferred("monitoring", s == State.BLAST)
	_smoke.amount = 10
	match s:
		State.WINDUP:
			warn(WINDUP_TIME)
			Game.sfx("jet", -8.0, 0.6)
		State.CHARGE:
			Game.sfx("jet", -4.0, 0.9)
			Game.add_shake(2.0)
		State.BLAST_WARN:
			warn(BLAST_WARN_TIME)
		State.BLAST:
			Game.sfx("jet", -6.0, 1.5)
		State.DRIVE:
			_cooldown = CHARGE_COOLDOWN * interval_mult()


func _crash() -> void:
	velocity.x = 0.0
	Game.add_shake(7.0)
	Game.hitstop(0.06)
	Game.sfx("crack", 0.0, 0.5)
	Game.sparks(get_parent(), global_position + Vector2(_charge_dir * 26, -16), Color8(255, 190, 120), 18, 140.0)
	Game.dust(get_parent(), global_position, 8)
	_enter(State.STUN)


func hurt(damage: float, from_dir: Vector2, full: bool) -> void:
	super.hurt(damage * (STUN_DAMAGE_MULT if state == State.STUN else 1.0), from_dir, full)


func _on_die() -> void:
	_blast.emitting = false
	_smoke.emitting = false


func _update_visual() -> void:
	super._update_visual()
	# 蓄力时原地发抖
	if state == State.WINDUP:
		_sprite.position.x += 1.0 if int(_state_t * 30.0) % 2 == 0 else -1.0


## 烟囱口相对原点（脚底中间）的位置，跟着朝向镜像
func _chimney_local() -> Vector2:
	var col := CHIMNEY_PIXEL.x if dir < 0 else frame_size.x - 1 - CHIMNEY_PIXEL.x
	return Vector2(col - frame_size.x / 2, CHIMNEY_PIXEL.y - frame_size.y)


func _particles(amount: int, life: float, speed: float, spread: float, size: Vector2, alpha: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
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
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	add_child(p)
	return p
